const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const url=process.argv[2],out=path.resolve(process.argv[3]);
const feedbackVersion=process.env.FENSHUI_EXPECT_VERSION||'20261106-H-splash-hurt-preview';
const expectedSlamRadius=Number(process.env.FENSHUI_EXPECT_SLAM_RADIUS||65);
fs.mkdirSync(out,{recursive:true});
const report={url,started_at:new Date().toISOString(),checks:[],errors:[],render_warnings:[],method:'正常连续播放、独立存档、只读观测及浏览器内部输入，无冻结取帧'};
function check(ok,label,detail){report.checks.push({passed:!!ok,label,detail});if(!ok)throw Error(label);}
(async()=>{
 let browser,page;
 const timer=setTimeout(()=>{report.error='180秒总时限';void browser?.close();},180000);
 try{
  browser=await chromium.launch({headless:true,timeout:30000,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
  report.browser=browser.version();
  const context=await browser.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true,recordVideo:{dir:out,size:{width:1280,height:720}}});
  page=await context.newPage();
  page.on('pageerror',e=>report.errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))report.errors.push(m.text());if(/WebGL|GL Driver Message/.test(m.text())&&!report.render_warnings.includes(m.text()))report.render_warnings.push(m.text());});
  await page.addInitScript(()=>{
   window.__waterSamples=[];let last=-1;
   function collect(){const s=window.fenshuiStatus;if(s?.ready&&s.time!==last){last=s.time;window.__waterSamples.push({at:performance.now(),time:s.time,hero:s.hero,hp:s.hp,water:s.water,hurt:s.player_hurt,recovery:s.hurt_recovery_left,hits:s.hits,splash:s.splash,area:s.slam_area});}requestAnimationFrame(collect);}
   requestAnimationFrame(collect);
  });
  const response=await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
  check(response.status()===200,'水体网页HTTP200');
  await page.waitForFunction(()=>window.fenshuiStatus?.ready&&window.fenshuiStatus.start_button,null,{timeout:60000});
  let s=await page.evaluate(()=>window.fenshuiStatus);
  check(s.monsters===7 && s.water?.enabled,'正式七怪与水体消费者实际就绪');
  if(process.env.FENSHUI_EXPECT_MONSTER_COMBAT==='1')check(s.monster_combat?.kinds.length===10&&s.monster_combat.eligible.length===6&&!s.monster_combat.eligible.includes('fenshui_wind_frog_1'),'网页加载十种共用规则；开始前沿原暂停入口尚未推进巨蛙解锁',s.monster_combat);
  if(process.env.FENSHUI_EXPECT_PLAYER_COMBAT==='1')check(s.player_combat?.installed&&s.player_combat.owned_by_player&&s.player_combat.enabled,'网页实际安装玩家持有的共用战斗模块',s.player_combat);
  const canvas=page.locator('canvas#canvas'),box=await canvas.boundingBox();
  const r=s.start_button,v=s.viewport;
  await canvas.click({position:{x:box.width*(r[0]+r[2]/2)/v[0],y:box.height*(r[1]+r[3]/2)/v[1]}});
  await page.waitForFunction(()=>!window.fenshuiStatus.gate&&window.fenshuiStatus.water.depth>.8,null,{timeout:5000});
  check(true,'正常战斗浅水渐进浸没并非启动假帧');
  if(process.env.FENSHUI_EXPECT_MONSTER_COMBAT==='1'){
   await page.waitForFunction(()=>window.fenshuiStatus.monster_combat?.eligible.length===7&&window.fenshuiStatus.monster_combat.eligible.includes('fenshui_wind_frog_1'),null,{timeout:3000});
   check(true,'开始真实战斗后巨蛙沿原解锁政策与六普通怪均可攻击');
  }
  if(process.env.FENSHUI_EXPECT_PLAYER_COMBAT==='1'){
   await page.keyboard.press('Tab');
   await page.waitForFunction(()=>!!window.fenshuiStatus.lock,null,{timeout:3000});
   check(true,'共用模块在网页接收Tab锁定');
   if(process.env.FENSHUI_EXPECT_MONSTER_COMBAT==='1'){
    s=await page.evaluate(()=>window.fenshuiStatus);
    check(s.monster_combat.eligible.includes(s.lock),'网页实际锁定目标满足怪物共用资格',s.lock);
   }
   await page.keyboard.press('q');
   await page.waitForFunction(()=>!window.fenshuiStatus.lock,null,{timeout:3000});
   check(true,'共用模块在网页接收Q解除锁定');
   await page.keyboard.press('Tab');
   await page.keyboard.press('Space');
   await page.waitForFunction(()=>{const g=window.fenshuiStatus.attack_gate;return !g.combat_paused&&!g.recovering&&g.cooldown<=.00001&&g.action_left<=0;},null,{timeout:8000});
   const before=await page.evaluate(()=>window.fenshuiStatus.throws);
   await canvas.click({position:{x:box.width*.48,y:box.height*.48}});
   await page.waitForFunction(n=>window.fenshuiStatus.throws>n,before,{timeout:3000});
   check(true,'共用模块实际左键出招推进原战斗计数');
  }
  await page.screenshot({path:path.join(out,'water-live.png')});
  await page.waitForFunction(()=>window.fenshuiStatus.player_hurt.received>0,null,{timeout:20000});
  s=await page.evaluate(()=>window.fenshuiStatus);
  check(s.hp<s.max_hp&&s.water.enabled,'真实自然受击与水体同时推进');
  if(process.env.FENSHUI_EXPECT_FEEDBACK==='1'){
   check(s.version===feedbackVersion&&s.candidate&&s.hurt_pose_refined,'实际网页进入指定版本的水花/痛态候选，未冒充8450 G版',s.version);
   await page.waitForFunction(()=>window.__waterSamples.some(x=>x.hurt?.pose_frame===1&&x.hurt.active&&x.hurt.effect_frame<0&&x.recovery>0&&x.recovery<(x.hurt.kind==='slam'?0.9:0.6)-.24),null,{timeout:15000});
   check(true,'正常连续播放中接触图结束后仍保持闭眼痛态，而非只统计事件');
   await page.screenshot({path:path.join(out,'held-hurt-live.png')});
   await page.keyboard.press('Control+0');
   await page.waitForFunction(()=>window.__waterSamples.some(x=>x.splash?.takeoffs>0&&x.splash.frame>=0&&x.splash.frame<3),null,{timeout:15000});
   check(true,'真实自然起跳消费新图集前三帧');
   await page.waitForFunction(()=>window.fenshuiStatus.splash?.landings>0&&window.fenshuiStatus.splash.frame>=4&&window.fenshuiStatus.splash.frame<=6,null,{timeout:15000});
   s=await page.evaluate(()=>window.fenshuiStatus);
   check(Math.abs(s.splash.radius-expectedSlamRadius)<.001&&s.frog.frog_phase==='landing','落地水花来自实际落地，核对本次指定判定半径',s.splash);
   await page.screenshot({path:path.join(out,'landing-splash-live.png')});
   await page.waitForFunction(()=>window.fenshuiStatus.splash.frame<0,null,{timeout:3000});
   check(true,'正常连续播放后水花自动结束，无残留层');
   if(process.env.FENSHUI_EXPECT_SLAM_AREA==='1'){
    // 上一次自然落地可能把玩家击退上岸；巨蛙只追击水中玩家。
    // 使用真实移动返回水中，再等待下一次预警，不注入怪物状态。
    if((await page.evaluate(()=>window.fenshuiStatus.water.depth))<.8){
     await page.keyboard.down('w');
     try{await page.waitForFunction(()=>window.fenshuiStatus.water.depth>.8,null,{timeout:8000,polling:20});}
     finally{await page.keyboard.up('w');}
    }
    await page.waitForFunction(()=>window.fenshuiStatus.slam_area?.visible&&window.fenshuiStatus.slam_area.phase==='warning',null,{timeout:15000,polling:20});
    const warning=await page.evaluate(()=>structuredClone(window.fenshuiStatus.slam_area));
    check(warning.shape.length===128&&warning.shape.every(p=>Math.hypot(p[0]-warning.center[0],p[1]-warning.center[1])<=expectedSlamRadius+.001),'真实预警显示当前砸击半径水域多边形，不再是30扁圈');
    await page.screenshot({path:path.join(out,'slam-area-warning-live.png')});
    await page.waitForFunction(()=>window.fenshuiStatus.slam_area?.visible&&window.fenshuiStatus.slam_area.phase==='airborne',null,{timeout:3000,polling:20});
    const airborne=await page.evaluate(()=>structuredClone(window.fenshuiStatus.slam_area));
    check(JSON.stringify(airborne.shape)===JSON.stringify(warning.shape),'真实腾空期间范围保持在同一落点');
    await page.waitForFunction(()=>window.fenshuiStatus.slam_area?.visible&&window.fenshuiStatus.slam_area.phase==='landing'&&window.fenshuiStatus.splash.frame>=4,null,{timeout:3000,polling:20});
    const landing=await page.evaluate(()=>structuredClone(window.fenshuiStatus.slam_area));
    check(JSON.stringify(landing.shape)===JSON.stringify(warning.shape),'预警、腾空和实际落地共用同一形状');
    await page.screenshot({path:path.join(out,'slam-area-landing-live.png')});
    await page.waitForFunction(()=>!window.fenshuiStatus.slam_area.visible,null,{timeout:3000});
    check(true,'正常播放结束后地面范围无残留');
   }
  }
  if(process.env.FENSHUI_EXPECT_HURT_900==='1'){
   check(s.version==='20261106-G-hurt600-slam900','实际网页运行普通600/巨蛙落地900毫秒新包',s.version);
   await page.waitForFunction(()=>window.__waterSamples.some(x=>x.recovery>0.7&&x.recovery<=0.9&&x.hurt?.kind==='slam'),null,{timeout:5000});
   check(true,'连续正常播放采样到巨蛙落地900毫秒恢复');
   await page.waitForFunction(()=>window.__waterSamples.some(x=>x.recovery>0&&x.recovery<0.2&&x.hurt?.kind==='slam'&&x.hurt.active&&x.hurt.effect_frame<0),null,{timeout:5000});
   check(true,'落地受击700毫秒附近仍保留人物动作，230毫秒接触图已结束');
   await page.waitForFunction(()=>window.fenshuiStatus.hurt_recovery_left===0&&!window.fenshuiStatus.player_hurt.active,null,{timeout:5000});
   check(true,'正常播放完成900毫秒落地恢复并清理动作');
  }
  if(process.env.FENSHUI_EXPECT_CROWD==='1'){
   report.attack_attempts=[];
   await page.keyboard.press('Control+0');
   await page.keyboard.press('Space');
   await page.keyboard.press('Tab');
   let accepted=0;
   for(let attempt=0;attempt<8;attempt++){
    await page.waitForFunction(()=>{const s=window.fenshuiStatus,g=s?.attack_gate;return g&&!g.combat_paused&&!g.recovering&&g.cooldown<=.00001&&g.action_left<=0&&s.hp>0;},null,{timeout:8000,polling:20});
    const before=await page.evaluate(()=>structuredClone(window.fenshuiStatus));
    await canvas.click({position:{x:box.width*.50,y:box.height*.45}});
    await page.waitForFunction(n=>window.fenshuiStatus.attack_gate.clicks>n,before.attack_gate.clicks,{timeout:3000,polling:20});
    await page.waitForFunction(b=>{const s=window.fenshuiStatus;return s.throws>b.throws||s.player_hurt.received>b.player_hurt.received||s.attack_gate.combat_paused;},before,{timeout:3000,polling:20});
    const after=await page.evaluate(()=>structuredClone(window.fenshuiStatus));
    report.attack_attempts.push({before,after});
    // 等待与实际点击之间若出现新的真实伤害，本次拒绝属于既定硬直，不误报丢键。
    if(after.throws===before.throws&&after.player_hurt.received>before.player_hurt.received)continue;
    check(after.throws===before.throws+1,'实际七怪近战画面点击人物位置仍能出招：'+attempt,{before:before.attack_gate,after:after.attack_gate});
    accepted++;
   }
   check(accepted>=3,'连续交战中至少三次角色位置左键被正常接收，未复现永久禁攻',accepted);
   await page.screenshot({path:path.join(out,'crowd-attack-live.png')});
  }
  await page.keyboard.press('Control+0');
  // 岸路并非正南直线：朝真实道路节点走，仍通过实际按键和水深判定上岸。
  const shoreDeadline=Date.now()+15000;
  let held=new Set();
  try{
   while(Date.now()<shoreDeadline){
    const current=await page.evaluate(()=>({hero:window.fenshuiStatus.hero,depth:window.fenshuiStatus.water.depth}));
    if(current.hero[1]>590&&current.depth<.12)break;
    const [x,y]=current.hero, next=new Set();
    if(x<830)next.add('d'); else if(x>842)next.add('a');
    if(y<733)next.add('s'); else if(y>745)next.add('w');
    for(const key of held)if(!next.has(key))await page.keyboard.up(key);
    for(const key of next)if(!held.has(key))await page.keyboard.down(key);
    held=next;
    await page.waitForTimeout(100);
   }
  }finally{for(const key of held)await page.keyboard.up(key);}
  await page.waitForFunction(()=>window.fenshuiStatus.hero[1]>590&&window.fenshuiStatus.water.depth<.12,null,{timeout:1000});
  await page.waitForFunction(()=>window.fenshuiStatus.water.depth<.12,null,{timeout:3000});
  check(true,'真实内部持键从水中走上中央岸路并自然出水');
  await page.screenshot({path:path.join(out,'shore-live.png')});
  const clock=await page.evaluate(()=>window.fenshuiStatus.water.clock);
  await page.waitForFunction(t=>window.fenshuiStatus.water.clock>t+.3,clock,{timeout:3000});
  check(true,'上岸后全图水面仍正常流动');
  report.samples=await page.evaluate(()=>window.__waterSamples);
  check(report.samples.some(x=>x.water?.depth>.8)&&report.samples.some(x=>x.water?.depth<.12&&x.hero[1]>590),'连续采样保留真实水岸过渡');
  check(report.errors.length===0,'无页面异常及引擎脚本/资源错误（渲染警告另列）',report.errors);
 }catch(e){report.error=report.error||String(e);if(page){report.status=await page.evaluate(()=>window.fenshuiStatus).catch(()=>null);await page.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});}}
 finally{clearTimeout(timer);if(browser)await browser.close();report.ended_at=new Date().toISOString();report.passed=!report.error&&!report.errors.length;fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({passed:report.passed,error:report.error,checks:report.checks,errors:report.errors},null,2));if(!report.passed)process.exitCode=1;}
})();
