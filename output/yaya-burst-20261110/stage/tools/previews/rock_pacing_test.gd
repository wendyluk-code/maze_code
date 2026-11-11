extends "res://tools/tests/rock_lunge_flow.gd"
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实盐池入口")
 baseline=Run.snapshot(sm).duplicate(true)
 var run: Dictionary=baseline.duplicate(true)
 var c: Dictionary=run.combat
 Run.Combat.Rock.lunge_hurt(run,Vector2(900,425),Vector2(850,425),Vector2.RIGHT)
 _check(float(c.get("rock_stun_left",0))==0,"空地命中不眩晕")
 _check(is_equal_approx(float(c.hurt_recovery_left),0.3),"控制仅覆盖0.3秒短击飞")
 _check(is_equal_approx(float(c.rock_launch_left),0.3) and is_equal_approx(Run.Combat.vec(c.rock_launch_velocity).length()*0.3,40.0),"短击飞总距离40")
 var hp: float=c.hp
 Run.Combat.Rock.lunge_hurt(run,Vector2(900,425),Vector2(850,425),Vector2.RIGHT)
 _check(c.hp==hp,"击飞保护不重复扣血或刷新击飞")
 for kind in ["open","wall","edge"]:
  var spots: Dictionary=preload("res://tools/previews/rock_pacing_cases.gd").find(kind)
  _check(not spots.is_empty(),"找到真实地图站位："+kind)
  if spots.is_empty(): continue
  run=baseline.duplicate(true)
  c=run.combat
  Run.Combat.Rock.lunge_hurt(run,spots.hero,spots.beast,Vector2.RIGHT)
  var point: Vector2=spots.hero
  for i in 30:
   Run.Combat.PlayerHurt.advance(c,0.01)
   point=Run.Combat.advance_rock_launch(run,point,0.01)
  if kind=="open":
   _check(absf(point.distance_to(spots.hero)-40.0)<0.1 and c.rock_stun_left==0 and c.hurt_recovery_left==0,"空地飞40后立即恢复、不晕")
  else:
   _check(c.rock_stun_left>1.6 and c.rock_stun_left<=2.0 and c.rock_launch_left==0,"撞真实障碍/边缘才晕："+kind)
   Run.Combat.PlayerHurt.advance(c,2.0)
   _check(c.rock_stun_left==0 and c.hurt_recovery_left==0,"撞物眩晕2秒后恢复："+kind)
 run=baseline.duplicate(true)
 c=run.combat
 var free: Dictionary=preload("res://tools/previews/rock_pacing_cases.gd").find("open")
 for id in c.actors:
  if str(id).begins_with("salt_pool_") and id!=Boss.ID:
   c.actors[id].position=Run.Combat.pack(free.hero+Vector2(20,0))
   c.actors[id].hp=1.0
   run.monsters[id].status="alive"
   break
 Run.Combat.Rock.lunge_hurt(run,free.hero,free.beast,Vector2.RIGHT)
 var flown: Vector2=Run.Combat.advance_rock_launch(run,free.hero,0.3)
 _check(absf(flown.distance_to(free.hero)-40.0)<0.1 and c.rock_stun_left==0,"击飞经过其他怪物不触发撞墙眩晕")
 run=baseline.duplicate(true)
 c=run.combat
 var a: Dictionary=c.actors[Boss.ID]
 a.mode="chase"
 a.rock_phase="active"
 a.rock_reuse=12.0
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(70,0),0.01)
 _check(a.rock_phase=="lunge_charge" and a.rock_left==1.2,"普通冲撞蓄力1.2秒")
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(70,0),0.8)
 _check(a.rock_phase=="lunge_charge","旧0.7秒时点仍在蓄力")
 a.rock_phase="lunge"
 a.rock_left=0.0
 a.rock_distance=120.0
 a.rock_hit=true
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(70,0),0.01)
 _check(a.rock_phase=="lunge_recover" and a.rock_left==2.0,"普通冲撞后留2秒间隔")
 a.rock_combo=true
 a.rock_chain_left=4
 Run.Combat.Rock.begin_lunge(a,Boss.HOME+Vector2(70,0))
 _check(a.rock_left==1.1,"四连首冲蓄力1.1秒")
 _check(Run.Combat.valid(c),"新节奏与保护字段被真实战斗校验接受")
 run=baseline.duplicate(true)
 c=run.combat
 Run.Combat.Rock.lunge_hurt(run,Vector2(1060,190),Vector2(980,190),Vector2.RIGHT)
 var water_end:=Run.Combat.advance_rock_launch(run,Vector2(1060,190),0.3)
 _check(water_end.distance_to(Vector2(1100,190))<0.1 and c.rock_stun_left==0,"击飞穿过池岸不阻挡不眩晕")
 _check(Run.Combat.Rock.LUNGE_DISTANCE==160.0,"岩鬃兽每冲行程160单位")
 c.hero=Run.Combat.pack(water_end)
 for id in c.actors:
  if id!=Boss.ID: run.monsters[id].status="skipped"
 c.actors[Boss.ID].rock_phase="rest"
 c.actors[Boss.ID].rock_left=5.0
 sm.data[Run.KEY]=run
 _check(Run.combat_tick(sm,water_end,0.03).success,"落水后真实探索事务仍可推进，不回退卡死")
 var location: Dictionary=sm.record_maze_location("salt_pool",water_end)
 _check(location.success,"击飞落水位置自动保存与战斗允许位置一致",location)
 _check(not sm.record_maze_location("salt_pool",Vector2(520,360)).success,"水晶位置仍拒绝保存")
 var wet_state: Dictionary=sm.data.duplicate(true)
 sm.data[Run.KEY].combat.hero=Run.Combat.pack(Boss.HOME)
 sm.data[Run.KEY].combat.rock_launch_left=0.0
 _check(not sm.record_maze_location("salt_pool",water_end).success,"普通陆地状态不能借保存主动进入水池")
 sm.data=wet_state
 run=baseline.duplicate(true)
 c=run.combat
 a=c.actors[Boss.ID]
 a.position=[800.0,425.0]
 a.mode="chase"
 a.rock_phase="charge"
 a.rock_left=0.01
 a.rock_aim=[1.0,0.0]
 var fixed:=Vector2(900,425)
 c.hero=Run.Combat.pack(fixed)
 Run.Combat.Rock.advance(run,fixed,0.02)
 _check(a.rock_chain_left==4 and a.rock_phase=="rush","咆哮实际命中准备四连")
 var charges:=0
 var prior: String=a.rock_phase
 for i in 400:
  Run.Combat.advance(run,Run.Combat.vec(c.hero),0.03)
  if a.rock_phase=="lunge_charge" and prior!="lunge_charge": charges+=1
  prior=a.rock_phase
  if a.rock_phase=="rest": break
 _check(charges==4 and a.rock_phase=="rest" and a.rock_left==5.0,"咆哮后四次短冲完整结束再力竭5秒")
 var solid=preload("res://scripts/maze/rock_charge_terrain.gd")
 _check(not solid.allowed(Vector2(520,360)),"水晶仍为冲撞硬阻挡")
 _check(not solid.allowed(Vector2(1050,575)),"树丛仍为冲撞硬阻挡")
 _check(solid.allowed(Vector2(1233,367)),"散石不再触发冲撞阻挡")
 run=baseline.duplicate(true)
 c=run.combat
 for id in c.actors:
  if id!=Boss.ID: run.monsters[id].status="skipped"
 c.hero=[700.0,425.0]
 a=c.actors[Boss.ID]
 a.position=[800.0,425.0]
 a.mode="chase"
 a.rock_phase="lunge"
 a.rock_left=Run.Combat.Rock.LUNGE_DURATIONS.lunge
 a.rock_aim=[1.0,0.0]
 a.rock_distance=0.0
 a.rock_hit=false
 for i in 80: Run.Combat.Rock.advance(run,Vector2(700,425),0.01)
 _check(Run.Combat.vec(a.position).distance_to(Vector2(960,425))<0.01 and a.rock_phase=="lunge_recover","实际跨水短冲160单位后收势")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("ROCK_PACING ",checks," checks; failures=",failures)
 get_tree().quit(1 if failures else 0)
