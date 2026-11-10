extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const SAFE=Vector2(920,782)

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"静水恢复使用隔离存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"真实建立探索")
 _check(Run.change_region(sm,"fenshui",SAFE).success,"真实进入分水庭安全岸路")
 if failures:
  _finish()
  return
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 # 合法非中央落点；不修改地形或落点算法。
 var landing:=Vector2(1040,450)
 _check(Boss.allowed(landing),"非中央回血样例为完整合法水面")
 a.hp=48.0
 a.position=[landing.x,landing.y]
 a.frog_origin=[Boss.HOME.x,Boss.HOME.y]
 a.frog_target=a.position.duplicate()
 a.frog_phase="landing"
 a.frog_left=0.1
 a.mode="return"
 _check(Run.valid(state()),"受伤非中央落水检查点有效")
 _check(Run.combat_tick(sm,SAFE,0.1).success,"通过公开事务完成落地")
 _check(actor().frog_phase=="dormant" and actor().mode=="idle","非中央合法水面落稳即待机，不必继续回中央")
 _check(Run.Combat.vec(actor().position).distance_to(landing)<0.01,"回血不传送也不移动合法落点")
 _check(is_equal_approx(float(actor().hp),48.0),"非中央落地不瞬间满血")
 if failures==0:
  for i in 19: _check(Run.combat_tick(sm,SAFE,0.1).success,"水中未受击计时正常推进")
  _check(is_equal_approx(float(actor().hp),48.0),"水中累计2秒前不回血")
  for i in 10: Run.combat_tick(sm,SAFE,0.1)
  _check(is_equal_approx(float(actor().hp),64.0),"静水恢复每秒增加16生命")
  recovery_checks()
  phase_guards()
  shore_hit_interrupt()
 _finish()

func phase_guards() -> void:
 var saved: Dictionary=sm.data.duplicate(true)
 for phase in ["airborne","toppling","exposed","recovering","emerging"]:
  sm.data=saved.duplicate(true)
  var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
  a.hp=48.0
  a.frog_heal_quiet=2.0
  a.frog_phase=phase
  a.frog_left=0.5
  a.frog_origin=[900.0,450.0]
  a.frog_target=[1040.0,450.0]
  a.position=a.frog_target.duplicate()
  a.mode="return"
  if phase=="warning": a.position=a.frog_origin.duplicate()
  if phase=="airborne":
   a.frog_air_duration=0.8
   a.position=[952.5,450.0]
  if phase=="toppling":
   a.position=a.frog_origin.duplicate()
   a.frog_counter_from=a.position.duplicate()
   a.frog_left=0.56
  _check(Run.valid(state()),"禁止回血的真实阶段检查点合法："+phase)
  _check(Run.combat_tick(sm,SAFE,0.1).success and is_equal_approx(float(actor().hp),48.0),"放宽地点不允许非待机阶段回血："+phase)
 sm.data=saved.duplicate(true)
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.position=[1040.0,450.0]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.hp=48.0
 a.frog_heal_quiet=2.0
 a.frog_phase="dormant"
 a.mode="idle"
 a.frog_left=0.0
 _check(Run.combat_tick(sm,Vector2(880,490),0.1).success and is_equal_approx(float(actor().hp),49.6) and actor().frog_heal_quiet==2.0,"非中央重新交战本身不再中断水中回血")
 sm.data=saved

