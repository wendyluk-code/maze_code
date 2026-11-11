extends "res://tools/tests/fenshui_heal_state.gd"
const FISH_ID="fenshui_silverfish_1"
const HURT_POINT=Vector2(1090,450)
const Growth=preload("res://scripts/characters/character_progression.gd")
var original: Dictionary

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"玩家受击真实事务使用隔离存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",HURT_POINT).success,"真实进入分水庭受击检查点")
 if failures:
  _finish()
  return
 original=sm.data.duplicate(true)
 seed_fish()
 _check(Run.valid(state()),"鱼锁向冲刺检查点合法")
 var before: float=state().combat.hp
 var result:=Run.combat_tick(sm,HURT_POINT,0.1)
 _check(result.success and state().combat.hp<before,"原鱼冲撞真实扣血，沿现有防御结算",{"result":result,"before":before,"after":state().combat.hp,"actor":state().combat.actors[FISH_ID]})
 var events: Array=result.get("player_hurt_feedback",[])
 _check(events.size()==1 and events[0].kind=="fish","成功鱼冲撞返回对应玩家受击显示事件",{"events":events})
 if failures==0:
  for kind in ["electric","water","slam"]: check_attack(kind)
  for kind in ["fish","electric","water","slam"]: error_and_recovery(kind)
  recovery_contract()
 _finish()

func recovery_contract() -> void:
 sm.data=original.duplicate(true)
 seed_fish()
 var run: Dictionary=sm.data[Run.KEY]
 run.combat.cooldown=0.0
 _check(Run.Combat.Skills.select(run,2) and Run.Combat.Skills.attack(run,HURT_POINT,Vector2.LEFT),"受击前真实开始尚未出手的旋斧")
 var hits: int=run.combat.hits
 var result:=Run.combat_tick(sm,HURT_POINT,0.1)
 var c: Dictionary=sm.data[Run.KEY].combat
 _check(result.success and is_equal_approx(float(c.get("hurt_recovery_left",0.0)),0.6),"实际鱼撞进入600毫秒恢复")
 _check(c.action=="" and c.action_left==0.0 and not c.axe_pending,"真实受击取消未出斧阶段")
 _check(not Run.Combat.Skills.attack(sm.data[Run.KEY],HURT_POINT,Vector2.LEFT),"恢复状态实际拒绝新攻击")
 _check(Run.combat_tick(sm,HURT_POINT,0.15).success and state().combat.hits==hits and not state().combat.axe_pending,"恢复推进不补发被取消旋斧")
 _check(is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.45),"恢复倒计时与原击退分别推进")
 _check(sm.save(),"按原保存入口持久化当前恢复检查点")
 sm.load_data()
 _check(Run.valid(state()) and is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.45),"保存读档保留剩余恢复而非重启整段")
 _check(Run.combat_tick(sm,HURT_POINT,0.30).success and not Run.Combat.Skills.attack(sm.data[Run.KEY],HURT_POINT,Vector2.LEFT),"受击450毫秒后仍拒绝新攻击，不在旧400毫秒提前恢复")
 _check(is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.15),"受击450毫秒后保留150毫秒恢复")
 sm.data[Run.KEY].monsters[Boss.ID].status="alive"
 seed_attack("water")
 result=Run.combat_tick(sm,HURT_POINT,0.1)
 _check(result.success and result.get("player_hurt_feedback",[]).size()==1 and is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.6),"连续有效受击刷新600毫秒，不累加或增加无敌")
 for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status="captured"
 _check(Run.combat_tick(sm,HURT_POINT,0.12).success and Run.Combat.vec(state().combat.hero).distance_to(HURT_POINT)>0.0,"水枪受击恢复不吞掉原0.12秒击退位移")
 _check(Run.combat_tick(sm,HURT_POINT,0.48).success and state().combat.get("hurt_recovery_left",0.0)==0.0,"无后续命中时600毫秒恢复倒计时归零")
 sm.data[Run.KEY].combat.cooldown=0.0
 _check(Run.Combat.Skills.attack(sm.data[Run.KEY],HURT_POINT,Vector2.DOWN),"恢复结束实际允许新的出招")
 sm.data=original.duplicate(true)
 seed_fish()
 run=sm.data[Run.KEY]
 run.combat.cooldown=0.0
 _check(Run.Combat.Skills.attack(run,HURT_POINT,Vector2.DOWN),"真实发射独立锅铲弹体")
 result=Run.combat_tick(sm,HURT_POINT,0.1)
 c=sm.data[Run.KEY].combat
 _check(result.success and c.shots.size()==1 and c.shots[0].time>0.0 and c.action_left==0.0,"受击只取消人物出招，已发弹体继续飞行")
 var valid: Dictionary=state().duplicate(true)
 valid.combat.erase("hurt_recovery_left")
 _check(Run.valid(valid),"缺少恢复字段的旧档仍合法")
 for remaining in [0.0,0.4,0.45,0.6,0.75,0.9,1.5]:
  var restored: Dictionary=state().duplicate(true)
  restored.combat.hurt_recovery_left=remaining
  _check(Run.valid(restored),"新旧恢复范围读档合法："+str(remaining))
 for invalid in [-0.01,1.501,"0.2",INF]:
  var broken: Dictionary=state().duplicate(true)
  broken.combat.hurt_recovery_left=invalid
  _check(not Run.valid(broken),"非法恢复字段拒绝："+str(invalid))
 for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status="captured"
 sm.data[Run.KEY].combat.shots.clear()
 _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success and state().combat.get("hurt_recovery_left",0.0)==0.0,"合法离图清除受击恢复")
 for scope in ["maze_entry","salt_pool","trial"]:
  var outside: Dictionary={"region":"fenshui" if scope=="trial" else scope,"fs01_trial":scope=="trial","hp":10.0,"action":"tieshan","action_left":0.4,"axe_pending":true}
  var events: Array=[]
  Run.Combat.PlayerHurt.record(outside,12.0,"fish",Vector2.ZERO,Vector2.LEFT,events)
  if scope=="trial":
   _check(events.is_empty() and not outside.has("hurt_recovery_left") and outside.axe_pending,"旧特殊试玩不新增恢复门禁")
  else:
   _check(events.size()==1 and is_equal_approx(outside.hurt_recovery_left,0.6) and not outside.axe_pending,"正常地图共用受击恢复："+scope)

