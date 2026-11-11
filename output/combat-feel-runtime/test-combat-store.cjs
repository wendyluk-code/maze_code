const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createCombatStore}=require('./combat-store.cjs');
const schema=require('../../data/maze/combat_tuning_schema.json');
function fixture(){const root=fs.mkdtempSync(path.join(os.tmpdir(),'maze-combat-'));return {root,store:createCombatStore({file:path.join(root,'combat.json'),history:path.join(root,'history'),schema})};}
test('未保存时不创建正式覆盖；保存水枪后新读取器读回，保留其他怪物',()=>{
 const {root,store}=fixture();assert.deepEqual(store.read().values,{});assert(!fs.existsSync(path.join(root,'combat.json')));
 store.save({scope:'all',values:{'base.slime':{hp:30}}});
 store.save({scope:'wind_frog',values:{'effect.water':{speed:250,damage:12},'base.slime':{hp:99}}});
 const next=createCombatStore({file:path.join(root,'combat.json'),history:path.join(root,'history'),schema});
 assert.equal(next.read().values['effect.water'].speed,250);assert.equal(next.read().values['base.slime'].hp,30);assert.equal(next.list().length,2);
 assert.equal(next.history(next.list()[0]).version,1);
});
test('未知字段、越界、候选独有、训练开关和小数伤害被拒绝且原值不变',()=>{
 const {store}=fixture();store.save({scope:'all',values:{'effect.water':{speed:250}}});const before=store.read();
 for(const values of [{'effect.water':{speed:9999}},{'effect.water':{damage:1.5}},{'rock.combo':{charge1:1}},{'training':{infinite:1}},{'effect.water':{unknown:1}}])assert.throws(()=>store.save({scope:'all',values}));
 assert.deepEqual(store.read(),before);
});
test('备份失败不改变现值；历史恢复必须再次保存',()=>{
 const {root,store}=fixture();store.save({scope:'all',values:{'effect.water':{speed:210}}});const old=store.list()[0];
 const staged=store.history(old);assert.equal(store.read().values['effect.water'].speed,210);assert.deepEqual(staged.values,{});
 const bad=path.join(root,'blocked');fs.writeFileSync(bad,'file');const broken=createCombatStore({file:path.join(root,'combat.json'),history:bad,schema});
 assert.throws(()=>broken.save({scope:'all',values:{'effect.water':{speed:220}}}));assert.equal(store.read().values['effect.water'].speed,210);
});
test('芽芽连发四项正式保存、非法颗数拒绝且保留其他参数',()=>{
 const {root,store}=fixture();
 store.save({scope:'all',values:{'base.slime':{hp:30},'effect.hero':{speed:420},'effect.yaya':{speed:310}}});
 const values={'effect.hero':{speed:420},'effect.yaya':{speed:310,burst_count:3,burst_interval:0.1,burst_damage_scale:25,burst_cooldown:0.45}};
 store.save({scope:'player',values});
 const reread=createCombatStore({file:path.join(root,'combat.json'),history:path.join(root,'history'),schema});
 assert.deepEqual(reread.read().values['effect.yaya'],values['effect.yaya']);
 assert.equal(reread.read().values['base.slime'].hp,30);
 const before=reread.read();
 for(const burst_count of [0,2.5,13])assert.throws(()=>reread.save({scope:'player',values:{'effect.yaya':{burst_count}}}));
 assert.deepEqual(reread.read(),before);
});
