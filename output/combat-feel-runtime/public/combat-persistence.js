'use strict';
window.installCombatPersistence=async function(schema){
 const q=s=>document.querySelector(s);let saved=null;
 const buttons=['saveCurrentCombat','saveRoleCombat','saveAllCombat','loadCombatGame','loadCombatHistory'];
 const message=text=>q('#combatSaveMessage').textContent=text;
 const get=async url=>{const r=await fetch(url,{cache:'no-store'}),data=await r.json();if(!r.ok)throw Error(data.error||'读取失败');return data;};
 const titles={baseline:'重新读取正式参数并重开训练场，不写游戏',apply:'把当前草稿应用到新训练场，不保存正式参数',wide:'只切换侧栏布局',saveTraining:'保存当前候选到这个浏览器，不写正式游戏',loadTraining:'载入本机候选并重开训练场',exportTraining:'下载完整候选JSON，不写正式游戏',importTraining:'校验候选JSON并重开训练场',saveCurrentCombat:'备份后只保存当前怪物的参数，不改其他怪物和角色共用参数',saveAllCombat:'备份后保存所有可用于正式游戏的参数；训练开关不保存',loadCombatGame:'重新读取磁盘正式值到草稿，再点应用预览',loadCombatHistory:'历史只载入草稿，需再次保存才恢复正式游戏'};
 for(const [id,title]of Object.entries(titles))q('#'+id).title=title;
 q('#saveRoleCombat').title='只保存已接正式游戏的角色参数，不改怪物；保存前会备份';
 for(const id of ['save','publish','loadLatest','export','import','reset','saveMonsterAttack','savePlayer','loadGameFish','loadFishHistory','loadMonsterHistory','loadPlayerHistory']){const node=q('#'+id);if(node){node.disabled=true;node.hidden=true;}}
 q('#legacyTools').hidden=true;
 q('#gameSaveDock').closest('details').hidden=true;
 for(const id of ['attackParameterDock','playerDock','fishParameterPanel'])q('#'+id).style.display='none';
 q('#monsterDataStatus').hidden=true;
 async function refresh(){saved=await get('api/game/combat');const list=await get('api/game/combat/history');q('#combatHistory').replaceChildren(new Option('选择历史备份',''),...list.map(n=>new Option(n,n)));return saved;}
 function draftValues(scope){
  const values=structuredClone(window.runtimeTuning||{});
  for(const [kind,n]of Object.entries(window.runtimeMonsterAttack?.attack||{}))(values['base.'+kind]??={}).attack=n;
  const selected={},blocked=[];
  for(const [group,row]of Object.entries(values)){
   const g=schema.groups[group];if(!g)throw Error('未知参数组：'+group);
   if(scope!=='all'&&g.owner!==scope)continue;
   for(const [key,n]of Object.entries(row)){
    const f=g.fields[key];if(!f?.connected)continue;
    if(!f.persist){blocked.push(g.label+'／'+f.label);continue;}
    (selected[group]??={})[key]=n;
   }
  }
  if(blocked.length&&scope!=='player')throw Error('以下字段只有候选消费者，不能保存到正式游戏：'+blocked.join('、')+'。请先导出保留候选，再重新读取游戏参数。');
  return selected;
 }
 async function save(scope){
  for(const id of buttons)q('#'+id).disabled=true;
  try{
   if(q('#tuningPanel input:invalid'))throw Error('存在无效输入，尚未保存');
   const latest=await get('api/game/combat'),values=draftValues(scope),diff=[];
   const omitted=scope==='player'?Object.entries(window.runtimeTuning||{}).flatMap(([group,row])=>Object.keys(row).filter(key=>schema.groups[group]?.owner==='player'&&schema.groups[group].fields[key]?.persist===false).map(key=>schema.groups[group].fields[key].label)):[];
   const omittedText=omitted.length?'以下候选字段未写正式游戏，仍保留草稿供本机保存／导出：'+omitted.join('、'):'';
   for(const [group,row]of Object.entries(values))for(const [key,n]of Object.entries(row))if(latest.effective[group]?.[key]!==n)diff.push(schema.groups[group].label+'／'+schema.groups[group].fields[key].label+'：'+latest.effective[group]?.[key]+' → '+n);
   if(omitted.length&&diff.length)diff.push(omittedText);
   q('#combatSaveDiff').textContent=diff.length?diff.join('\n'):'没有数值差异';
   if(!diff.length){message('已接字段没有数值差异，未写入文件。'+omittedText);return;}
   if(!confirm('确认保存到正式游戏参数？\n'+diff.join('\n')+'\n保存前备份。源码游戏重启／网页重新导出后读取；不修改存档。')){message('已取消，正式参数未改变。');return;}
   const response=await fetch('api/game/combat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({scope,values})});const result=await response.json();if(!response.ok)throw Error(result.error);
   message('已写入正式参数并备份 '+result.backup+'；当前运行游戏未热更新。源码游戏需重启，网页需重新导出。'+omittedText);
   await refresh();
  }catch(e){message('保存未完成：'+e.message);}finally{for(const id of buttons)q('#'+id).disabled=false;}
 }
 q('#saveCurrentCombat').onclick=()=>save(q('#monsterKind').value);
 q('#saveRoleCombat').onclick=()=>save('player');
 q('#saveAllCombat').onclick=()=>save('all');
 q('#loadCombatGame').onclick=async()=>{try{await refresh();applyTuningCandidate(saved.effective);message('正式参数已载入草稿；点击应用候选并重开后预览，未写文件。');}catch(e){message('读取失败：'+e.message);}};
 q('#baseline').onclick=async()=>{try{await refresh();applyTuningCandidate(saved.effective);restart('candidate');message('已重新读取正式参数并重开训练场。');}catch(e){message('读取失败，原训练场保留：'+e.message);}};
 q('#loadCombatHistory').onclick=async()=>{try{const id=q('#combatHistory').value;if(!id)throw Error('请先选择历史');const history=await get('api/game/combat/history/'+encodeURIComponent(id));await refresh();const next=structuredClone(saved.defaults);for(const [g,row]of Object.entries(history.values))Object.assign(next[g]??={},row);for(const [group,g]of Object.entries(schema.groups))if(g.fields.damage?.persist&&next['base.'+g.owner]&&history.values[group]?.damage===undefined)next[group].damage=next['base.'+g.owner].attack;applyTuningCandidate(next);message('历史已载入草稿，未修改正式值；应用预览或再次保存后恢复。');}catch(e){message('历史读取失败：'+e.message);}};
 try{
  await refresh();let seedPreview=false;
  if(Object.keys(window.runtimeTuning||{}).length===0){
   const initial=structuredClone(saved.effective);
   for(const [group,g]of Object.entries(schema.groups))for(const [key,f]of Object.entries(g.fields))if(f.game_default!==undefined&&saved.values[group]?.[key]===undefined)(initial[group]??={})[key]=f.default;
   // 只将仍为原单发弹速的芽芽带入本次慢速候选，不覆盖用户另调的速度。
   if(Math.abs(Number(initial['effect.yaya']?.speed)-310/0.6)<0.001){initial['effect.yaya'].speed=310;seedPreview=true;}
   applyTuningCandidate(initial);restart('candidate');
  }
  message('已读取正式参数作基准；岩鬃兽未正式保存的差异项沿用已确认候选（160单位、1.2秒蓄力、5秒力竭）。'+(seedPreview?'芽芽本次仅预览310单位/秒慢速弹道，未保存正式游戏。':'')+'正式保存前显示差异；用游戏基准重开会读取正式值。');
  for(const id of buttons)q('#'+id).disabled=false;
 }catch(e){message('正式参数读取失败，保存保持禁用：'+e.message);}
};
