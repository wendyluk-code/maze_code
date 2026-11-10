extends "res://tools/tests/rock_lunge_flow.gd"
const Route=preload("res://scripts/maze/rock_combo_path.gd")
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离用户目录")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"真实探索创建")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实盐池")
 var run: Dictionary=Run.snapshot(sm)
 for id in run.monsters:
  if id!=Boss.ID: run.monsters[id].status="skipped"
 var hero:=Vector2(850,550)
 run.combat.hero=Run.Combat.pack(hero)
 var origin:=hero+Vector2(-90,0)
 for side in 4:
  var angle:=PI+side*PI/2.0
  run.combat.actors[Boss.ID].position=Run.Combat.pack(origin)
  var route:=Route.plan(run,origin,hero,angle)
  _check(not route.is_empty(),"真实盐池侧面路径存在："+str(side))
  if route.is_empty(): continue
  for p in route:
   var target:=Run.Combat.vec(p)
   _check(Route.clear(run,origin,target),"路径段不穿玩家、怪物和地形")
   origin=target
  _check(absf(wrapf(hero.angle_to_point(origin)-angle,-PI,PI))<0.45,"到达指定侧扇区")
  _check(origin.distance_to(hero)>=65.0,"侧点有蓄力距离")
 _full_sequence(run.duplicate(true))
 _moving_sequence(run.duplicate(true))
 _edge_cases(run.duplicate(true))
 _monster_pair(run.duplicate(true))
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("FOUR_SIDE_PATH ",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)

func _full_sequence(run: Dictionary) -> void:
 var hero:=Vector2(850,550)
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.position=[760.0,550.0]
 a.mode="chase"
 Run.Combat.Rock.start_combo(a,hero)
 var directions: Array=[]
 var previous: String=a.rock_phase
 for i in 2400:
  run.combat.hero=Run.Combat.pack(hero)
  run.combat.hp=36.0
  run.combat.elapsed+=0.016
  Run.Combat.Rock.advance_status(run.combat,0.016)
  Run.Combat.Rock.advance(run,hero,0.016)
  hero=Run.Combat.advance_rock_launch(run,hero,0.016)
  if a.rock_phase=="lunge" and previous!="lunge": directions.append(Run.Combat.vec(a.rock_aim).angle())
  previous=a.rock_phase
  if a.rock_phase=="rest": break
 print("COMBO_DIRECTIONS=",directions," phase=",a.rock_phase," note=",a.get("rock_combo_note","")," boss=",a.position," hero=",hero)
 _check(directions.size()==4,"完整四次冲撞实际释放")
 if directions.size()==4:
  for n in range(1,4): _check(absf(wrapf(float(directions[n])-float(directions[n-1]),-PI,PI))>0.8,"相邻攻击来自不同侧面")
 _check(a.rock_phase=="rest" and float(a.rock_left)>4.9,"完成后5秒力竭")

func _moving_sequence(run: Dictionary) -> void:
 var hero:=Vector2(850,550)
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.position=[760.0,550.0]
 Run.Combat.Rock.start_combo(a,hero)
 var releases:=0
 var previous: String=a.rock_phase
 for i in 2400:
  if a.rock_phase=="combo_reposition":
   var next:=hero+Vector2(0.0,sin(float(i)*0.016)*0.12)
   if Route.Bodies.step(run,"hero",hero,next): hero=next
  run.combat.hero=Run.Combat.pack(hero)
  run.combat.hp=36.0
  run.combat.elapsed+=0.016
  Run.Combat.Rock.advance_status(run.combat,0.016)
  Run.Combat.Rock.advance(run,hero,0.016)
  hero=Run.Combat.advance_rock_launch(run,hero,0.016)
  if a.rock_phase=="lunge" and previous!="lunge": releases+=1
  previous=a.rock_phase
  if a.rock_phase=="rest": break
 print("MOVING_COMBO releases=",releases," phase=",a.rock_phase," note=",a.get("rock_combo_note",""))
 _check(releases==4,"轻微移动目标仍完成四次真实释放")
 _check(a.rock_phase=="rest","移动目标连段正常结束")

func _edge_cases(run: Dictionary) -> void:
 var a: Dictionary=run.combat.actors[Boss.ID]
 var hero:=Vector2(850,550)
 a.position=[810.0,550.0]
 run.combat.hero=Run.Combat.pack(hero)
 Run.Combat.Rock.start_combo(a,hero)
 _check(a.rock_phase=="combo_reposition","贴身也接受四连，先绕位")
 for i in 500:
  Run.Combat.Rock.advance(run,hero,0.016)
  if a.rock_phase=="lunge_charge": break
 _check(a.rock_phase=="lunge_charge","贴身准备可进入真实蓄力")
 var aim: Array=a.rock_aim.duplicate()
 Run.Combat.Rock.advance(run,hero+Vector2(12,8),0.02)
 _check(a.rock_aim==aim,"蓄力锁向后玩家移动不追踪转向")
 a.position=[850.0,550.0]
 hero=Vector2(900,550)
 run.combat.hero=Run.Combat.pack(hero)
 for n in 8:
  var id: String="salt_pool_mimic_crab_block"+str(n)
  run.monsters[id]={"status":"alive"}
  var p:=Vector2(850,550)+Vector2.RIGHT.rotated(n*TAU/8.0)*8.0
  run.combat.actors[id]={"hp":10.0,"position":Run.Combat.pack(p)}
 Run.Combat.Rock.start_combo(a,hero)
 for i in 500:
  Run.Combat.Rock.advance(run,hero,0.016)
  if a.rock_phase=="rest": break
 _check(a.rock_phase=="rest" and not a.rock_combo and not str(a.get("rock_combo_note","")).is_empty(),"完全被围时有界退出并说明，不无限卡住")

func _monster_pair(run: Dictionary) -> void:
 var rows:=Run.Catalog.Salt.all()
 var first: Dictionary=rows[1]
 var second: Dictionary=rows[4]
 for id in run.monsters: run.monsters[id].status="skipped"
 run.monsters[first.id].status="alive"
 run.monsters[second.id].status="alive"
 var a: Dictionary=run.combat.actors[first.id]
 var b: Dictionary=run.combat.actors[second.id]
 var origin: Vector2=first.position
 a.position=Run.Combat.pack(origin)
 b.position=Run.Combat.pack(origin+Vector2(-30,0))
 a.mode="chase"
 a.cooldown=1.0
 b.mode="windup"
 b.windup=1.5
 b.attack_aim=[-1.0,0.0]
 var hero:=origin+Vector2(-60,0)
 run.combat.hero=Run.Combat.pack(hero)
 var blocked:=run.duplicate(true)
 Run.Combat.advance(blocked,hero,0.2)
 var free:=run.duplicate(true)
 free.monsters[second.id].status="skipped"
 Run.Combat.advance(free,hero,0.2)
 var blocked_distance:=origin.distance_to(Run.Combat.vec(blocked.combat.actors[first.id].position))
 var free_distance:=origin.distance_to(Run.Combat.vec(free.combat.actors[first.id].position))
 print("BODY_PAIR_DISTANCE blocked=",blocked_distance," free=",free_distance)
 _check(free_distance>blocked_distance and blocked_distance<=6.01,"真实战斗推进中普通怪被另一只普通怪挡住")
