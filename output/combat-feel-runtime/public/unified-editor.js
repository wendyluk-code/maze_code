'use strict';
window.editorTraining={ai:true,infinite:true,bounds:false,loop:false,skill:''};
window.editorCommands=[];
window.editorTrainingStatus=null;
window.installUnifiedEditor=function(){
 const q=s=>document.querySelector(s);
 const labels={slime:'史莱姆',snail:'砖壳蜗牛',beetle:'剑甲虫',lizard:'石化蜥蜴',silverfish:'银鳞鱼',thunder_eel:'雷鳗',wind_frog:'风袋巨蛙',mimic_crab:'拟态宝箱蟹',blind_scorpion:'盲水蝎',rockmane:'岩鬃兽'};
 const skills={slime:[['melee','近战攻击'],['spit','吐弹']],silverfish:[['rush','蓄力冲撞']],thunder_eel:[['electric','蓄电放电']],wind_frog:[['water','水枪'],['slam','跳跃砸击']],rockmane:[['lunge','单次冲撞 · 160单位'],['roar','扇形咆哮'],['combo','四连冲撞']]};
 const regions={slime:'枯水渠',snail:'枯水渠',beetle:'枯水渠',lizard:'枯水渠',silverfish:'分水庭',thunder_eel:'分水庭',wind_frog:'分水庭',mimic_crab:'盐池',blind_scorpion:'盐池',rockmane:'盐池'};
 const select=q('#monsterKind'),monsterSection=select.closest('section');
 const navs=[...monsterSection.querySelectorAll('nav')];
 q('#monsterDock').append(monsterSection);
 q('#attackParameterDock').append(navs[1]);
 q('#gameSaveDock').append(navs[2],q('#saveMonsterAttack'));
 const playerSection=q('#playerHero').closest('section');
 const playerNav=q('#savePlayer').closest('nav');
 q('#playerDock').append(playerSection);
 q('#gameSaveDock').append(playerNav);
 for(const node of [q('#save'),q('#publish'),q('#loadLatest')])if(node)node.closest('nav').classList.add('legacy-controls');
 for(const id of ['loadGameFish','loadFishHistory']){const node=q('#'+id);if(node)q('#gameSaveDock').append(node.closest('nav'));}
 q('#rockDock').append(q('#rock-review-controls'));
 q('main>p').textContent='边操作边调“出招 → 命中 → 卡肉 → 受击 → 恢复”。十种怪物共用真实Godot训练场，使用各自地图；不写正式存档。';
 q('#boundary').textContent='统一入口不等于全部技能参数均已接通。右侧只开放有真实消费者的字段；未接字段明确列出。范围显示复用实际范围函数，脚底占位与身体画布大小区分，判伤仍受阶段、遮挡和存活条件限制。无限生命只在训练场将双方生命最低保留1点。旧模拟数据、旧草稿及历史保留，不当成正式游戏数据。岩鬃兽移动攻击丢锁仍未解决。';
 q('#playerDock small').textContent='三招共用卡肉，单位毫秒，适用于全部十种对手。修改后应用候选并重开。正式保存操作位于下方折叠区。';
 let serial=0,lastAck=0,lastPhase='',lastHits=-1,lastThrows=-1,lastSelected=null;
 const phases={idle:'待机',chase:'追击',windup:'攻击前摇',return:'返回',active:'待机 / 追击',dormant:'水中待机',warning:'范围预警',airborne:'腾空',landing:'落地收势',toppling:'翻落',exposed:'露腹',recovering:'恢复',charging:'蓄电',discharge:'放电',chasing:'追击',exhausted:'力竭',stranded:'搁浅',returning:'回水',forming:'成泡',rush:'释放 / 冲刺',recover:'收势',lunge_charge:'刨地蓄力',lunge:'冲撞',lunge_recover:'制动收势',charge:'咆哮前摇',rest:'气绝 · 可反击',stunned:'撞晕 · 可反击'};
 const events=[];
 const log=text=>{events.unshift(text);events.splice(8);q('#events').textContent=events.join('\n');};
 function focusGame(){const frame=q('#game');frame.contentWindow?.focus();frame.contentWindow?.document.querySelector('canvas')?.focus();}
 window.sendEditorCommand=(action,value='')=>{
  if(!window.editorTrainingStatus?.ready||window.editorTrainingStatus.generation!==window.editorGeneration){q('#trainingMessage').textContent='引擎尚未就绪，命令未发送。';return null;}
  const id=++serial;
  window.editorCommands.push({id,action,value});
  focusGame();return id;
 };
 function update(){
  if(window.editorTuningSchema?.skills)Object.assign(skills,window.editorTuningSchema.skills);
  const id=select.value;
  q('#enemySkill').replaceChildren(...(skills[id]||[['melee','近战攻击']]).map(([value,name])=>new Option(id==='rockmane'&&value==='combo'?'四侧连冲（候选专用）':name,value)));
  window.editorTraining.skill=q('#enemySkill').value;
  q('#parameterTitle').textContent=labels[id]+' · '+regions[id];
  const available=id==='silverfish'?'基础攻击值、银鳞鱼专属参数、三招共用卡肉':'基础攻击值、三招共用卡肉';
  const missing=id==='silverfish'?'身体动作与其他视觉字段':'专属技能的时序、范围及视觉参数';
  q('#capability').replaceChildren();
  for(const text of ['已接真实参数：'+available+'。','技能调试：'+(skills[id]||[['melee','近战攻击']]).map(s=>s[1]).join('、')+'。','尚未接参数：'+missing+'；不提供假滑块。']){const p=document.createElement('p');p.textContent=text;q('#capability').append(p);}
  if(!['silverfish','thunder_eel','wind_frog','rockmane'].includes(id)){const p=document.createElement('p');p.textContent='范围叠加尚未接入此怪物；不绘制推测判定或假占位。';q('#capability').append(p);}
  q('#fishParameterPanel').hidden=id!=='silverfish';
  events.length=0;lastPhase='';lastHits=-1;lastThrows=-1;lastSelected=null;
 }
 select.addEventListener('change',update);update();
 for(const [id,key] of [['ai','ai'],['dummy','infinite'],['boxes','bounds']])q('#'+id).onchange=e=>{window.editorTraining[key]=e.target.checked;focusGame();};
 q('#skillLoop').onchange=e=>{window.editorTraining.loop=e.target.checked;window.editorTraining.skill=q('#enemySkill').value;focusGame();};
 q('#enemySkill').onchange=e=>{window.editorTraining.skill=e.target.value;focusGame();};
 q('#weapon').onchange=e=>window.sendEditorCommand('weapon',Number(e.target.value));
 q('#startTraining').onclick=()=>window.sendEditorCommand('start');
 q('#attack').onclick=()=>window.sendEditorCommand('attack');
 q('#enemyAttack').onclick=()=>window.sendEditorCommand('enemy_attack',q('#enemySkill').value);
 q('#lock').onclick=()=>window.sendEditorCommand('lock');
 q('#pause').onclick=()=>window.sendEditorCommand('pause');
 q('#step').onclick=()=>window.sendEditorCommand('step');
 q('#resetScene').onclick=()=>restart('candidate');
 q('#game').addEventListener('load',()=>{window.editorTrainingStatus=null;window.editorCommands=[];lastAck=0;q('#trainingMessage').textContent='';});
 const candidate=()=>({version:1,type:'maze-unified-training',selected_monster:select.value,training:structuredClone(window.editorTraining),tuning:structuredClone(window.runtimeTuning||{}),monsters:structuredClone(window.runtimeMonsterAttack),player:structuredClone(window.runtimePlayer),fish:window.profileEditor.drafts().fish.effects.fish,runtime:arenaUrl().split('?')[0],applied_parameters:window.editorTrainingStatus?.consumer_parameters||null});
 window.trainingCandidate=candidate;
 function validateCandidate(data){
  const object=v=>v&&typeof v==='object'&&!Array.isArray(v);
  if(!object(data)||data.version!==1||data.type!=='maze-unified-training'||!Object.hasOwn(labels,data.selected_monster))throw Error('不是受支持的统一训练候选');
  if(!object(data.training)||['ai','infinite','bounds'].some(k=>typeof data.training[k]!=='boolean'))throw Error('训练开关无效');
  if(data.training.loop!==undefined&&typeof data.training.loop!=='boolean')throw Error('招式循环开关无效');
  if(data.training.skill!==undefined&&data.training.skill!==''&&!(skills[data.selected_monster]||[['melee','近战攻击']]).some(s=>s[0]===data.training.skill))throw Error('所选怪物不支持该循环技能');
  if(!object(data.monsters)||data.monsters.version!==1||!object(data.monsters.attack)||Object.keys(data.monsters.attack).sort().join()!==Object.keys(labels).sort().join()||Object.values(data.monsters.attack).some(n=>!Number.isInteger(n)||n<0||n>100))throw Error('十怪攻击值缺失或越界');
  if(!object(data.player)||data.player.version!==1||!object(data.player.effects)||Object.keys(data.player.effects).sort().join()!=='hero,tieshan,yaya'||Object.values(data.player.effects).some(r=>!object(r)||Object.keys(r).join()!=='hitstop'||!Number.isInteger(r.hitstop)||r.hitstop<0||r.hitstop>200))throw Error('角色共用参数缺失或越界');
  if(!object(data.fish)||Object.keys(data.fish).sort().join()!==Object.keys(spec.defaults.fish).sort().join())throw Error('银鳞鱼字段不完整');
  for(const [key,n] of Object.entries(data.fish)){const f=spec.fields[key];if(typeof n!=='number'||!Number.isFinite(n)||n<f.min||n>f.max)throw Error('银鳞鱼参数越界：'+key);}
  window.validateTuningCandidate?.(data.tuning||{});
  return data;
 }
 window.validateTrainingCandidate=validateCandidate;
 q('#baseline').onclick=()=>{window.monsterEditor.resetAll();window.playerEditor.resetAll();window.profileEditor.setFish(structuredClone(spec.defaults.fish));restart('baseline');};
 const oldJson=json;json=function(){oldJson();q('#mode').textContent=window.runtimeConfig.mode==='baseline'?'运行：载入时游戏基准':'运行：隔离候选'+(dirty?' · 草稿尚未应用':'');};
 q('#exportTraining').onclick=()=>{
  const data=candidate();
  const url=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='料理迷宫-统一训练候选.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  q('#trainingMessage').textContent='已导出当前候选与实际运行参数对照，未保存到正式游戏；未应用的草稿和运行值分别保留。';
 };
 q('#importTraining').onclick=()=>q('#trainingFile').click();
 window.importTrainingCandidate=data=>{
  validateCandidate(data);
  if(!window.runtimeMonsterAttack||!window.runtimePlayer)throw Error('游戏基准尚未读取完毕，请稍后重试');
  window.monsterEditor.importCandidate(data.monsters);window.playerEditor.importCandidate(data.player);window.profileEditor.setFish(data.fish);
  window.applyTuningCandidate?.(data.tuning||{});
  window.editorTraining={ai:data.training.ai,infinite:data.training.infinite,bounds:data.training.bounds,loop:data.training.loop===true,skill:data.training.skill||''};
  for(const [id,key] of [['ai','ai'],['dummy','infinite'],['boxes','bounds']])q('#'+id).checked=window.editorTraining[key];
  select.value=data.selected_monster;select.dispatchEvent(new Event('change'));
  q('#skillLoop').checked=window.editorTraining.loop;
  if(data.training.skill)q('#enemySkill').value=data.training.skill;
  window.editorTraining.skill=q('#enemySkill').value;
 };
 q('#saveTraining').onclick=()=>{try{localStorage.setItem('maze-unified-training-v1',JSON.stringify(candidate()));q('#trainingMessage').textContent='完整训练候选已保存到本机浏览器，未写正式游戏。';}catch(e){q('#trainingMessage').textContent='本机保存失败：'+e.message;}};
 q('#loadTraining').onclick=()=>{try{const raw=localStorage.getItem('maze-unified-training-v1');if(!raw)throw Error('尚无本机候选');window.importTrainingCandidate(JSON.parse(raw));}catch(e){q('#trainingMessage').textContent='载入失败，原候选保留：'+e.message;}};
 q('#trainingFile').onchange=async e=>{
  try{
   const file=e.target.files[0];if(!file)return;
   window.importTrainingCandidate(JSON.parse(await file.text()));
   q('#trainingMessage').textContent='已校验并导入候选，正在重开隔离训练场；正式参数、存档和旧浏览器草稿未写入。';
  }catch(err){q('#trainingMessage').textContent='导入失败，原候选保留：'+err.message;}finally{e.target.value='';}
 };
 setInterval(()=>{
  const s=window.editorTrainingStatus,ready=Boolean(s?.ready&&s.generation===window.editorGeneration&&s.kind===select.value);
  for(const id of ['startTraining','attack','enemyAttack','lock','pause','step','weapon','enemySkill'])q('#'+id).disabled=!ready;
  q('#step').disabled=!ready||!s.paused||s.gate;
  q('#startTraining').hidden=ready&&!s.gate;
  q('#engineState').textContent=ready?labels[s.kind]+' · '+(s.state_valid===false?'状态校验失败，请重置双方':s.gate?'等待开始':s.paused?'已暂停':'真实战斗运行中'):'正在载入真实训练场…';
  if(!ready)return;
  q('#trainingActual').textContent=JSON.stringify(s,null,2);
  if(s.loop_message)q('#trainingMessage').textContent=s.loop_message;
  phases.combo_reposition='绕位 · 准备下一侧冲撞';
  if(s.ack!==lastAck){lastAck=s.ack;q('#trainingMessage').textContent=s.error||((s.command==='step'?'已推进16毫秒':s.command==='enemy_attack'?(s.paused?'技能已设置；当前已暂停，继续后播放':s.actor?.rock_combo?'已启动四侧连冲：先绕位，再依次从四侧冲入':'已启动所选技能；可能因距离、遮挡或玩家躲避而打空'):'操作已由真实训练场接收'));}
  if(s.combo_note)q('#trainingMessage').textContent=s.combo_note;
  if(lastSelected!==s.selected){q('#weapon').value=String(s.selected);lastSelected=s.selected;}
  if(s.phase!==lastPhase){log('阶段：'+(phases[s.phase]||'其他状态')+' · 战斗时间 '+s.elapsed.toFixed(2)+'秒');lastPhase=s.phase;}
  if(lastHits>=0&&s.hits!==lastHits)log('命中 '+s.hits+' 次 · 怪物生命 '+s.monster_hp.toFixed(0));
  if(lastThrows>=0&&s.throws!==lastThrows)log('已出招 '+s.throws+' 次');
  lastHits=s.hits;lastThrows=s.throws;
 },100);
};
