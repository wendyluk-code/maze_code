const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const url=process.argv[2] || 'http://127.0.0.1:8086/';
const out=path.resolve(process.argv[3]);fs.mkdirSync(out,{recursive:true});
const report={url,started_at:new Date().toISOString(),checks:[],console_errors:[],observations:[]};
function check(ok,label,detail){report.checks.push({passed:!!ok,label,detail});if(!ok)throw Error(label);}
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
 const context=await browser.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:url.startsWith('https://')});
 const page=await context.newPage();
 // 只在隔离验收页保留真实命中后的帧；不向游戏发送暂停或状态写入。
 await page.addInitScript(()=>{
  const raf=window.requestAnimationFrame.bind(window);
  const capture={armed:false,frozen:false,hits:0,pending:[]};
  window.__fenshuiHitCapture=capture;
  window.requestAnimationFrame=callback=>raf(time=>{
   if(capture.frozen){capture.pending.push(callback);return;}
   callback(time);
   if(capture.armed && (window.fenshuiStatus?.hits||0)>capture.hits)capture.frozen=true;
  });
  capture.resume=()=>{
   capture.armed=false;capture.frozen=false;
   for(const callback of capture.pending.splice(0))raf(callback);
  };
 });
 page.on('console',m=>{if(m.type()==='error' || /SCRIPT ERROR|ERROR:/.test(m.text())){report.console_errors.push(m.text());console.error(m.text());}});
 page.on('pageerror',e=>report.console_errors.push(String(e)));
 try{
  const response=await page.goto(url,{waitUntil:'domcontentloaded',timeout:120000});
  check(response.status()===200,'实际游戏网页HTTP成功');
  console.log('游戏HTML已加载，等待引擎与场景就绪');
  await page.waitForFunction(()=>window.fenshuiStatus?.ready,{},{timeout:180000});
  let s=await page.evaluate(()=>window.fenshuiStatus);report.observations.push(s);
  check(s.monsters===7 && s.gate,'正式七怪与原确认窗就绪');
  await page.screenshot({path:path.join(out,'entry.png')});
  const canvas=page.locator('canvas#canvas');const box=await canvas.boundingBox();
  check(box?.width>500 && box?.height>300,'游戏画布已显示');
  const start=await page.evaluate(()=>({rect:window.fenshuiStatus.start_button,viewport:window.fenshuiStatus.viewport}));
  const startPoint=start.rect?{x:box.width*(start.rect[0]+start.rect[2]/2)/start.viewport[0],y:box.height*(start.rect[1]+start.rect[3]/2)/start.viewport[1]}:{x:box.width*Number(process.env.FENSHUI_START_X||0.52),y:box.height*Number(process.env.FENSHUI_START_Y||0.69)};
  await canvas.click({position:startPoint});
  await page.waitForFunction(()=>window.fenshuiStatus?.gate===false,{},{timeout:10000});
  check(true,'通过画布实际点击开始进入战斗');
  const before=await page.evaluate(()=>window.fenshuiStatus.hero);
  await page.keyboard.down('d');
  try{await page.waitForFunction(x=>window.fenshuiStatus.hero[0]>x+5,before[0],{timeout:5000});}
  finally{await page.keyboard.up('d');}
  check(true,'浏览器内部按键可以实际移动');
  await page.keyboard.press('Tab');
  await page.waitForFunction(()=>!!window.fenshuiStatus.lock,{},{timeout:5000});
  check(true,'Tab实际锁定目标');
  const hits=await page.evaluate(()=>window.fenshuiStatus.hits);
  await page.keyboard.press('Space');
  await page.evaluate(n=>Object.assign(window.__fenshuiHitCapture,{armed:true,hits:n}),hits);
  // 锁定不提供追踪弹；对移动目标按原冷却连续实际出手，不要求首发必中。
  for(let attempt=0;attempt<6;attempt++){
   const s=await page.evaluate(()=>window.fenshuiStatus);report.observations.push(s);
   if(s.hits>hits)break;
   await canvas.click({position:{x:box.width*0.47,y:box.height*0.56}});
   await page.waitForFunction(a=>window.fenshuiStatus.hits>a[0] || window.fenshuiStatus.time>a[1]+0.8,[hits,s.time],{timeout:5000,polling:20});
  }
  await page.waitForFunction(n=>window.fenshuiStatus.hits>n,hits,{timeout:3000,polling:20});
  check(true,'浏览器内部左键经过原战斗命中入口');
  await page.waitForFunction(()=>window.__fenshuiHitCapture.frozen,{},{timeout:3000,polling:20});
  check(true,'隔离浏览器保留实际命中渲染帧，仅用于截图取证');
  await page.screenshot({path:path.join(out,'actual-hit.png')});
  await page.evaluate(()=>window.__fenshuiHitCapture.resume());
  await page.keyboard.press('q');
  await page.waitForFunction(()=>!window.fenshuiStatus.lock,{},{timeout:5000});
  check(true,'Q实际解除锁定');
  const continued=await page.evaluate(()=>window.fenshuiStatus.time);
  await page.waitForFunction(t=>window.fenshuiStatus.time>t+0.6,continued,{timeout:5000});
  check(true,'解除锁定后原战斗继续推进，显示层已接续当前阶段');
  await page.screenshot({path:path.join(out,'battle.png')});
  for(const size of [{width:1152,height:648},{width:1280,height:720}]){
   await page.setViewportSize(size);
   const resizedAt=await page.evaluate(()=>window.fenshuiStatus.time);
   await page.waitForFunction(t=>window.fenshuiStatus.time>t+0.15,resizedAt,{timeout:5000});
   await page.screenshot({path:path.join(out,`controls-hint-${size.width}.png`)});
   check(true,`实际网页${size.width}×${size.height}提示栏画面已留证`);
  }
  report.observations.push(await page.evaluate(()=>window.fenshuiStatus));
  check(report.console_errors.length===0,'无脚本、资源或浏览器运行错误',report.console_errors);
 }catch(error){report.error=String(error);report.observations.push(await page.evaluate(()=>window.fenshuiStatus).catch(()=>null));await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});}
 finally{
  report.ended_at=new Date().toISOString();report.passed=!report.error && report.console_errors.length===0;
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  await browser.close();console.log(JSON.stringify(report,null,2));if(!report.passed)process.exitCode=1;
 }
})().catch(error=>{console.error(error);process.exitCode=1;});