func check_attack(kind: String) -> void:
 sm.data=original.duplicate(true)
 seed_attack(kind)
 _check(Run.valid(state()),"真实受击事务检查点合法："+kind)
 var hp: float=state().combat.hp
 var result:=Run.combat_tick(sm,HURT_POINT,0.1)
 var events: Array=result.get("player_hurt_feedback",[])
 _check(result.success and state().combat.hp<hp,"原真实伤害入口仍扣血："+kind,{"result":result,"before":hp,"after":state().combat.hp})
 _check(events.size()==1 and events[0].kind==kind,"成功事务返回对应受击种类："+kind,{"events":events})
 if kind=="slam":
  _check(is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.9),"巨蛙落地砸击实际扣血进入900毫秒恢复")
  _check(sm.save(),"900毫秒落地受击通过原入口保存")
  sm.load_data()
  _check(Run.valid(state()) and is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.9),"900毫秒落地恢复可读档且不被旧600上限拒绝")
  _check(Run.combat_tick(sm,HURT_POINT,0.45).success and Run.combat_tick(sm,HURT_POINT,0.35).success,"真实落地受击推进800毫秒")
  _check(is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.1) and not Run.Combat.Skills.attack(sm.data[Run.KEY],HURT_POINT,Vector2.LEFT),"落地受击800毫秒后仍禁攻")
  _check(Run.combat_tick(sm,HURT_POINT,0.1).success and is_zero_approx(float(state().combat.get("hurt_recovery_left",0.0))) and Run.Combat.Skills.attack(sm.data[Run.KEY],HURT_POINT,Vector2.LEFT),"落地受击900毫秒结束后实际允许新攻击")
 else:
  _check(is_equal_approx(float(state().combat.get("hurt_recovery_left",0.0)),0.6),"其他招式保留600毫秒："+kind)

