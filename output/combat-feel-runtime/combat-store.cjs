'use strict';
const fs=require('node:fs'),path=require('node:path');
const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
function validateValues(values,schema){
 if(!object(values))throw Error('参数必须是对象');
 for(const [group,row] of Object.entries(values)){
  const g=schema.groups[group];if(!g||!object(row))throw Error('未知参数组：'+group);
  for(const [key,n]of Object.entries(row)){
   const f=g.fields[key];if(!f||!f.connected||!f.persist)throw Error('字段未接正式游戏：'+group+'.'+key);
   if(typeof n!=='number'||!Number.isFinite(n)||n<f.min||n>f.max||((['点','颗'].includes(f.unit)||key==='hitstop')&&!Number.isInteger(n)))throw Error('数值无效：'+group+'.'+key);
  }
 }
 return structuredClone(values);
}
function createCombatStore({file,history,schema}){
 function packet(data){if(!object(data)||data.version!==1)throw Error('战斗参数版本错误');validateValues(data.values,schema);return data;}
 function read(){return fs.existsSync(file)?packet(JSON.parse(fs.readFileSync(file,'utf8'))):{version:1,values:{}};}
 function save(input){
  if(!object(input)||typeof input.scope!=='string')throw Error('缺少保存对象');
  const owners=new Set(Object.values(schema.groups).map(g=>g.owner));if(input.scope!=='all'&&!owners.has(input.scope))throw Error('未知保存对象');
  const values=validateValues(input.values,schema),previous=read(),next=structuredClone(previous);
  // 请求携带所选范围的完整草稿；未选择的怪物与共用角色组保留。
  for(const [group,g] of Object.entries(schema.groups))if(input.scope==='all'||g.owner===input.scope)delete next.values[group];
  for(const [group,row]of Object.entries(values))if(input.scope==='all'||schema.groups[group].owner===input.scope)next.values[group]=row;
  next.saved_at=new Date().toISOString();
  fs.mkdirSync(history,{recursive:true});
  const revision=Date.now()+'-'+process.hrtime.bigint()+'.json';
  fs.writeFileSync(path.join(history,revision),JSON.stringify(previous,null,2),{flag:'wx'});
  fs.mkdirSync(path.dirname(file),{recursive:true});
  const temp=file+'.tmp-'+process.pid;
  try{fs.writeFileSync(temp,JSON.stringify(next,null,2));fs.renameSync(temp,file);}finally{if(fs.existsSync(temp))fs.unlinkSync(temp);}
  return {ok:true,data:next,backup:revision,restart_required:true};
 }
 function historical(name){if(!/^[0-9]+-[0-9]+[.]json$/.test(name))throw Error('历史名称错误');return packet(JSON.parse(fs.readFileSync(path.join(history,name),'utf8')));}
 return {read,save,list:()=>fs.existsSync(history)?fs.readdirSync(history).filter(n=>/^[0-9]+-[0-9]+[.]json$/.test(n)).sort().reverse():[],history:historical};
}
module.exports={createCombatStore,validateValues};
