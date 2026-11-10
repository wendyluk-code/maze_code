const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const url=process.argv[2];
const out=path.resolve(process.argv[3]);
fs.mkdirSync(out,{recursive:true});
const report={url,started_at:new Date().toISOString(),checks:[],console_errors:[],observations:[],method:'配套专用无头浏览器，仅页面内部输入，不写游戏状态'};
function check(ok,label,detail){report.checks.push({passed:!!ok,label,detail});if(!ok)throw Error(label);}
(async()=>{
 let browser;
 let page;
 const deadline=setTimeout(()=>{
  report.error='本次玩家受击网页检查超过180秒';
  void browser?.close();
 },180000);
 try{
  browser=await chromium.launch({headless:true,timeout:30000,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
  report.browser_version=browser.version();
  const context=await browser.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
  page=await context.newPage();
  await page.addInitScript(()=>{
   const raf=window.requestAnimationFrame.bind(window);
   const capture={armed:false,frozen:false,received:0,pending:[]};
   window.__hurtFrameCapture=capture;
   window.requestAnimationFrame=callback=>raf(time=>{
    if(capture.frozen){capture.pending.push(callback);return;}
    callback(time);
    const event=window.fenshuiStatus?.player_hurt;
    if(capture.armed && event?.active && event.received>capture.received){capture.frozen=true;capture.observed=structuredClone(window.fenshuiStatus);}
   });
   capture.resume=()=>{
    capture.armed=false;capture.frozen=false;
    for(const callback of capture.pending.splice(0))raf(callback);
   };
  });
  page.on('console',m=>{if(m.type()==='error' || /SCRIPT ERROR|ERROR:/.test(m.text()))report.console_errors.push(m.text());});
  page.on('pageerror',e=>report.console_errors.push(String(e)));
  const response=await page.goto(url,{waitUntil:'domcontentloaded',timeout:90000});
  check(response.status()===200,'新导出游戏网页返回200');
  await page.waitForFunction(()=>window.fenshuiStatus?.ready,null,{timeout:90000});
  let status=await page.evaluate(()=>window.fenshuiStatus);
  check(status.monsters===7 && status.player_hurt?.received===0 && status.gate,'新七怪入口安装干净玩家受击消费者');
  await page.screenshot({path:path.join(out,'entry.png')});
  const canvas=page.locator('canvas#canvas');
  let box=await canvas.boundingBox();
  const start=await page.evaluate(()=>({rect:window.fenshuiStatus.start_button,viewport:window.fenshuiStatus.viewport}));
  const startPoint=start.rect?{x:box.width*(start.rect[0]+start.rect[2]/2)/start.viewport[0],y:box.height*(start.rect[1]+start.rect[3]/2)/start.viewport[1]}:{x:box.width*Number(process.env.FENSHUI_START_X||0.52),y:box.height*Number(process.env.FENSHUI_START_Y||0.69)};
  await canvas.click({position:startPoint});
  await page.waitForFunction(()=>window.fenshuiStatus?.gate===false,null,{timeout:10000});
  const initialHP=await page.evaluate(()=>window.fenshuiStatus.hp);
  await page.evaluate(()=>{window.__hurtFrameCapture.armed=true;});
  await page.waitForFunction(()=>window.__hurtFrameCapture.frozen,null,{timeout:25000,polling:20});
  status=await page.evaluate(()=>window.__hurtFrameCapture.observed);
  report.observations.push(status);
  check(status.hp<initialHP && status.player_hurt.received>0 && status.player_hurt.active,'自然七怪攻击实际扣血后播放玩家受击，不伪造事件');
  if(process.env.FENSHUI_EXPECT_INTERRUPT==='1'){
   const recovery=status.player_hurt.kind==='slam'?0.9:0.6;
   check(status.hurt_recovery_left>recovery-0.2 && status.hurt_recovery_left<=recovery && status.action==='','实际网页按招式进入600/900毫秒恢复并取消未完成攻击',status.hurt_recovery_left);
  }
  check(['fish','electric','water','slam'].includes(status.player_hurt.kind) && status.player_hurt.effect_frame>=0,'实际网页消费已认可四类图集之一',status.player_hurt);
  await page.screenshot({path:path.join(out,'actual-player-hurt.png')});
  await page.evaluate(()=>window.__hurtFrameCapture.resume());
  await page.waitForFunction(()=>!window.fenshuiStatus.player_hurt.active,null,{timeout:5000,polling:20});
  check(true,'真实短效播完自动清理');
  if(process.env.FENSHUI_EXPECT_INTERRUPT==='1'){
   await page.waitForFunction(()=>window.fenshuiStatus.hurt_recovery_left<=0,null,{timeout:5000,polling:20});
   check(true,'实际网页受击恢复时钟能正常归零');
  }
  await page.keyboard.press('Control+0');
  await page.waitForFunction(()=>window.fenshuiStatus.hp===window.fenshuiStatus.max_hp,null,{timeout:5000});
  check(true,'受击后原Ctrl+0满血仍可用');
  const before=await page.evaluate(()=>window.fenshuiStatus.hero);
  await page.keyboard.down('s');
  try{await page.waitForFunction(p=>Math.hypot(window.fenshuiStatus.hero[0]-p[0],window.fenshuiStatus.hero[1]-p[1])>5,before,{timeout:5000});}
  finally{await page.keyboard.up('s');}
  check(true,'受击结束后浏览器内部输入仍能正常移动');
  for(const size of [{width:1152,height:648},{width:1280,height:720}]){
   await page.setViewportSize(size);
   const time=await page.evaluate(()=>window.fenshuiStatus.time);
   await page.waitForFunction(t=>window.fenshuiStatus.time>t+0.15,time,{timeout:5000});
   await page.screenshot({path:path.join(out,'restored-'+size.width+'.png')});
   check(true,'受击后'+size.width+'宽实际画面已留证');
  }
  check(report.console_errors.length===0,'无脚本、资源或网页控制台错误',report.console_errors);
 }catch(error){
  report.error=report.error || String(error);
  if(page){report.observations.push(await page.evaluate(()=>window.fenshuiStatus).catch(()=>null));await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});}
 }finally{
  clearTimeout(deadline);
  if(browser)await browser.close();
  report.ended_at=new Date().toISOString();
  report.passed=!report.error && report.console_errors.length===0;
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
  if(!report.passed)process.exitCode=1;
 }
})().catch(error=>{console.error(error);process.exitCode=1;});
