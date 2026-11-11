'use strict';
window.installMonsterControls=function(){
 const labels={slime:'史莱姆',snail:'砖壳蜗牛',beetle:'剑甲虫',lizard:'石化蜥蜴',silverfish:'银鳞鱼',thunder_eel:'雷鳗',wind_frog:'风袋巨蛙',mimic_crab:'拟态宝箱蟹',blind_scorpion:'盲水蝎',rockmane:'岩鬃兽'};
 const aliases={silverfish:'fish',thunder_eel:'eel',wind_frog:'frog'};
 const reverse={fish:'silverfish',eel:'thunder_eel',frog:'wind_frog'};
 const oldNav=document.querySelector('#enemy').closest('nav');oldNav.hidden=true;document.querySelector('#enemy').setAttribute('aria-label','旧版分水庭怪物');
 const box=document.createElement('section');
 box.innerHTML='<nav><label for="monsterKind">对打怪物</label><select id="monsterKind"></select><button id="resetArena">重置双方</button><span id="monsterDataStatus">正在读取游戏数据…</span></nav><nav><label for="monsterAttack">怪物攻击基础值</label><input id="monsterAttack" type="number" min="0" max="100" step="1"><button id="saveMonsterAttack">保存当前怪物攻击值到游戏</button><button id="resetMonsterAttack">使用当前游戏值</button></nav><nav><label for="monsterHistory">怪物参数历史</label><select id="monsterHistory"><option value="">请选择历史版本</option></select><button id="loadMonsterHistory">载入历史中当前怪物的值</button></nav><small>攻击值按实际怪物结算；保存前备份完整旧版本，其余怪物不变。重新启动游戏才读取，已经导出的网页包需要重新导出。角色攻击、卡肉和其他招式参数尚未全部接通。</small>';
 oldNav.after(box);
 const select=document.querySelector('#monsterKind'),input=document.querySelector('#monsterAttack'),message=document.querySelector('#message');
 for(const [id,name] of Object.entries(labels))select.add(new Option(name,id));
 select.value=reverse[window.runtimeEnemy]||'wind_frog';
 let saved=null,draft=null;
 const get=async url=>{const r=await fetch(url,{cache:'no-store'});const v=await r.json();if(!r.ok)throw Error(v.error||'读取失败');return v};
 const render=()=>{if(!draft)return;input.value=draft.attack[select.value];document.querySelector('#monsterDataStatus').textContent='当前游戏值：'+saved.attack[select.value]+' · '+(saved.published_at?'更新于 '+new Date(saved.published_at).toLocaleString():'初始版本')+(draft.attack[select.value]!==saved.attack[select.value]?' · 有未保存修改':'');};
 const refreshHistory=async()=>{const list=await get('api/game/monsters/history'),history=document.querySelector('#monsterHistory');history.replaceChildren(new Option('请选择历史版本',''));for(const name of list)history.add(new Option(name,name));};
 const updateControls=()=>{
  const id=select.value,legacy=aliases[id];
  document.querySelector('#fishParameterPanel').hidden=id!=='silverfish';
  document.querySelector('#save').disabled=id!=='silverfish';
  if(legacy){const old=document.querySelector('#enemy');old.value=legacy;old.dispatchEvent(new Event('change'));}
  else {window.runtimeEnemy=id;restart('candidate');}
  render();
 };
 select.onchange=updateControls;
 input.oninput=()=>{const n=input.valueAsNumber;if(!Number.isInteger(n)||n<0||n>100)return;draft.attack[select.value]=n;window.runtimeMonsterAttack=structuredClone(draft);render();};
 document.querySelector('#resetArena').onclick=()=>restart('candidate');
 document.querySelector('#resetMonsterAttack').onclick=()=>{if(!saved)return;draft.attack[select.value]=saved.attack[select.value];window.runtimeMonsterAttack=structuredClone(draft);render();};
 document.querySelector('#saveMonsterAttack').onclick=async event=>{
  const button=event.currentTarget;button.disabled=true;let committed=false;
  try {
   if(!draft||!Number.isInteger(input.valueAsNumber)||input.valueAsNumber<0||input.valueAsNumber>100)throw Error('请输入0至100的整数');
   const latest=await get('api/game/monsters');latest.attack[select.value]=input.valueAsNumber;
   const r=await fetch('api/game/monsters',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(latest)});const result=await r.json();if(!r.ok)throw Error(result.error||'保存失败');
   committed=true;saved=result.data;draft.attack[select.value]=saved.attack[select.value];window.runtimeMonsterAttack=structuredClone(draft);render();
   await refreshHistory();message.textContent=labels[select.value]+'攻击值已写入游戏并备份旧版；其他怪物未改变。重新启动游戏或重新导出网页包后读取。';
  } catch(e){message.textContent=(committed?'游戏已保存，但历史列表刷新失败：':'保存失败，旧游戏值保留：')+e.message;}finally{button.disabled=false;}
 };
 document.querySelector('#loadMonsterHistory').onclick=async()=>{try{const id=document.querySelector('#monsterHistory').value;if(!id)throw Error('请先选择历史版本');const old=await get('api/game/monsters/history/'+encodeURIComponent(id));draft.attack[select.value]=old.attack[select.value];window.runtimeMonsterAttack=structuredClone(draft);render();message.textContent='已载入当前怪物的历史值到草稿；保存后才更新游戏并备份现值。';}catch(e){message.textContent='载入历史失败：'+e.message;}};
 updateControls();
 window.monsterEditor={importCandidate:data=>{draft=structuredClone(data);window.runtimeMonsterAttack=structuredClone(draft);render();},resetAll:()=>{draft=structuredClone(saved);window.runtimeMonsterAttack=structuredClone(draft);render();}};
 return get('api/game/monsters').then(data=>{saved=data;draft=structuredClone(data);window.runtimeMonsterAttack=structuredClone(data);render();return refreshHistory();}).catch(e=>{document.querySelector('#monsterDataStatus').textContent='游戏参数不可用：'+e.message;input.disabled=true;document.querySelector('#saveMonsterAttack').disabled=true;});
};
