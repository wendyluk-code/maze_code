const assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path");
const sharp=require("C:/Users/KSG/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp");
(async()=>{let checks=0;for(const name of ["01-charge","02-water-area","03-hit-break"]){
 const original=path.resolve("output/fenshui-attack-vfx",name+".png");
 for(let i=0;i<4;i++){
  const target=path.resolve("assets/effects/fenshui",name+"-"+i+".png");
  assert(fs.existsSync(target),"缺生产切图："+target);
  const source=await sharp(original).extract({left:(i%2)*627,top:Math.floor(i/2)*627,width:627,height:627}).ensureAlpha().raw().toBuffer();
  const meta=await sharp(target).metadata();assert.equal(meta.width,787);assert.equal(meta.height,787);
  const restored=await sharp(target).extract({left:80,top:80,width:627,height:627}).ensureAlpha().raw().toBuffer();
  assert(source.equals(restored),"补边不得改变原格任何像素");
  const raw=await sharp(target).ensureAlpha().raw().toBuffer();
  for(let y=0;y<787;y++)for(let x=0;x<787;x++)if(x<80||y<80||x>=707||y>=707)assert.equal(raw[(y*787+x)*4+3],0,"新增边距必须完全透明");
  checks++;
 }
}console.log(JSON.stringify({checks,passed:true}));})().catch(e=>{console.error(e.message);process.exitCode=1});