func shore_hit_interrupt() -> void:
 var saved: Dictionary=sm.data.duplicate(true)
 # 沿用真实越岸返回样例的合法水中起点，中央东侧水面附近未必有射程内干岸。
 var target:=Vector2(416,240)
 var shore:=Vector2.ZERO
 var fish=preload("res://scripts/maze/silverfish_combat.gd")
 for distance in range(48,181,8):
  for direction in 32:
   var point:=target+Vector2.RIGHT.rotated(direction*TAU/32.0)*distance
   if fish.dry(point) and Boss.Roads.is_walkable(point) and not Boss.water(point) and Run.Combat.Skills.clear_line(point,target,"fenshui"):
    shore=point
    break
  if not shore.is_zero_approx(): break
 _check(not shore.is_zero_approx(),"非中央恢复点附近存在原射程内的真实干岸",{"shore":str(shore)})
 if shore.is_zero_approx(): return
 var c: Dictionary=sm.data[Run.KEY].combat
 var a: Dictionary=c.actors[Boss.ID]
 _check(Run.Catalog.targetable(c,Boss.ID),"已解锁的可见满血待机巨蛙仍可选中")
 var locked_story:=c.duplicate(true)
 locked_story.frog_unlocked=false
 _check(not Run.Catalog.targetable(locked_story,Boss.ID),"剧情未解锁的满血待机巨蛙保持原保护")
 a.position=[target.x,target.y]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.hp=48.0
 a.frog_phase="dormant"
 a.mode="idle"
 a.frog_heal_quiet=2.0
 a.hit_remaining=0.0
 var trial:=c.duplicate(true)
 trial.fs01_trial=true
 _check(not Run.Catalog.targetable(trial,Boss.ID),"旧特殊试玩不启用回血待机命中例外")
 var emerging:=c.duplicate(true)
 emerging.actors[Boss.ID].frog_phase="emerging"
 _check(not Run.Catalog.targetable(emerging,Boss.ID),"旧出水阶段保持原不可选条件")
 _check(Run.Catalog.targetable(c,"fenshui_silverfish_1"),"普通鱼的目标条件保持不变")
 c.hero=[shore.x,shore.y]
 c.cooldown=0.0
 c.action_left=0.0
 _check(Run.valid(state()),"干岸真实攻击使用合法回血检查点")
 _check(Run.combat_command(sm,"select",0).success and Run.combat_attack(sm,shore,shore.direction_to(target)).success,"通过原玩家出手事务从干岸发射锅铲")
 var hit:=false
 var damaged:=false
 for i in 60:
  var before_hit: float=actor().hp
  var result:=Run.combat_tick(sm,shore,0.01)
  if not result.success: break
  for event in result.get("hit_feedback",[]):
   if event.id==Boss.ID:
    hit=true
    damaged=actor().hp<before_hit
  if hit: break
 _check(hit and damaged and actor().frog_heal_quiet==0.0,"真实岸上攻击命中时扣血并打断回血，不误把弹体飞行前已恢复生命当作命中无效",{"actor":actor()})
 sm.data=saved

func recovery_checks() -> void:
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 var failed:=Run.combat_tick(sm,SAFE,0.1)
 _check(not failed.success and sm.data==before,"保存失败同时回滚回血与安静时钟")
 sm._active_save_path=path
 _check(Run.combat_tick(sm,SAFE,0.1).success,"恢复保存后继续实际回血")
 _check(sm.save(),"保存已有回血检查点")
 var checkpoint:=state()
 sm.load_data()
 var saved: Dictionary=checkpoint.combat.actors[Boss.ID]
 trace.append({"saved":saved,"reloaded":actor()})
 _check(is_equal_approx(float(actor().hp),float(saved.hp)) and is_equal_approx(float(actor().frog_heal_quiet),float(saved.frog_heal_quiet)) and is_equal_approx(float(state().combat.elapsed),float(checkpoint.combat.elapsed)) and actor().frog_phase==saved.frog_phase,"重新读取不离线补血或重置安静时钟")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.erase("frog_heal_quiet")
 _check(Run.valid(state()),"缺安静时钟的旧档仍合法")
 Run.combat_tick(sm,SAFE,0.5)
 _check(is_equal_approx(float(actor().hp),float(checkpoint.combat.actors[Boss.ID].hp)),"旧档缺时钟从零等待，不追补治疗")
 for value in [-1,2.1,"2",NAN]:
  var bad:=state()
  bad.combat.actors[Boss.ID].frog_heal_quiet=value
  _check(not Run.valid(bad),"拒绝损坏安静时钟："+str(value))
 a=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.frog_heal_quiet=2.0
 a.frog_phase="active"
 a.frog_left=0.0
 a.mode="chase"
 Run.Combat.Skills.damage(sm.data[Run.KEY],Boss.ID,8)
 _check(actor().frog_heal_quiet==0.0,"实际玩家受击立即打断恢复时钟")
 Run.combat_tick(sm,Vector2(880,490),0.1)
 Run.combat_tick(sm,Vector2(880,490),0.2)
 Run.combat_tick(sm,Vector2(880,490),0.1)
 _check(is_equal_approx(float(actor().frog_heal_quiet),0.4) and actor().mode=="chase","受击后按场景时间重计，重新交战不额外清零")
 a=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.position=[Boss.HOME.x,Boss.HOME.y]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.frog_phase="dormant"
 a.mode="idle"
 a.hit_remaining=0.0
 a.hp=95.9
 a.frog_heal_quiet=2.0
 Run.combat_tick(sm,SAFE,0.5)
 _check(actor().hp==96.0,"渐进回血达到上限不溢出")
 _check(Run.valid(state()),"满血检查点仍可合法保存")
