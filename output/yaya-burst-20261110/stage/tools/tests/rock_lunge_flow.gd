extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Boss=preload("res://data/maze/salt_boss.gd")
var baseline: Dictionary
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures==0:
  _completed()
  sm.cancel_maze_entry()
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
  _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实盐池入口")
  baseline=Run.snapshot(sm).duplicate(true)
  _protection()
  _lunge()
  _launch()
  _wall_weakness()
  _transaction()
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"  "))
 print("ROCK_LUNGE ",checks," checks, ",failures," failures")
 get_tree().quit(1 if failures else 0)

func _protection() -> void:
 for weapon in ["hero","yaya","tieshan"]:
  var run: Dictionary=baseline.duplicate(true)
  var a: Dictionary=run.combat.actors[Boss.ID]
  var before: Dictionary=a.duplicate(true)
  var feedback: Array=[]
  var clock: Dictionary={}
  Run.Combat.Monster.impact(run,Boss.ID,5,weapon,Boss.HOME,Vector2.RIGHT,feedback,clock)
  _check(a==before and feedback.is_empty() and clock.is_empty(),"正常态阻断伤害、击退、白闪、命中特效和卡肉："+weapon)
 var run: Dictionary=baseline.duplicate(true)
 var a: Dictionary=run.combat.actors[Boss.ID]
 Run.Combat.Skills.damage(run,Boss.ID,5)
 _check(a.hp==120 and float(a.get("hit_remaining",0))==0,"旧直接伤害入口不能绕过保护")
 run=baseline.duplicate(true)
 a=run.combat.actors[Boss.ID]
 a.rock_phase="rest"
 a.rock_left=1.5
 var feedback: Array=[]
 Run.Combat.Monster.impact(run,Boss.ID,5,"hero",Boss.HOME,Vector2.RIGHT,feedback)
 _check(a.hp==115 and feedback.size()==1,"既有咆哮力竭窗口允许实际伤害")
 run=baseline.duplicate(true)
 for id in run.combat.actors:
  if id!=Boss.ID and run.monsters.has(id): run.monsters[id].status="defeated"
 run.combat.actors[Boss.ID].position=[Boss.HOME.x,Boss.HOME.y]
 run.combat.axe_pending=true
 run.combat.action_left=0.29
 run.combat.throws=41
 run.combat.axe_damage=5
 var axe_clock={"duration":0.07,"left":0.0,"ids":[],"serial":-1,"step_held":0.0,"step_ids":[]}
 Run.Combat.Skills.advance(run,Boss.HOME,0.0,axe_clock)
 _check(axe_clock.left==0.0 and axe_clock.ids.is_empty(),"铁山命中保护态岩鬃兽不触发有效命中卡肉")
 _check(Run.Combat.Monster.eligible(run,Boss.ID),"保护态岩鬃兽仍可锁定和瞄准")

func _lunge() -> void:
 var run: Dictionary=baseline.duplicate(true)
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[Boss.ID]
 var point:=Vector2(920,425)
 _check(Boss.line(Boss.HOME,point,Boss.BODY),"冲撞测试站位之间可通行")
 a.position=[Boss.HOME.x,Boss.HOME.y]
 a.mode="chase"
 a.rock_phase="active"
 a.rock_left=0.0
 a.rock_reuse=6.0
 Run.Combat.Rock.advance(run,point,0.01)
 _check(a.rock_phase=="lunge_charge","正常追击优先进入单次冲撞前摇")
 var aim: Array=a.rock_aim.duplicate()
 Run.Combat.Rock.advance(run,point,0.7)
 _check(a.rock_phase=="lunge" and a.rock_aim==aim,"冲撞锁向后进入直线冲刺")
 var before: float=c.hp
 for i in 3:
  Run.Combat.Rock.advance(run,point,0.1)
 _check(c.hp<before,"冲撞经过玩家时实际扣血")
 _check(is_equal_approx(float(c.get("hurt_recovery_left",0.0)),1.0),"冲撞命中后玩家眩晕一秒")
 _check(float(c.get("rock_launch_left",0.0))>0.0,"冲撞命中启动击飞")
 _check(Run.Combat.valid(c),"冲撞中的战斗事务状态可以保存和恢复")

func _launch_run() -> Dictionary:
 var run: Dictionary=baseline.duplicate(true)
 for id in run.combat.actors:
  if id!=Boss.ID and run.monsters.has(id): run.monsters[id].status="skipped"
 run.combat.actors[Boss.ID].rock_phase="rest"
 run.combat.actors[Boss.ID].rock_left=1.5
 run.combat.hurt_recovery_left=1.0
 run.combat.rock_launch_left=0.4
 run.combat.rock_launch_velocity=[300.0,0.0]
 return run

