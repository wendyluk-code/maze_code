const fs=require("node:fs");
const path=require("node:path");
const {chromium}=require("C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright");
const [url,outArg,fixture]=process.argv.slice(2);
const out=path.resolve(outArg);fs.mkdirSync(out,{recursive:true});
const report={url,fixture,started_at:new Date().toISOString(),checks:[],errors:[],warnings:[]};
function check(value,label){report.checks.push({passed:!!value,label});if(!value)throw Error(label);}
(async()=>{
 let browser,page;
 const timer=setTimeout(()=>{report.timeout=true;void browser?.close();},180000);
 try{
  const save=JSON.parse(fs.readFileSync(fixture,"utf8"));
  check(save.maze_exploration?.region==="salt_pool","夹具来自隔离盐池存档");
  browser=await chromium.launch({headless:true,args:["--use-angle=swiftshader","--enable-unsafe-swiftshader","--autoplay-policy=no-user-gesture-required"]});
  report.browser=browser.version();
  const context=await browser.newContext({viewport:{width:1280,height:720},ignoreHTTPSErrors:true});
  page=await context.newPage();
  page.on("pageerror",e=>report.errors.push(String(e)));
  page.on("console",m=>{const t=m.text();if(/WebGL|GL Driver Message/.test(t))report.warnings.push(t);else if(m.type()==="error"||/SCRIPT ERROR|ERROR:/.test(t))report.errors.push(t);});
  await page.goto(url,{waitUntil:"domcontentloaded",timeout:120000});
  await page.waitForFunction(()=>!document.getElementById("status"),null,{timeout:120000});
  let canvas=page.locator("canvas#canvas");
  await canvas.click({position:{x:210,y:470}});
  await page.waitForFunction(async()=>new Promise(resolve=>{const q=indexedDB.open("/userfs");q.onsuccess=()=>{const d=q.result;const r=d.transaction("FILE_DATA").objectStore("FILE_DATA").getAllKeys();r.onsuccess=()=>{resolve(r.result.some(k=>String(k).includes("/saves/")&&String(k).endsWith(".json")));d.close();}};}),null,{timeout:15000});
  // 离开游戏页后再注入隔离存档，使用已存在的静态资源，避免制造404。
  await page.goto(new URL("/index.icon.png",url).href);
  const seeded=await page.evaluate(async data=>new Promise((resolve,reject)=>{
   const q=indexedDB.open("/userfs");q.onerror=()=>reject(String(q.error));q.onsuccess=()=>{
    const db=q.result,tx=db.transaction("FILE_DATA","readwrite"),store=tx.objectStore("FILE_DATA"),keys=store.getAllKeys();
    keys.onsuccess=()=>{const key=keys.result.find(k=>String(k).includes("/saves/")&&String(k).endsWith(".json"));if(!key){reject(Error("隔离存档槽不存在"));return;}
     const read=store.get(key);read.onsuccess=()=>{const entry=read.result;data._save_slot.id=String(key).split("/").pop().replace(/\.json$/,"");entry.contents=new TextEncoder().encode(JSON.stringify(data));entry.timestamp=new Date();store.put(entry,key);};
    };tx.oncomplete=()=>{db.close();resolve(true);};tx.onerror=()=>reject(String(tx.error));
   };
  }),save);
  check(seeded,"独立浏览器存档槽载入隔离检查点");
  await page.goto(url,{waitUntil:"domcontentloaded",timeout:120000});
  await page.waitForFunction(()=>!document.getElementById("status"),null,{timeout:120000});
  canvas=page.locator("canvas#canvas");
  await canvas.click({position:{x:210,y:535}});
  await page.screenshot({path:path.join(out,"slots.png")});
  await canvas.click({position:{x:500,y:285}});
  await canvas.click({position:{x:850,y:565}});
  await page.waitForTimeout(6500);
  await page.screenshot({path:path.join(out,"restored.png")});
  await page.keyboard.press("e");
  await page.waitForTimeout(700);
  await page.screenshot({path:path.join(out,"salt-interaction.png")});
  await canvas.click({position:{x:743,y:383}});
  await page.waitForTimeout(6500);
  await page.screenshot({path:path.join(out,"returned-fenshui.png")});
  await page.keyboard.press("e");
  await page.waitForTimeout(1000);
  await page.screenshot({path:path.join(out,"fenshui-interaction.png")});
  await canvas.click({position:{x:580,y:44}});
  await page.waitForTimeout(700);
  await page.screenshot({path:path.join(out,"return-salt-confirm.png")});
  await canvas.click({position:{x:743,y:383}});
  await page.waitForTimeout(6500);
  await page.screenshot({path:path.join(out,"returned-salt.png")});
  check(report.errors.length===0,"读取隔离存档期间没有页面或引擎错误");
 }catch(e){report.error=String(e);if(page)await page.screenshot({path:path.join(out,"failure.png")}).catch(()=>{});}
 finally{clearTimeout(timer);if(browser)await browser.close();report.ended_at=new Date().toISOString();report.passed=!report.error&&!report.timeout&&!report.errors.length;fs.writeFileSync(path.join(out,"report.json"),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));if(!report.passed)process.exitCode=1;}
})().catch(e=>{console.error(e);process.exitCode=1;});
