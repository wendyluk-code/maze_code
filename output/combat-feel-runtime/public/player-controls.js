'use strict';
window.installPlayerControls=function(){
 const box=document.createElement('section');
 box.innerHTML='<h2>角色共用卡肉</h2><small>三项参数对所有对手共用，单位为毫秒；其他角色旧草稿字段未接入。修改后点击“应用候选并重开”预览。保存后，正式游戏重新启动读取；网页导出包需重新导出。</small><nav><label>锅铲卡肉毫秒 <input id="playerHero" type="number" min="0" max="200" step="1"></label><label>芽芽卡肉毫秒 <input id="playerYaya" type="number" min="0" max="200" step="1"></label><label>铁山卡肉毫秒 <input id="playerTieshan" type="number" min="0" max="200" step="1"></label></nav><nav><button id="savePlayer">保存角色共用参数</button><button id="resetPlayer">载入当前角色游戏值</button><label>角色参数历史 <select id="playerHistory"><option value="">请选择历史版本</option></select></label><button id="loadPlayerHistory">载入角色历史</button></nav><div id="playerDataStatus">正在读取角色游戏值…</div><div id="playerMessage" role="status"></div><pre id="playerSnapshot" hidden></pre>';
 document.querySelector('#monsterKind').closest('section').after(box);
 const ids={hero:'playerHero',yaya:'playerYaya',tieshan:'playerTieshan'};
 let saved=null,draft=null;
 const get=async url=>{const r=await fetch(url,{cache:'no-store'}),v=await r.json();if(!r.ok)throw Error(v.error||'读取失败');return v;};
 const render=()=>{for(const [id,element] of Object.entries(ids))document.getElementById(element).value=draft.effects[id].hitstop;window.runtimePlayer=structuredClone(draft);document.querySelector('#playerSnapshot').textContent=JSON.stringify(saved);document.querySelector('#playerDataStatus').textContent='当前游戏值：锅铲 '+saved.effects.hero.hitstop+' / 芽芽 '+saved.effects.yaya.hitstop+' / 铁山 '+saved.effects.tieshan.hitstop+' 毫秒'+(JSON.stringify(draft.effects)!==JSON.stringify(saved.effects)?' · 有未保存修改':'');};
 const history=async()=>{const list=await get('api/game/player/history'),select=document.querySelector('#playerHistory');select.replaceChildren(new Option('请选择历史版本',''));for(const name of list)select.add(new Option(name,name));};
 for(const [id,element] of Object.entries(ids))document.getElementById(element).oninput=event=>{const n=event.target.valueAsNumber;if(draft&&Number.isInteger(n)&&n>=0&&n<=200){draft.effects[id].hitstop=n;window.runtimePlayer=structuredClone(draft);document.querySelector('#playerDataStatus').textContent='角色参数有未保存修改；重开预览后才应用。';}};
 document.querySelector('#resetPlayer').onclick=()=>{if(saved){draft=structuredClone(saved);render();}};
 document.querySelector('#loadPlayerHistory').onclick=async()=>{try{const id=document.querySelector('#playerHistory').value;if(!id)throw Error('请先选择历史版本');draft=await get('api/game/player/history/'+encodeURIComponent(id));render();document.querySelector('#playerMessage').textContent='历史已载入草稿；保存后才恢复游戏，保存前会备份当前值。';}catch(e){document.querySelector('#playerMessage').textContent='读取历史失败：'+e.message;}};
 document.querySelector('#savePlayer').onclick=async event=>{const button=event.currentTarget;button.disabled=true;let committed=false;try{
  if(!draft)throw Error('角色数据尚未就绪');
  for(const element of Object.values(ids)){const n=document.getElementById(element).valueAsNumber;if(!Number.isInteger(n)||n<0||n>200)throw Error('请输入0至200的整数');}
  const r=await fetch('api/game/player',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(draft)}),v=await r.json();if(!r.ok)throw Error(v.error||'保存失败');committed=true;saved=v.data;draft=structuredClone(saved);render();await history();document.querySelector('#playerMessage').textContent='角色共用参数已保存并备份旧值；正式游戏重启后读取。';
 }catch(e){document.querySelector('#playerMessage').textContent=(committed?'游戏已保存，但历史列表刷新失败：':'保存失败，旧游戏值保留：')+e.message;}finally{button.disabled=false;}};
 window.playerEditor={importCandidate:data=>{draft=structuredClone(data);render();},resetAll:()=>{draft=structuredClone(saved);render();}};
 return get('api/game/player').then(data=>{saved=data;draft=structuredClone(data);render();return history();}).catch(e=>{document.querySelector('#playerDataStatus').textContent='角色游戏参数不可用：'+e.message;document.querySelector('#savePlayer').disabled=true;});
};
