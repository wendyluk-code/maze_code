const fs=require("node:fs");
const path=require("node:path");
const {chromium}=require("C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright");
const url=process.argv[2];
const out=path.resolve(process.argv[3]);
fs.mkdirSync(out,{recursive:true});
const report={url,started_at:new Date().toISOString(),checks:[],errors:[],warnings:[]};
function check(value,label){report.checks.push({passed:!!value,label});if(!value)throw Error(label);}
(async()=>{
 let browser,page;
 const timer=setTimeout(()=>{report.timeout=true;void browser?.close();},180000);
 try{
  browser=await chromium.launch({headless:true,args:["--use-angle=swiftshader","--enable-unsafe-swiftshader","--autoplay-policy=no-user-gesture-required"]});
  report.browser=browser.version();
  const context=await browser.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
  page=await context.newPage();
  page.on("pageerror",e=>report.errors.push(String(e)));
  page.on("console",m=>{const t=m.text();if(/WebGL|GL Driver Message/.test(t))report.warnings.push(t);else if(m.type()==="error"||/SCRIPT ERROR|ERROR:/.test(t))report.errors.push(t);});
  const response=await page.goto(url,{waitUntil:"domcontentloaded",timeout:120000});
  check(response.status()===200,"正式游戏入口返回HTTP 200");
  await page.waitForFunction(()=>!document.getElementById("status"),null,{timeout:150000});
  const canvas=page.locator("canvas#canvas");
  const box=await canvas.boundingBox();
  check(box&&box.width>500&&box.height>300,"正式游戏画布可见并完成加载");
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await page.screenshot({path:path.join(out,"start.png")});
  // 继续游戏只打开隔离浏览器上下文内的存档选择，不操作用户正式存档。
  const scale=Math.min(box.width/1672,box.height/941);
  await canvas.click({position:{x:(box.width-1672*scale)/2+271*scale,y:(box.height-941*scale)/2+700*scale}});
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await page.screenshot({path:path.join(out,"continue.png")});
  check(report.errors.length===0,"启动及点击期间没有页面或引擎脚本错误");
 }catch(e){report.error=String(e);if(page)await page.screenshot({path:path.join(out,"failure.png")}).catch(()=>{});}
 finally{clearTimeout(timer);if(browser)await browser.close();report.ended_at=new Date().toISOString();report.passed=!report.error&&!report.timeout&&!report.errors.length;fs.writeFileSync(path.join(out,"report.json"),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));if(!report.passed)process.exitCode=1;}
})().catch(e=>{console.error(e);process.exitCode=1;});