func error_and_recovery(kind: String) -> void:
 sm.data=original.duplicate(true)
 seed_attack(kind)
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 var failed:=Run.combat_tick(sm,HURT_POINT,0.1)
 _check(not failed.success and sm.data==before and failed.get("player_hurt_feedback",[]).is_empty(),"失败保存回滚伤害且不泄漏显示事件："+kind)
 sm._active_save_path=path
 var result:=Run.combat_tick(sm,HURT_POINT,0.1)
 _check(result.success and result.get("player_hurt_feedback",[]).size()==1,"恢复保存后真实命中只发布一次："+kind)
 _check(not state().combat.has("player_hurt_feedback"),"玩家受击事件不进入存档状态："+kind)
 sm.load_data()
 _check(Run.valid(state()) and Run.combat_tick(sm,HURT_POINT,0.01).get("player_hurt_feedback",[]).is_empty(),"读档续阶段不重放刚才受击："+kind)
 sm.data=original.duplicate(true)
 seed_attack(kind)
 # 使用合法满级队友防御，不伪造超出便当上限的属性。
 var records: Dictionary=sm.data.get(Growth.KEY,{}).duplicate(true)
 for member in state().members:
  if not Growth.CHARACTERS.has(member.id): continue
  records[member.id]={"level":30,"exp":0,"rank":1,"breakthroughs":5}
 sm.data[Growth.KEY]=records
 Run.Combat.Skills.sync_levels(sm.data[Run.KEY],sm)
 _check(Run.valid(state()) and Run.Combat.Skills.defense(state())>=6,"零伤前提为有效成长记录及原防御结算："+kind)
 var hp: float=state().combat.hp
 var zero:=Run.combat_tick(sm,HURT_POINT,0.1)
 _check(zero.success and state().combat.hp==hp and zero.get("player_hurt_feedback",[]).is_empty(),"现有防御使伤害为零时不误播："+kind)
 _check(state().combat.get("hurt_recovery_left",0.0)==0.0,"零伤不新增恢复门禁："+kind)
 sm.data=original.duplicate(true)
 seed_attack(kind)
 hp=state().combat.hp
 var missed:=Run.combat_tick(sm,SAFE,0.1)
 _check(missed.success and state().combat.hp==hp and missed.get("player_hurt_feedback",[]).is_empty(),"原攻击未命中不播放玩家受击："+kind)
 _check(state().combat.get("hurt_recovery_left",0.0)==0.0,"打空不新增恢复门禁："+kind)

func seed_attack(kind: String, isolate: bool=true) -> void:
 if kind=="fish":
  seed_fish(isolate)
  return
 var id: String="fenshui_thunder_eel_2" if kind=="electric" else Boss.ID
 var c: Dictionary=sm.data[Run.KEY].combat
 for other in c.actors:
  if isolate and other!=id: sm.data[Run.KEY].monsters[other].status="captured"
 var a: Dictionary=c.actors[id]
 a.position=[1040.0,450.0]
 if kind=="electric":
  a.eel_origin=a.position.duplicate()
  a.eel_path=[]
  Run.Combat.ThunderEel.phase(a,"charging",0.05)
 else:
  a.frog_origin=a.position.duplicate()
  a.frog_target=a.position.duplicate()
  a.frog_phase="active"
  a.frog_left=1.0
  a.mode="chase"
  a.cooldown=10.0
  if kind=="water":
   a.frog_shots=[{"position":[1068.0,450.0],"direction":[1.0,0.0],"distance":28.0}]
  else:
   a.frog_phase="airborne"
   a.frog_origin=[900.0,450.0]
   a.frog_target=[1040.0,450.0]
   a.frog_air_duration=0.8
   a.frog_left=0.05
   a.position=[1031.25,450.0]

func seed_fish(isolate: bool=true) -> void:
 var c: Dictionary=sm.data[Run.KEY].combat
 for id in c.actors:
  if isolate and id!=FISH_ID: sm.data[Run.KEY].monsters[id].status="captured"
 var a: Dictionary=c.actors[FISH_ID]
 a.position=[1060.0,450.0]
 a.fish_origin=a.position.duplicate()
 a.fish_aim=[1.0,0.0]
 a.fish_hit=false
 Run.Combat.Silverfish.phase(a,"rush",0.5)
