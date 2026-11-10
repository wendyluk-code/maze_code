const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const url = process.argv[2], out = path.resolve(process.argv[3]);
fs.mkdirSync(out, {recursive: true});
const report = {url, started_at: new Date().toISOString(), checks: [], errors: [], samples: [], method: '配套专用无界面浏览器，正常连续播放和页面内部持键；不改游戏状态、不冻结取帧'};
function check(ok, label, detail) {report.checks.push({passed: !!ok, label, detail}); if (!ok) throw Error(label);}
(async () => {
 let browser, page;
 const deadline = setTimeout(() => {report.error = '180秒总时限'; void browser?.close();}, 180000);
 try {
  browser = await chromium.launch({headless: true, timeout: 30000, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required']});
  report.browser = browser.version();
  const context = await browser.newContext({viewport: {width: 1280, height: 720}, ignoreHTTPSErrors: true, recordVideo: {dir: out, size: {width: 1280, height: 720}}});
  page = await context.newPage();
  page.on('pageerror', e => report.errors.push(String(e)));
  page.on('console', m => {if (m.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(m.text())) report.errors.push(m.text());});
  await page.addInitScript(() => {
   window.__eelSamples = []; let previous = -1;
   function collect() {
    const s = window.fenshuiStatus;
    if (s?.ready && previous !== s.time) {previous = s.time; window.__eelSamples.push(structuredClone(s));}
    requestAnimationFrame(collect);
   }
   requestAnimationFrame(collect);
  });
  check((await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 60000})).status() === 200, '电鳗候选网页HTTP200');
  await page.waitForFunction(() => window.fenshuiStatus?.start_button, null, {timeout: 60000});
  let s = await page.evaluate(() => window.fenshuiStatus);
  check(s.version === '20261105-F-eel' && s.monsters === 7 && Object.keys(s.eels).length === 2, 'F版真实七怪、两只独立电鳗已加载');
  const canvas = page.locator('canvas#canvas'), box = await canvas.boundingBox(), r = s.start_button, v = s.viewport;
  await canvas.click({position: {x: box.width * (r[0] + r[2] / 2) / v[0], y: box.height * (r[1] + r[3] / 2) / v[1]}});
  await page.waitForFunction(() => !window.fenshuiStatus.gate, null, {timeout: 5000});
  // 从原统一出生点沿已有合法水路走向第二只电鳗；只用实际移动和既有满血键。
  await page.keyboard.press('Control+0');
  await page.keyboard.down('s');
  try {await page.waitForFunction(() => window.fenshuiStatus.hero[1] > 570, null, {timeout: 8000, polling: 20});}
  finally {await page.keyboard.up('s');}
  await page.keyboard.down('d');
  try {await page.waitForFunction(() => window.fenshuiStatus.hero[0] > 1090, null, {timeout: 8000, polling: 20});}
  finally {await page.keyboard.up('d');}
  await page.keyboard.down('s');
  try {await page.waitForFunction(() => window.fenshuiStatus.hero[1] > 605, null, {timeout: 5000, polling: 20});}
  finally {await page.keyboard.up('s');}
  check(true, '浏览器实际持键走到电鳗附近，不传送或改怪物位置');
  await page.keyboard.press('Control+0');
  const id = 'fenshui_thunder_eel_2';
  // 巨蛙砸击会按原规则击退玩家；用页面真实方向键回到水中站位，不能留在岸上诱导回水后要求继续放电。
  const held = new Set(), approachDeadline = Date.now() + 25000;
  try {
   while (Date.now() < approachDeadline) {
    const current = await page.evaluate(() => window.fenshuiStatus);
    if (current.eels[id]?.actor.eel_phase === 'exhausted') break;
    const desired = new Set();
    if (current.hero[0] < 1082) desired.add('d');
    if (current.hero[0] > 1098) desired.add('a');
    if (current.hero[1] < 597) desired.add('s');
    if (current.hero[1] > 613) desired.add('w');
    for (const key of held) if (!desired.has(key)) {await page.keyboard.up(key); held.delete(key);}
    for (const key of desired) if (!held.has(key)) {await page.keyboard.down(key); held.add(key);}
    if (current.hp < 20) await page.keyboard.press('Control+0');
    await page.waitForFunction(t => window.fenshuiStatus.time > t + 0.1, current.time, {timeout: 3000, polling: 20});
   }
  } finally {for (const key of held) await page.keyboard.up(key);}
  await page.waitForFunction(id => window.fenshuiStatus.eels[id]?.actor.eel_phase === 'exhausted', id, {timeout: 1000, polling: 20});
  s = await page.evaluate(() => window.fenshuiStatus);
  check(s.eels[id].actor.eel_discharges === 3 && !s.eels[id].shielded && !s.eels[id].bubble_visible, '正常七怪实战第三次完成后破泡且取消真实保护');
  const hp = s.eels[id].actor.hp, start = s.time;
  await page.screenshot({path: path.join(out, 'natural-break.png')});
  await page.waitForFunction(id => {const e = window.fenshuiStatus.eels[id]; return e.actor.eel_phase === 'exhausted' && e.actor.eel_left < 3.7;}, id, {timeout: 3000});
  s = await page.evaluate(() => window.fenshuiStatus);
  check(s.eels[id].fx_visible && s.eels[id].body_scale[1] < s.eels[id].body_scale[0] * 0.85, '正常播放可见低伏喘息，命中特效不继承身体形变');
  await page.screenshot({path: path.join(out, 'natural-exhausted.png')});
  await page.waitForFunction(id => window.fenshuiStatus.eels[id].actor.eel_phase === 'forming', id, {timeout: 7000, polling: 20});
  s = await page.evaluate(() => window.fenshuiStatus);
  check(s.time - start > 3.5 && !s.eels[id].shielded, '实际保留4秒窗口后进入恢复，成泡未完成仍无减伤');
  await page.screenshot({path: path.join(out, 'natural-recover.png')});
  await page.waitForFunction(id => window.fenshuiStatus.eels[id].actor.eel_discharges === 0 && window.fenshuiStatus.eels[id].shielded, id, {timeout: 3000});
  s = await page.evaluate(() => window.fenshuiStatus);
  check(s.eels[id].actor.hp === hp && s.eels[id].bubble_visible, '恢复成泡和行动，次数清零且不回血');
  await page.screenshot({path: path.join(out, 'natural-restored.png')});
  report.samples = await page.evaluate(() => window.__eelSamples);
  check(report.samples.some(s => s.eels?.[id]?.actor.eel_discharges === 1) && report.samples.some(s => s.eels?.[id]?.actor.eel_discharges === 2), '连续原始采样包含一、二次，不跳写到第三次');
  check(report.errors.length === 0, '无网页、脚本或资源错误', report.errors);
 } catch (e) {
  report.error = report.error || String(e);
  if (page) {report.status = await page.evaluate(() => window.fenshuiStatus).catch(() => null); report.samples = await page.evaluate(() => window.__eelSamples).catch(() => []); await page.screenshot({path: path.join(out, 'failure.png')}).catch(() => {});}
 } finally {
  clearTimeout(deadline); if (browser) await browser.close(); report.ended_at = new Date().toISOString(); report.passed = !report.error && !report.errors.length;
  fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify({passed: report.passed, error: report.error, checks: report.checks, errors: report.errors}, null, 2));
  if (!report.passed) process.exitCode = 1;
 }
})();
