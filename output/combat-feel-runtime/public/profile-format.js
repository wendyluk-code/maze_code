(function(root){
 'use strict';
 const enemies={fish:'银鳞鱼',eel:'电鳗',frog:'巨蛙'};
 const units='world_offsets_percent_sizes_milliseconds';
 const clone=x=>JSON.parse(JSON.stringify(x));
 function makeBundle(spec){return {version:4,baseline:spec.baseline,runtime_revision:'20261106-editor-profiles-K-hurt',units,selected_enemy:'frog',profiles:Object.fromEntries(Object.keys(enemies).map(id=>[id,{version:3,baseline:spec.baseline,mode:'candidate',units,effects:clone(spec.defaults),saved_at:null}])),published_at:null};}
 function validatePacket(p,spec){
  if(!p||p.version!==3||p.baseline!==spec.baseline||p.units!==units||!p.effects||Array.isArray(p.effects))throw Error('参数版本、基准或单位不一致');
  if(Object.keys(p.effects).sort().join()!==Object.keys(spec.defaults).sort().join())throw Error('招式集合不完整');
  for(const [kind,row]of Object.entries(p.effects)){
   if(!row||Object.keys(row).sort().join()!==Object.keys(spec.defaults[kind]).sort().join())throw Error('参数字段不完整：'+kind);
   for(const [key,n]of Object.entries(row)){const f=spec.fields[key];if(typeof n!=='number'||!Number.isFinite(n)||n<f.min||n>f.max)throw Error('参数越界：'+kind+'.'+key);}
  }
  return clone(p);
 }
 function validateBundle(b,spec){
  if(!b||b.version!==4||![spec.baseline,'20261106-I-splash-hurt-repair'].includes(b.baseline)||b.runtime_revision!=='20261106-editor-profiles-K-hurt'||b.units!==units||!Object.hasOwn(enemies,b.selected_enemy)||!b.profiles||Object.keys(b.profiles).sort().join()!==Object.keys(enemies).sort().join())throw Error('怪物集合、运行版本或单位不匹配');
  const result=clone(b);result.baseline=spec.baseline;for(const id of Object.keys(enemies)){if(b.profiles[id].baseline!==b.baseline)throw Error('怪物基准不一致');result.profiles[id]=validatePacket({...b.profiles[id],baseline:spec.baseline},spec);}return result;
 }
 const api={enemies,units,makeBundle,validatePacket,validateBundle};
 if(typeof module!=='undefined')module.exports=api;else root.ProfileFormat=api;
})(typeof globalThis!=='undefined'?globalThis:this);
