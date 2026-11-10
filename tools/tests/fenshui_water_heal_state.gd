extends "res://tools/tests/fenshui_heal_state.gd"
const WATER_HERO=Vector2(1090,450)
var seeded: Dictionary

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"战斗中水回血使用隔离存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",WATER_HERO).success,"真实进入可交战水域")
 if failures:
  _finish()
  return
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.hp=48.0
 a.position=[1040.0,450.0]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.frog_phase="active"
 a.frog_left=1.2
 a.mode="chase"
 a.cooldown=10.0
 a.frog_heal_quiet=0.0
 _check(Run.valid(state()) and Boss.water(WATER_HERO),"原追击冷却检查点与玩家水中站位合法")
 seeded=sm.data.duplicate(true)
 for i in 19:
  _check(Run.combat_tick(sm,WATER_HERO,0.1).success,"交战中正常推进水中计时")
 _check(actor().hp==48.0 and is_equal_approx(float(actor().frog_heal_quiet),1.9),"交战中水里1.9秒仅累计计时，不提前回血")
 Run.combat_tick(sm,WATER_HERO,0.1)
 _check(is_equal_approx(float(actor().hp),48.0) and is_equal_approx(float(actor().frog_heal_quiet),2.0),"交战中达到2秒门槛，不补之前的治疗")
 Run.combat_tick(sm,WATER_HERO,0.1)
 _check(is_equal_approx(float(actor().hp),49.6) and actor().mode=="chase","真实交战中2秒未受击后按每秒16恢复，不要求脱战",{"actor":actor()})
 if failures==0:
  water_stages()
  phase_guards()
  attack_reset()
  miss_keeps_clock()
  zero_damage_keeps_clock()
  lightning_resets_clock()
 _finish()

func water_stages() -> void:
 for phase in ["dormant","active","warning","landing"]:
  sm.data=seeded.duplicate(true)
  var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
  a.frog_phase=phase
  a.frog_left=0.9
  a.frog_heal_quiet=2.0
  if phase=="warning": a.frog_target=[1090.0,450.0]
  if phase=="landing": a.frog_origin=[900.0,450.0]
  _check(Run.valid(state()),"普通水中阶段恢复样例合法："+phase)
  _check(Run.combat_tick(sm,WATER_HERO,0.1).success and is_equal_approx(float(actor().hp),49.6),"普通水中阶段可在交战时恢复："+phase)

func attack_reset() -> void:
 sm.data=seeded.duplicate(true)
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.frog_heal_quiet=2.0
 sm.data[Run.KEY].combat.cooldown=0.0
 _check(Run.combat_command(sm,"select",0).success and Run.combat_attack(sm,WATER_HERO,WATER_HERO.direction_to(Vector2(1040,450))).success,"交战中从原出手事务攻击回血巨蛙")
 var hit:=false
 for i in 50:
  var result:=Run.combat_tick(sm,WATER_HERO,0.01)
  for event in result.get("hit_feedback",[]):
   if event.id==Boss.ID: hit=true
  if hit: break
 _check(hit and actor().frog_heal_quiet==0.0,"实际有效命中当次事务清零水中回血计时")
 if not hit: return
 var hp: float=actor().hp
 for i in 3: Run.combat_tick(sm,WATER_HERO,0.5)
 Run.combat_tick(sm,WATER_HERO,0.4)
 _check(is_equal_approx(float(actor().hp),hp) and is_equal_approx(float(actor().frog_heal_quiet),1.9),"受击后水中1.9秒尚不回血，包括原受击位移时间")
 Run.combat_tick(sm,WATER_HERO,0.1)
 _check(is_equal_approx(float(actor().hp),hp),"受击后完整等满2秒，不提前追补")
 Run.combat_tick(sm,WATER_HERO,0.1)
 _check(is_equal_approx(float(actor().hp),hp+1.6),"受击后仍在交战，满2秒后重新按原速率恢复")

func miss_keeps_clock() -> void:
 sm.data=seeded.duplicate(true)
 sm.data[Run.KEY].combat.actors[Boss.ID].frog_heal_quiet=1.5
 sm.data[Run.KEY].combat.cooldown=0.0
 _check(Run.combat_command(sm,"select",0).success and Run.combat_attack(sm,WATER_HERO,Vector2.RIGHT).success,"通过原出手事务向巨蛙反方向打空")
 for i in 6: Run.combat_tick(sm,WATER_HERO,0.1)
 _check(is_equal_approx(float(actor().hp),49.6) and actor().frog_heal_quiet==2.0,"玩家打空不清零巨蛙计时，不要求脱战才能续回")

func zero_damage_keeps_clock() -> void:
 sm.data=seeded.duplicate(true)
 sm.data[Run.KEY].combat.actors[Boss.ID].frog_heal_quiet=1.5
 sm.data[Run.KEY].combat.cooldown=0.0
 _check(Run.combat_command(sm,"select",0).success and Run.combat_attack(sm,WATER_HERO,Vector2.LEFT).success,"原出手入口建立零伤边界弹体")
 sm.data[Run.KEY].combat.shots[0].damage=0
 for i in 6: Run.combat_tick(sm,WATER_HERO,0.1)
 _check(state().combat.hits>0 and is_equal_approx(float(actor().hp),49.6) and actor().frog_heal_quiet==2.0,"零伤命中不清零计时，原实际伤害条件保持")

func lightning_resets_clock() -> void:
 sm.data=seeded.duplicate(true)
 sm.data[Run.KEY].combat.actors[Boss.ID].frog_heal_quiet=2.0
 var eel: Dictionary=sm.data[Run.KEY].combat.actors["fenshui_thunder_eel_1"]
 eel.position=[1080.0,450.0]
 eel.eel_origin=eel.position.duplicate()
 eel.eel_path=[]
 eel.eel_phase="charging"
 eel.eel_left=0.05
 eel.mode="windup"
 eel.windup=0.05
 _check(Run.valid(state()),"同场雷鳗真实释放检查点合法")
 var serial: int=state().combat.get("electric_serial",0)
 _check(Run.combat_tick(sm,WATER_HERO,0.1).success and state().combat.get("electric_serial",0)>serial and actor().hp<48.0 and actor().frog_heal_quiet==0.0,"原范围电实际伤害同样重置巨蛙水中回血计时")
