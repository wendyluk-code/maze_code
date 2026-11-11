'use strict';
window.initializeProfiles=async function(){
 document.querySelector('main>p').textContent='单怪训练候选：按怪物原地图、真实战斗与共用模块运行。十种怪物基础攻击值、银鳞鱼受击参数和角色共用卡肉可保存到游戏；其他旧字段尚未接通，旧草稿保留。';
 document.querySelector('details:last-of-type p').textContent='十种怪物攻击基础值、银鳞鱼鱼冲撞受击参数及独立角色卡肉参数可保存到游戏；其他旧招式字段仍只存浏览器。正式游戏重新启动后读取；已导出网页包需要重新导出，当前运行页面不会自动更新。训练场是隔离候选，不能替代正式游戏验收。';
 const F=window.ProfileFormat,key='fenshui-runtime-monsters-v4',names=F.enemies;
 let saved=F.makeBundle(spec),drafts={},selected='frog';
 const hasOldSaved=Boolean(localStorage.getItem(key)||localStorage.getItem('fenshui-runtime-editor-v3'));
 try{const raw=localStorage.getItem(key);if(raw)saved=F.validateBundle(JSON.parse(raw),spec);else if(localStorage.getItem('fenshui-runtime-editor-v3')){
  for(const id of Object.keys(names))saved.profiles[id]={...packet(),saved_at:null};
  $('#message').textContent='已将旧共享草稿复制到三类怪物，各自独立保存；旧存储未删除。';
 }}catch(e){$('#message').textContent='保存集合未加载，原记录保留：'+e.message;}
 selected=saved.selected_enemy;$('#enemy').value=selected;window.runtimeEnemy=selected;
 for(const id of Object.keys(names))drafts[id]=structuredClone(saved.profiles[id]);
 function stash(){drafts[selected]={...packet(),saved_at:drafts[selected].saved_at};}
 function setDraft(){draft=structuredClone(drafts[selected].effects);legacy=drafts[selected].legacy_source||null;const kinds=({fish:['fish'],eel:['electric'],frog:['water','slam']}[selected]);for(const option of $('#kind').options){option.hidden=!kinds.includes(option.value);option.disabled=option.hidden;}if(!kinds.includes($('#kind').value))$('#kind').value=kinds[0];}
 function showSaved(){const changed=JSON.stringify(draft)!==JSON.stringify(saved.profiles[selected].effects);$('#profileState').textContent=names[selected]+' · '+(changed?'有未保存修改':saved.profiles[selected].saved_at?'已保存 '+new Date(saved.profiles[selected].saved_at).toLocaleString():'默认/迁移参数，尚未单独保存');}
 const nav=document.createElement('nav');nav.innerHTML='<button id="publish">发布已保存集合为最新版</button><button id="loadLatest">载入已发布最新版</button><span id="profileState"></span>';
 $('#message').before(nav);
 const info=document.createElement('small');info.textContent='银鳞鱼保存会先备份旧游戏值，只更新鱼冲撞受击字段；其他怪物及角色字段暂只保存浏览器草稿。旧集合发布仍是独立输出，不改变游戏。';nav.after(info);
 const gameNav=document.createElement('nav');gameNav.innerHTML='<button id="loadGameFish">载入银鳞鱼游戏值到草稿</button><label for="fishHistory">游戏历史版本</label><select id="fishHistory"><option value="">无已选版本</option></select><button id="loadFishHistory">载入所选历史到草稿</button><span id="gameFishState">正在读取游戏值…</span>';info.after(gameNav);
 async function getGame(){const r=await fetch('api/game/silverfish',{cache:'no-store'});const data=await r.json();if(!r.ok)throw Error(data.error||'读取失败');return data;}
 async function refreshHistory(){const r=await fetch('api/game/silverfish/history',{cache:'no-store'});const list=await r.json();if(!r.ok)throw Error(list.error||'读取历史失败');const box=$('#fishHistory');box.replaceChildren(new Option('请选择历史版本',''));for(const id of list)box.add(new Option(id,id));}
 function setFishGameDraft(data){stash();drafts.fish.effects.fish=structuredClone(data.fish);if(selected==='fish'){setDraft();controls();}dirty=true;showSaved();}
 $('#loadGameFish').onclick=async()=>{try{setFishGameDraft(await getGame());$('#message').textContent='已载入游戏值到银鳞鱼草稿，尚未保存；旧浏览器记录未删除。';}catch(e){$('#message').textContent='读取游戏值失败：'+e.message;}};
 $('#loadFishHistory').onclick=async()=>{try{const id=$('#fishHistory').value;if(!id)throw Error('请先选择历史版本');const r=await fetch('api/game/silverfish/history/'+encodeURIComponent(id));const data=await r.json();if(!r.ok)throw Error(data.error);setFishGameDraft(data);$('#message').textContent='历史已载入草稿，选择银鳞鱼后保存才恢复游戏；保存前仍备份当前版本。';}catch(e){$('#message').textContent='载入历史失败：'+e.message;}};
 getGame().then(data=>{spec.defaults.fish=structuredClone(data.fish);if(!hasOldSaved){drafts.fish.effects.fish=structuredClone(data.fish);saved.profiles.fish.effects.fish=structuredClone(data.fish);if(selected==='fish'&&!dirty){setDraft();controls();}}$('#gameFishState').textContent=(hasOldSaved?'已保留旧草稿；可显式载入当前游戏值':'银鳞鱼初始值来自当前游戏')+' · '+(data.published_at?'更新于 '+new Date(data.published_at).toLocaleString():'初始版本');return refreshHistory();}).catch(e=>{$('#gameFishState').textContent='游戏数据不可用：'+e.message;});
 const oldJson=json;json=function(){oldJson();$('#mode').textContent=$('#mode').textContent.replace('I版','K版');showSaved();};
 $('#save').textContent='保存当前怪物参数';$('#export').textContent='导出全部已保存参数';
 $('#enemy').onchange=()=>{stash();selected=$('#enemy').value;setDraft();controls();window.runtimeEnemy=selected;restart('candidate');};
 $('#save').onclick=async()=>{const button=$('#save');button.disabled=true;let gameSaved=false;try{stash();const next=structuredClone(saved);next.selected_enemy=selected;next.profiles[selected]={...structuredClone(drafts[selected]),saved_at:new Date().toISOString()};F.validateBundle(next,spec);if(selected==='fish'){const r=await fetch('api/game/silverfish',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({version:1,monster:'silverfish',fish:next.profiles.fish.effects.fish})});const result=await r.json();if(!r.ok)throw Error(result.error||'游戏保存失败');gameSaved=true;await refreshHistory();}localStorage.setItem(key,JSON.stringify(next));saved=next;drafts[selected]=structuredClone(next.profiles[selected]);showSaved();$('#message').textContent=selected==='fish'?'银鳞鱼受击参数已写入游戏并备份旧版；角色字段仅保存草稿。游戏需重启，已导出网页需重新导出。':'已保存 '+names[selected]+' 的浏览器草稿；尚未写入游戏。';}catch(e){$('#message').textContent=(gameSaved?'游戏值已更新并备份，但浏览器草稿保存或历史刷新失败：':'保存失败，旧游戏值和浏览器记录保留：')+e.message;}finally{button.disabled=false;}};
 function collection(){return F.validateBundle({...structuredClone(saved),selected_enemy:selected},spec);}
 $('#export').onclick=()=>{const url=URL.createObjectURL(new Blob([JSON.stringify(collection(),null,2)],{type:'application/json'})),a=document.createElement('a');a.href=url;a.download='fenshui-monsters-settings.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);$('#message').textContent='已导出已保存集合；未保存草稿未导出。';};
 async function loadBundle(input){const next=F.validateBundle(input,spec);stash();for(const id of Object.keys(names))drafts[id]=structuredClone(next.profiles[id]);setDraft();dirty=true;controls();$('#message').textContent='已导入三类怪物草稿；逐个应用检查并保存后再发布。当前对手、磁盘与已保存集合尚未改变。';}
 const oldImport=$('#file').onchange;
 $('#file').onchange=async e=>{const file=e.target.files[0];if(!file)return;let input;try{input=JSON.parse(await file.text());if(input.version===4){await loadBundle(input);e.target.value='';return;}}catch(err){$('#message').textContent='导入失败，原参数保留：'+err.message;e.target.value='';return;}await oldImport(e);$('#migration').textContent=$('#migration').textContent.replace('G数值迁入I，受击姿态和水花使用I版','旧同单位数值迁入K，受击与落地采用K版');stash();showSaved();};
 $('#publish').onclick=async()=>{const button=$('#publish');button.disabled=true;try{const response=await fetch('api/publish',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(collection())});const result=await response.json();if(!response.ok)throw Error(result.error||'发布失败');$('#message').textContent='发布成功：'+result.path+'\n更新时间：'+new Date(result.published_at).toLocaleString()+'。历史版本已保留，正式游戏未改变。';}catch(e){$('#message').textContent='发布失败：'+e.message+'；浏览器保存参数保留。';}finally{button.disabled=false;}};
 $('#loadLatest').onclick=async()=>{try{const response=await fetch('parameters/latest.json',{cache:'no-store'});const data=await response.json();if(!response.ok)throw Error(data.error);await loadBundle(data);}catch(e){$('#message').textContent='载入失败，原草稿保留：'+e.message;}};
 $('#fields').addEventListener('input',showSaved);
 window.profileEditor={collection,selected:()=>selected,drafts:()=>{stash();return structuredClone(drafts)},setFish:fish=>setFishGameDraft({fish})};
 setDraft();controls();await window.installMonsterControls();await window.installPlayerControls();window.installUnifiedEditor?.();await window.installTuningPanel?.();
};
