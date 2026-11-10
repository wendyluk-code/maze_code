const http=require('node:http'),fs=require('node:fs'),path=require('node:path');
const {validateBundle}=require('./public/profile-format.js');
const root=path.join(__dirname,'public'),output=path.join(__dirname,'parameters');
const {createCombatStore}=require('./combat-store.cjs');
const combatSchema=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../data/maze/combat_tuning_schema.json'),'utf8'));
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.json':'application/json','.png':'image/png','.svg':'image/svg+xml'};
const monsterKinds=['slime','snail','beetle','lizard','silverfish','thunder_eel','wind_frog','mimic_crab','blind_scorpion','rockmane'];
function validatePlayer(data){
 const ids=['hero','yaya','tieshan'];
 if(!data || data.version!==1 || !data.effects || Array.isArray(data.effects) || Object.keys(data.effects).sort().join()!==ids.sort().join())throw Error('角色参数集合不完整');
 for(const id of ids){const row=data.effects[id];if(!row || Object.keys(row).join()!=='hitstop' || !Number.isInteger(row.hitstop) || row.hitstop<0 || row.hitstop>200)throw Error('角色卡肉参数无效：'+id);}
 return {version:1,effects:data.effects,...(typeof data.published_at==='string'?{published_at:data.published_at}:{})};
}
function validateMonsters(data){
 if(!data || data.version!==1 || !data.attack || Array.isArray(data.attack) || Object.keys(data.attack).sort().join()!==[...monsterKinds].sort().join())throw Error('怪物攻击值集合不完整');
 for(const [kind,value] of Object.entries(data.attack))if(!Number.isInteger(value)||value<0||value>100)throw Error('怪物攻击值越界：'+kind);
 return {version:1,attack:data.attack,...(typeof data.published_at==='string'?{published_at:data.published_at}:{})};
}
function validateFish(data){
 const spec=JSON.parse(fs.readFileSync(path.join(root,'schema.json'),'utf8'));
 const keys=Object.keys(spec.defaults.fish).sort().join();
 if(!data || data.version!==1 || data.monster!=='silverfish' || !data.fish || Array.isArray(data.fish) || Object.keys(data.fish).sort().join()!==keys)throw Error('银鳞鱼参数格式不匹配');
 for(const [key,n] of Object.entries(data.fish)){const rule=spec.fields[key];if(typeof n!=='number' || !Number.isFinite(n) || n<rule.min || n>rule.max)throw Error('银鳞鱼参数越界：'+key);}
 return {version:1,monster:'silverfish',fish:data.fish,...(typeof data.published_at==='string'?{published_at:data.published_at}:{})};
}
function createServer({port=8777,outputDir=output,gameFile=path.resolve(__dirname,"../../data/maze/silverfish_editor.json"),gameHistoryDir=path.join(output,"game-history"),monsterFile=path.resolve(__dirname,"../../data/maze/monster_attack.json"),monsterHistoryDir=path.join(output,"monster-history"),playerFile=path.resolve(__dirname,"../../data/maze/player_combat_editor.json"),playerHistoryDir=path.join(output,"player-history")}={}){
 const combat=createCombatStore({file:process.env.MAZE_EDITOR_TEST_COMBAT_FILE||path.resolve(__dirname,'../../data/maze/combat_tuning.json'),history:process.env.MAZE_EDITOR_TEST_COMBAT_HISTORY||path.join(output,'combat-history'),schema:combatSchema});
 const json=(res,code,data)=>{res.writeHead(code,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
 const server=http.createServer((req,res)=>{
  let name;try{name=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname)}catch{return json(res,400,{error:'地址无效'})}
  if(name==='/editor-tuning.json')return json(res,200,combatSchema);
  if(name==='/api/game/combat/history' && req.method==='GET'){
   try{return json(res,200,combat.list())}catch(e){return json(res,500,{error:e.message})}
  }
  if(name.startsWith('/api/game/combat/history/') && req.method==='GET'){
   try{return json(res,200,combat.history(name.slice('/api/game/combat/history/'.length)))}catch(e){return json(res,400,{error:e.message})}
  }
  if(name==='/api/game/combat'){
   if(req.method==='GET'){
    try{
     const saved=combat.read(),effective={};
     for(const [group,g]of Object.entries(combatSchema.groups))for(const [key,f]of Object.entries(g.fields))if(f.connected&&f.persist)(effective[group]??={})[key]=f.game_default??f.default;
     const attacks=validateMonsters(JSON.parse(fs.readFileSync(monsterFile,'utf8'))).attack;
     for(const [kind,n]of Object.entries(attacks))effective['base.'+kind].attack=n;
     const player=validatePlayer(JSON.parse(fs.readFileSync(playerFile,'utf8'))).effects;
     for(const [kind,row]of Object.entries(player))effective['effect.'+kind].hitstop=row.hitstop;
     Object.assign(effective['effect.fish'],validateFish(JSON.parse(fs.readFileSync(gameFile,'utf8'))).fish);
     for(const [group,g]of Object.entries(combatSchema.groups))if(g.fields.damage?.persist&&attacks[g.owner]!==undefined)effective[group].damage=attacks[g.owner];
     const defaults=structuredClone(effective);
     for(const [group,row]of Object.entries(saved.values))Object.assign(effective[group]??={},row);
     for(const [group,g]of Object.entries(combatSchema.groups))if(g.fields.damage?.persist&&attacks[g.owner]!==undefined&&saved.values[group]?.damage===undefined)effective[group].damage=effective['base.'+g.owner].attack;
     return json(res,200,{...saved,effective,defaults});
    }catch(e){return json(res,500,{error:e.message})}
   }
   if(req.method!=='POST')return json(res,405,{error:'仅允许读取或保存'});
   const port=server.address().port;
   if(req.headers.origin&&!['http://127.0.0.1:'+port,'http://localhost:'+port].includes(req.headers.origin))return json(res,403,{error:'仅允许编辑器本机来源'});
   if(!(req.headers['content-type']||'').startsWith('application/json'))return json(res,415,{error:'仅接受JSON'});
   let body='',large=false;
   req.on('data',chunk=>{if(!large){body+=chunk;if(body.length>262144){large=true;body='';}}});
   req.on('end',()=>{if(large)return json(res,413,{error:'参数文件过大'});try{return json(res,200,combat.save(JSON.parse(body)))}catch(e){return json(res,400,{error:e.message})}});return;
  }
  if(name==='/editor-instance.json' && req.method==='GET')return json(res,200,{editor:'maze-combat-editor',workspace:path.resolve(__dirname,'../..')});
  if(name==='/game/latest.json' && req.method==='GET'){
   try{return json(res,200,{silverfish:validateFish(JSON.parse(fs.readFileSync(gameFile,'utf8'))),monsters:validateMonsters(JSON.parse(fs.readFileSync(monsterFile,'utf8'))),player:validatePlayer(JSON.parse(fs.readFileSync(playerFile,'utf8')))})}catch(e){return json(res,500,{error:'读取游戏最新版失败：'+e.message})}
  }
  if(name==='/api/game/player/history' && req.method==='GET'){
   try{return json(res,200,fs.existsSync(playerHistoryDir)?fs.readdirSync(playerHistoryDir).filter(f=>/^[0-9T-Z-]+\.json$/.test(f)).sort().reverse():[])}catch(e){return json(res,500,{error:'读取历史失败：'+e.message})}
  }
  if(name.startsWith('/api/game/player/history/') && req.method==='GET'){
   const file=name.slice('/api/game/player/history/'.length);
   if(!/^[0-9T-Z-]+\.json$/.test(file))return json(res,400,{error:'历史版本名称无效'});
   try{return json(res,200,validatePlayer(JSON.parse(fs.readFileSync(path.join(playerHistoryDir,file),'utf8'))))}catch(e){return json(res,404,{error:'历史版本不可读取：'+e.message})}
  }
  if(name==='/api/game/player'){
   if(req.method==='GET'){try{return json(res,200,validatePlayer(JSON.parse(fs.readFileSync(playerFile,'utf8'))))}catch(e){return json(res,500,{error:'读取角色参数失败：'+e.message})}}
   if(req.method!=='POST')return json(res,405,{error:'仅允许读取或保存'});
   const actualPort=server.address().port;
   if(req.headers.origin && req.headers.origin!=='http://127.0.0.1:'+actualPort && req.headers.origin!=='http://localhost:'+actualPort)return json(res,403,{error:'仅允许编辑器本机来源'});
   if(!(req.headers['content-type']||'').startsWith('application/json'))return json(res,415,{error:'仅接受JSON'});
   let body='',large=false;
   req.on('data',chunk=>{if(large)return;body+=chunk;if(body.length>262144){large=true;body='';}});
   req.on('end',()=>{if(large)return json(res,413,{error:'参数文件过大'});try{
    const next=validatePlayer(JSON.parse(body));
    const old=fs.readFileSync(playerFile,'utf8');validatePlayer(JSON.parse(old));
    fs.mkdirSync(playerHistoryDir,{recursive:true});
    const revision=new Date().toISOString().replace(/[:.]/g,'-')+'-'+process.hrtime.bigint();
    const backup=path.join(playerHistoryDir,revision+'.json');fs.writeFileSync(backup,old,{flag:'wx'});
    next.published_at=new Date().toISOString();
    const temp=playerFile+'.'+revision+'.tmp';fs.writeFileSync(temp,JSON.stringify(next,null,2)+'\n',{flag:'wx'});fs.renameSync(temp,playerFile);
    return json(res,200,{ok:true,backup,data:next});
   }catch(e){return json(res,400,{error:'保存失败，原游戏参数保留：'+e.message})}});return;
  }
  if(name==='/api/game/monsters/history' && req.method==='GET'){
   try{return json(res,200,fs.existsSync(monsterHistoryDir)?fs.readdirSync(monsterHistoryDir).filter(f=>/^[0-9T-Z-]+\.json$/.test(f)).sort().reverse():[])}catch(e){return json(res,500,{error:'读取历史失败：'+e.message})}
  }
  if(name.startsWith('/api/game/monsters/history/') && req.method==='GET'){
   const file=name.slice('/api/game/monsters/history/'.length);
   if(!/^[0-9T-Z-]+\.json$/.test(file))return json(res,400,{error:'历史版本名称无效'});
   try{return json(res,200,validateMonsters(JSON.parse(fs.readFileSync(path.join(monsterHistoryDir,file),'utf8'))))}catch(e){return json(res,404,{error:'历史版本不可读取：'+e.message})}
  }
  if(name==='/api/game/monsters'){
   if(req.method==='GET'){try{return json(res,200,validateMonsters(JSON.parse(fs.readFileSync(monsterFile,'utf8'))))}catch(e){return json(res,500,{error:'读取怪物参数失败：'+e.message})}}
   if(req.method!=='POST')return json(res,405,{error:'仅允许读取或保存'});
   const actualPort=server.address().port;
   if(req.headers.origin && req.headers.origin!=='http://127.0.0.1:'+actualPort && req.headers.origin!=='http://localhost:'+actualPort)return json(res,403,{error:'仅允许编辑器本机来源'});
   if(!(req.headers['content-type']||'').startsWith('application/json'))return json(res,415,{error:'仅接受JSON'});
   let body='',large=false;
   req.on('data',chunk=>{if(large)return;body+=chunk;if(body.length>262144){large=true;body='';}});
   req.on('end',()=>{if(large)return json(res,413,{error:'参数文件过大'});try{
    const next=validateMonsters(JSON.parse(body));
    const old=fs.readFileSync(monsterFile,'utf8');validateMonsters(JSON.parse(old));
    fs.mkdirSync(monsterHistoryDir,{recursive:true});
    const revision=new Date().toISOString().replace(/[:.]/g,'-')+'-'+process.hrtime.bigint();
    const backup=path.join(monsterHistoryDir,revision+'.json');
    fs.writeFileSync(backup,old,{flag:'wx'});
    next.published_at=new Date().toISOString();
    const temp=monsterFile+'.'+revision+'.tmp';
    fs.writeFileSync(temp,JSON.stringify(next,null,2)+'\n',{flag:'wx'});
    fs.renameSync(temp,monsterFile);
    return json(res,200,{ok:true,backup,data:next});
   }catch(e){return json(res,400,{error:'保存失败，原游戏参数保留：'+e.message})}});return;
  }
  if(name==='/api/game/silverfish/history' && req.method==='GET'){
   try{return json(res,200,fs.existsSync(gameHistoryDir)?fs.readdirSync(gameHistoryDir).filter(f=>/^[0-9T-Z-]+\.json$/.test(f)).sort().reverse():[])}catch(e){return json(res,500,{error:'读取历史失败：'+e.message})}
  }
  if(name.startsWith('/api/game/silverfish/history/') && req.method==='GET'){
   const file=name.slice('/api/game/silverfish/history/'.length);
   if(!/^[0-9T-Z-]+\.json$/.test(file))return json(res,400,{error:'历史版本名称无效'});
   try{return json(res,200,validateFish(JSON.parse(fs.readFileSync(path.join(gameHistoryDir,file),'utf8'))))}catch(e){return json(res,404,{error:'历史版本不可读取：'+e.message})}
  }
  if(name==='/api/game/silverfish'){
   if(req.method==='GET'){try{return json(res,200,validateFish(JSON.parse(fs.readFileSync(gameFile,'utf8'))))}catch(e){return json(res,500,{error:'读取游戏参数失败：'+e.message})}}
   if(req.method!=='POST')return json(res,405,{error:'仅允许读取或保存'});
   const actualPort=server.address().port;
   if(req.headers.origin && req.headers.origin!=='http://127.0.0.1:'+actualPort && req.headers.origin!=='http://localhost:'+actualPort)return json(res,403,{error:'仅允许编辑器本机来源'});
   if(!(req.headers['content-type']||'').startsWith('application/json'))return json(res,415,{error:'仅接受JSON'});
   let body='',large=false;
   req.on('data',chunk=>{if(large)return;body+=chunk;if(body.length>262144){large=true;body='';}});
   req.on('end',()=>{if(large)return json(res,413,{error:'参数文件过大'});try{
    const next=validateFish(JSON.parse(body));
    const old=fs.readFileSync(gameFile,'utf8');validateFish(JSON.parse(old));
    fs.mkdirSync(gameHistoryDir,{recursive:true});
    const revision=new Date().toISOString().replace(/[:.]/g,'-')+'-'+process.hrtime.bigint();
    const backup=path.join(gameHistoryDir,revision+'.json');
    fs.writeFileSync(backup,old,{flag:'wx'});
    next.published_at=new Date().toISOString();
    const temp=gameFile+'.'+revision+'.tmp';
    fs.writeFileSync(temp,JSON.stringify(next,null,2)+'\n',{flag:'wx'});
    fs.renameSync(temp,gameFile);
    return json(res,200,{ok:true,backup,data:next});
   }catch(e){return json(res,400,{error:'保存失败，原游戏参数保留：'+e.message})}});return;
  }
  if(name==='/api/publish'){
   if(req.method!=='POST')return json(res,405,{error:'仅允许发布请求'});
   const actualPort=server.address().port;
   if(req.headers.origin && req.headers.origin!=='http://127.0.0.1:'+actualPort && req.headers.origin!=='http://localhost:'+actualPort)return json(res,403,{error:'仅允许编辑器本机来源'});
   if(!(req.headers['content-type']||'').startsWith('application/json'))return json(res,415,{error:'仅接受JSON'});
   let body='',large=false;
   req.on('data',chunk=>{if(large)return;body+=chunk;if(body.length>262144){large=true;body='';}});
   req.on('end',()=>{if(large)return json(res,413,{error:'参数文件过大'});try{
    const spec=JSON.parse(fs.readFileSync(path.join(root,'schema.json'),'utf8'));
    const bundle=validateBundle(JSON.parse(body),spec);bundle.published_at=new Date().toISOString();
    const data=JSON.stringify(bundle,null,2),history=path.join(outputDir,'history');fs.mkdirSync(history,{recursive:true});
    const revision=bundle.published_at.replace(/[:.]/g,'-')+'-'+process.hrtime.bigint();
    fs.writeFileSync(path.join(history,revision+'.json'),data,{flag:'wx'});
    const temp=path.join(outputDir,'latest.tmp');fs.writeFileSync(temp,data);fs.renameSync(temp,path.join(outputDir,'latest.json'));
    json(res,200,{ok:true,revision,published_at:bundle.published_at,path:path.join(outputDir,'latest.json')});
   }catch(e){json(res,400,{error:e.message})}});return;
  }
  if(name==='/parameters/latest.json'){
   if(req.method!=='GET')return json(res,405,{error:'仅允许读取'});
   try{const b=JSON.parse(fs.readFileSync(path.join(outputDir,'latest.json'),'utf8'));return json(res,200,b)}catch(e){return json(res,e.code==='ENOENT'?404:500,{error:e.code==='ENOENT'?'尚未发布最新版':e.message})}
  }
  if(!['GET','HEAD'].includes(req.method))return json(res,405,{error:'不支持该操作'});
  const entry=name==='/' || name==='/editor.html';
  const file=entry?path.resolve(__dirname,'../combat-feel-playground/preview.html'):path.resolve(root,'.'+name);if(!entry && !file.startsWith(root+path.sep))return json(res,403,{error:'禁止访问'});
  fs.stat(file,(err,s)=>{if(err||!s.isFile()){res.writeHead(404);return res.end('Not found')};res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Content-Length':s.size,'Cache-Control':'no-cache'});if(req.method==='HEAD')return res.end();fs.createReadStream(file).pipe(res)});
 });return server;
}
module.exports={createServer};
