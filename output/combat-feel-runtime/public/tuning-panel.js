'use strict';
window.runtimeTuning={};
window.installTuningPanel=async function(){
 const q=s=>document.querySelector(s);
 try{
  const response=await fetch('editor-tuning.json',{cache:'no-store'});if(!response.ok)throw Error('参数清单读取失败');
  const schema=await response.json();
  const playerResponse=await fetch('player-skill-candidate.json',{cache:'no-store'});if(!playerResponse.ok)throw Error('角色技能清单读取失败');
  const playerCandidate=await playerResponse.json();
  for(const [group,fields]of Object.entries(playerCandidate.groups))schema.groups[group].fields={...fields,...schema.groups[group].fields};
  for(const [id,name]of Object.entries({hero:'锅铲',yaya:'芽芽',tieshan:'铁山'}))schema.groups['effect.'+id].label=name+' · 技能与命中';
  window.editorTuningSchema=schema;
  const host=document.createElement('section');host.id='tuningPanel';
  host.innerHTML='<h2>战斗参数清单</h2><label>参数显示 <select id="parameterScope" aria-label="参数显示范围"><option value="current">当前怪物与角色</option><option value="player">角色技能（锅铲／芽芽／铁山）</option><option value="all">全部怪物与角色</option></select></label><small id="tuningCount"></small><p id="tuningMessage" role="status">修改先进入草稿；应用预览与保存正式游戏分别执行。</p><div id="tuningGroups"></div>';
  q('#capability').after(host);document.body.classList.add('tuning-ready');
  const categories={monster:'怪物基础',skill:'专属技能',player:'角色攻击与命中',hurt:'角色受击'};
  function syncShared(){
   if(window.runtimeMonsterAttack){const data=structuredClone(window.runtimeMonsterAttack);for(const kind of Object.keys(data.attack))if(window.runtimeTuning['base.'+kind]?.attack!==undefined)data.attack[kind]=window.runtimeTuning['base.'+kind].attack;window.monsterEditor.importCandidate(data);}
   if(window.runtimePlayer){const data=structuredClone(window.runtimePlayer);for(const id of ['hero','yaya','tieshan'])if(window.runtimeTuning['effect.'+id]?.hitstop!==undefined)data.effects[id].hitstop=window.runtimeTuning['effect.'+id].hitstop;window.playerEditor.importCandidate(data);}
   if(window.runtimeTuning['effect.fish']){const fish=window.profileEditor.drafts().fish.effects.fish;for(const key of Object.keys(spec.defaults.fish))if(window.runtimeTuning['effect.fish'][key]!==undefined)fish[key]=window.runtimeTuning['effect.fish'][key];window.profileEditor.setFish(fish);}
  }
  function value(group,key,rule){
   if(window.runtimeTuning[group]&&Object.hasOwn(window.runtimeTuning[group],key))return window.runtimeTuning[group][key];
   if(group==='effect.fish')return window.profileEditor.drafts().fish.effects.fish[key];
   if(key==='attack'&&group.startsWith('base.'))return window.runtimeMonsterAttack?.attack[group.slice(5)]??rule.default;
   if(key==='hitstop'&&group.startsWith('effect.'))return window.runtimePlayer?.effects[group.slice(7)]?.hitstop??rule.default;
   return rule.default;
  }
  function render(){
   const box=q('#tuningGroups');box.replaceChildren();const selected=q('#monsterKind').value,all=q('#parameterScope').value==='all',playerOnly=q('#parameterScope').value==='player',weapon=['hero','yaya','tieshan'][Number(q('#weapon').value)];let count=0;
   for(const [category,title] of Object.entries(categories)){
    const rows=Object.entries(schema.groups).filter(([,g])=>g.category===category&&(playerOnly?g.category==='player':(all||g.owner===selected||g.owner==='player')));
    if(!rows.length)continue;const heading=document.createElement('h3');heading.textContent=title;box.append(heading);
    for(const [group,g] of rows){
     const details=document.createElement('details');details.dataset.group=group;details.open=playerOnly?group==='effect.'+weapon:category==='monster'&&!all;
     const summary=document.createElement('summary');summary.textContent=g.label+' · '+Object.keys(g.fields).length+'项';details.append(summary);
     for(const [key,rule] of Object.entries(g.fields)){
      count++;const label=document.createElement('label');label.className='field';
      const text=document.createElement('span');text.textContent=rule.label.replace('原G的','')+' · '+rule.unit;label.append(text);
      for(const type of ['number','range']){
       const input=document.createElement('input');Object.assign(input,{type,min:rule.min,max:rule.max,step:(['点','颗'].includes(rule.unit)||key==='hitstop')?1:'any',value:value(group,key,rule),disabled:!rule.connected});input.dataset.group=group;input.dataset.key=key;input.setAttribute('aria-label',g.label+' '+key+' '+(type==='number'?'数值':'滑块'));
       input.oninput=()=>{
        const n=input.valueAsNumber;if(!Number.isFinite(n)||n<rule.min||n>rule.max||((['点','颗'].includes(rule.unit)||key==='hitstop')&&!Number.isInteger(n))){input.setCustomValidity('数值越界或格式无效');q('#tuningMessage').textContent='请输入有效范围 '+rule.min+' 至 '+rule.max+'；原候选值尚未改变。';return;}
        input.setCustomValidity('');(window.runtimeTuning[group]??={})[key]=n;
        dirty=true;json();
        syncShared();
        for(const other of label.querySelectorAll('input')){if(other!==input)other.value=n;other.setCustomValidity('');}
        q('#tuningMessage').textContent='有未应用的参数修改；点击“应用候选并重开”后进入真实消费者。';
       };label.append(input);
      }
      const hint=document.createElement('small');hint.className='original';hint.textContent=rule.connected?'代码基准 '+(rule.game_default??rule.default)+' '+rule.unit+(rule.persist?' · 可保存正式游戏':' · 候选可调；本机保存／导出，尚未接正式游戏'):'未开放：'+rule.reason;if(key==='burst_interval')hint.textContent+=' · 以0.05秒战斗步释放';if(group==='effect.yaya'&&key==='interval_scale')hint.textContent+=' · 不短于整轮连发耗时与最短间隔';label.append(hint);details.append(label);
     }
     box.append(details);
    }
   }
   const fields=Object.values(schema.groups).flatMap(g=>Object.values(g.fields)),total=fields.length,available=fields.filter(f=>f.connected).length;q('#tuningCount').textContent='显示 '+count+' / 全部 '+total+' 项（'+available+'可调，'+(total-available)+'未开放）。';
   q('#capability').textContent='当前候选开放基础属性、角色攻击/受击及专属技能数值。参数按对象分类；素材与内部算法常量不作为数值滑块。';
  }
  window.validateTuningCandidate=function(data){
   if(!data||typeof data!=='object'||Array.isArray(data))throw Error('完整参数候选必须是对象');
   for(const [group,values] of Object.entries(data)){
    if(!schema.groups[group]||!values||typeof values!=='object'||Array.isArray(values))throw Error('未知参数组 '+group);
    for(const [key,n] of Object.entries(values)){const f=schema.groups[group].fields[key];if(!f||!f.connected||typeof n!=='number'||!Number.isFinite(n)||n<f.min||n>f.max||((['点','颗'].includes(f.unit)||key==='hitstop')&&!Number.isInteger(n)))throw Error('参数无效、未开放或越界 '+group+'.'+key);}
   }
   return data;
  };
  window.applyTuningCandidate=data=>{window.runtimeTuning=structuredClone(window.validateTuningCandidate(data));syncShared();render();};
  q('#parameterScope').onchange=render;q('#monsterKind').addEventListener('change',render);
  q('#weapon').addEventListener('change',()=>{q('#parameterScope').value='player';render();});
  const apply=q('#apply').onclick;q('#apply').onclick=()=>{const invalid=host.querySelector('input:invalid');if(invalid){invalid.closest('details').open=true;q('#tuningMessage').textContent='存在无效数值，未重开也未覆盖当前运行。';invalid.reportValidity();return;}window.validateTuningCandidate(window.runtimeTuning);apply();q('#tuningMessage').textContent='已用当前草稿重开训练场；尚未执行正式保存。';};
  const baseline=q('#baseline').onclick;q('#baseline').onclick=()=>{window.runtimeTuning={};baseline();render();};
  render();
  q('#boundary').textContent='参数按怪物和技能归类，角色共用字段单列；可保存字段有正式消费者。岩鬃兽四侧连冲已接入本候选：沿可达路径绕位后从四侧冲入；无路时结束，不穿人穿障碍。四连仍不能正式保存。脚底体积阻挡不等于斜视角画面轮廓绝不重叠，岩鬃兽不再遮挡淡化。弹速、射程、实际命中半径与接触特效尺寸是不同参数；水枪原轨迹与遮挡规则保留。史莱姆循环停滞、移动攻击丢锁等历史问题仍未解决。';
  await window.installCombatPersistence(schema);
 }catch(e){const p=document.createElement('p');p.textContent='完整参数面板未就绪：'+e.message;q('#capability').after(p);}
};