func _launch() -> void:
 var run: Dictionary=_launch_run()
 var start:=Vector2(900,425)
 _check(Salt.is_walkable(start) and Salt.is_walkable(start+Vector2(30,0)),"击飞测试使用真实可走地面")
 Run.Combat.advance(run,start,0.1)
 _check(Run.Combat.vec(run.combat.hero).distance_to(start+Vector2(30,0))<0.1,"击飞未撞物时沿冲撞方向移动")
 _check(is_equal_approx(float(run.combat.rock_launch_left),0.3),"击飞时钟推进")
 _check(is_equal_approx(float(run.combat.hurt_recovery_left),0.9),"未撞物时保留原一秒眩晕的剩余时间")
 var edge:=Vector2.INF
 for y in range(100,900,10):
  for x in range(80,1500,10):
   var p:=Vector2(x,y)
   if Salt.is_walkable(p) and not Salt.is_walkable(p+Vector2(30,0)) and p.distance_to(Boss.HOME)>100.0:
    edge=p
    break
  if edge!=Vector2.INF: break
 _check(edge!=Vector2.INF,"真实盐池存在可测试的障碍边缘")
 if edge!=Vector2.INF:
  run=_launch_run()
  Run.Combat.advance(run,edge,0.1)
  _check(is_zero_approx(float(run.combat.rock_launch_left)),"击飞撞障碍后停止")
  _check(is_equal_approx(float(run.combat.hurt_recovery_left),2.0),"撞障碍从碰撞时重计两秒眩晕")
  _check(Run.Combat.valid(run.combat),"撞障碍后的两秒眩晕可保存")
 run=_launch_run()
 var other:="salt_pool_mimic_crab_1"
 run.monsters[other].status="alive"
 run.combat.actors[other].position=[940.0,425.0]
 Run.Combat.advance(run,start,0.1)
 _check(is_zero_approx(float(run.combat.rock_launch_left)) and is_equal_approx(float(run.combat.hurt_recovery_left),2.0),"击飞撞其他存活怪物同样重计两秒")
 run=_launch_run()
 run.combat.rock_launch_left=-1.0
 _check(not Run.Combat.valid(run.combat),"错误的击飞时钟不能进入探索事务")

func _wall_weakness() -> void:
 var edge:=Vector2.INF
 for y in range(100,900,10):
  for x in range(80,1500,10):
   var p:=Vector2(x,y)
   if Boss.allowed(p) and not Boss.allowed(p+Vector2(30,0)):
    edge=p
    break
  if edge!=Vector2.INF: break
 _check(edge!=Vector2.INF,"真实盐池存在岩鬃兽可撞的障碍")
 if edge==Vector2.INF: return
 var run: Dictionary=baseline.duplicate(true)
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[Boss.ID]
 a.position=[edge.x,edge.y]
 a.mode="chase"
 a.rock_phase="lunge"
 a.rock_left=0.4
 a.rock_distance=0.0
 a.rock_hit=false
 a.rock_aim=[1.0,0.0]
 Run.Combat.Rock.advance(run,Salt.SPAWN,0.1)
 _check(a.rock_phase=="stunned" and is_equal_approx(float(a.rock_left),1.5),"岩鬃兽冲撞障碍后眩晕1.5秒")
 var before: float=a.hp
 Run.Combat.Monster.impact(run,Boss.ID,5,"hero",edge,Vector2.RIGHT,[])
 _check(a.hp==before-5.0,"撞障碍眩晕期间可以对岩鬃兽造成伤害")
 Run.Combat.Rock.advance(run,Salt.SPAWN,0.1)
 _check(is_equal_approx(float(a.rock_left),1.4),"眩晕期间受击不延长弱点窗口")
 for i in 14: Run.Combat.Rock.advance(run,Salt.SPAWN,0.1)
 _check(a.rock_phase=="active" and Run.Combat.Monster.protected_rockmane(run,Boss.ID),"眩晕结束后恢复保护")
 _check(is_equal_approx(float(Boss.TYPE.width),168.0),"岩鬃兽身体显示为原宽度的1.4倍")

func _transaction() -> void:
 var run: Dictionary=baseline.duplicate(true)
 for id in run.combat.actors:
  if id!=Boss.ID and run.monsters.has(id): run.monsters[id].status="skipped"
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.position=[Boss.HOME.x,Boss.HOME.y]
 a.mode="chase"
 a.rock_phase="lunge"
 a.rock_left=0.4
 a.rock_distance=0.0
 a.rock_hit=false
 a.rock_aim=[1.0,0.0]
 sm.data[Run.KEY]=run
 var point:=Vector2(900,425)
 _check(sm.record_maze_location("salt_pool",point).success,"单冲事务使用真实盐池站位")
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 # 新起步曲线前0.1秒只走28.125；0.15秒已越过50距离的18接触半径。
 var denied: Dictionary=Run.combat_tick(sm,point,0.15)
 _check(not denied.success and sm.data==before,"冲撞命中保存失败时生命和位置完整回滚")
 sm._active_save_path=path
 var result: Dictionary=Run.combat_tick(sm,point,0.15)
 var after: Dictionary=Run.snapshot(sm)
 _check(result.success and float(after.combat.hp)<float(before[Run.KEY].combat.hp),"保存恢复后经真实战斗事务完成冲撞命中")
 _check(float(after.combat.get("rock_launch_left",0.0))>0.0 and Run.Combat.vec(after.combat.hero).x>point.x,"真实事务提交击飞计时与位置")
 _check(Run.valid(after),"真实命中后的探索状态仍合法")
 sm.load_data()
 var loaded: Dictionary=Run.snapshot(sm)
 _check(Run.valid(loaded) and is_equal_approx(float(loaded.combat.rock_launch_left),float(after.combat.rock_launch_left)),"重载保留合法的击飞剩余时间")
 var tick:=Run.combat_tick(sm,Run.Combat.vec(loaded.combat.hero),0.05)
 _check(tick.success and float(Run.snapshot(sm).combat.rock_launch_left)<float(loaded.combat.rock_launch_left),"重载后击飞按剩余时间继续")
 var migrating: Dictionary=Run.snapshot(sm)
 migrating.combat.actors[Boss.ID].mode="idle"
 migrating.combat.shots=[]
 migrating.combat.enemy_shots=[]
 migrating.combat.axe_pending=false
 migrating.combat.action_left=0.0
 sm.data[Run.KEY]=migrating
 _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"非战斗状态可以换区")
 _check(is_zero_approx(float(Run.snapshot(sm).combat.get("rock_launch_left",0.0))),"换区清理岩鬃兽击飞")
 var invalid:=_launch_run()
 invalid.combat.rock_launch_velocity=[INF,0.0]
 _check(not Run.Combat.valid(invalid.combat),"无效击飞向量不能通过事务校验")
