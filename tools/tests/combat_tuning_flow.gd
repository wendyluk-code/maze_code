extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"只使用隔离用户目录")
 if failures: get_tree().quit(1); return
 _completed()
 sm.cancel_maze_entry()
 Tuning.load_settings()
 _check(Tuning.error.is_empty(),"正式读取器接受参数文件",{"error":Tuning.error})
 var saved:=Tuning.values.duplicate(true)
 if not OS.get_environment("MAZE_COMBAT_TEST_SETTINGS_FILE").is_empty():
  _check(Tuning.effect("water","speed",190.0)==250.0,"新进程从已保存文件读取水枪弹速")
 Tuning.values={}
 Tuning.initialized=true
 var original_stats:=Run.Combat.STATS.duplicate(true)
 for monster in original_stats:
  var health:=int(original_stats[monster].hp)+7
  var attack:=int(original_stats[monster].attack)+2
  Tuning.values={"base."+str(monster):{"hp":health,"attack":attack}}
  var fresh:=preload("res://scripts/maze/monster_combat.gd").fresh_actor(monster,Vector2.ZERO)
  _check(fresh.hp==health,"怪物生命读取覆盖："+str(monster))
  _check(preload("res://scripts/maze/monster_editor.gd").attack(monster,0)==attack,"怪物基础攻击读取覆盖："+str(monster))
 for monster in original_stats: Run.Combat.STATS[monster]=original_stats[monster].duplicate(true)
 Tuning.values={}
 _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
 _check(Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").SPAWN).success,"进入真实分水庭")
 var base: Dictionary=Run.snapshot(sm)
 base.combat.frog_unlocked=true
 for id in base.monsters:
  if id!=Run.Combat.Frog.Config.ID: base.monsters[id].status="skipped"
 var frog: String=Run.Combat.Frog.Config.ID
 for speed in [100.0,250.0]:
  Tuning.values={"effect.water":{"speed":speed,"distance":400.0,"hit_radius":10.0,"damage":20.0}}
  var run:=base.duplicate(true)
  run.combat.actors[frog].frog_shots=[{"position":[900.0,450.0],"direction":[1.0,0.0],"distance":0.0}]
  Run.Combat.Frog.advance_projectiles(run,Vector2(1000,450),0.1,[])
  var shots: Array=run.combat.actors[frog].frog_shots
  _check(shots.size()==1 and absf(float(shots[0].position[0])-900.0-speed*0.1)<0.01,"真实水枪位移消费弹速："+str(speed))
 for radius in [3.0,30.0]:
  Tuning.values={"effect.water":{"speed":250.0,"distance":400.0,"hit_radius":radius,"damage":20.0,"hurt":1200.0}}
  var run:=base.duplicate(true)
  run.combat.actors[frog].frog_shots=[{"position":[900.0,450.0],"direction":[1.0,0.0],"distance":0.0}]
  var events: Array=[]
  Run.Combat.Frog.advance_projectiles(run,Vector2(930,465),0.15,events)
  _check((run.combat.hp<base.combat.hp)==(radius==30.0),"实际命中半径改变擦边判定："+str(radius))
  if radius==30.0:
   _check(events.size()==1 and run.combat.hurt_recovery_left==1.2,"命中后实际硬直1200毫秒并生成受击事件")
   _check(base.combat.hp-run.combat.hp==Run.Combat.Skills.incoming_damage(run,20),"独立水枪伤害经过正式防御计算")
   _check(Run.valid(run),"非默认命中结果满足原战斗状态校验")
 Tuning.values={"effect.water":{"distance":40.0,"speed":250.0}}
 var short:=base.duplicate(true)
 short.combat.actors[frog].frog_shots=[{"position":[900.0,450.0],"direction":[1.0,0.0],"distance":0.0}]
 Run.Combat.Frog.advance_projectiles(short,Vector2(1000,450),0.2,[])
 _check(short.combat.actors[frog].frog_shots.is_empty() and short.combat.hp==base.combat.hp,"短射程到期消失，不继续命中远处玩家")
 Tuning.values={"effect.water":{"windup":1100.0,"interval_scale":150.0,"recover":900.0}}
 var actor: Dictionary=base.combat.actors[frog].duplicate(true)
 Run.Combat.Frog.prepare_spit(actor,Vector2(900,450),Vector2(950,450))
 _check(actor.windup==1.1 and is_equal_approx(actor.cooldown,3.3),"水枪前摇与间隔独立消费")
 actor.frog_spit_left=0.9
 _check(Run.Combat.Frog.valid(actor),"扩展收势时间通过同源校验")
 var recovering:=base.duplicate(true)
 recovering.combat.actors[frog].frog_phase="active"
 recovering.combat.actors[frog].mode="chase"
 recovering.combat.actors[frog].frog_spit_left=0.9
 Run.Combat.Frog.advance(recovering,Vector2(955,450),0.1,0.0,[])
 _check(recovering.combat.actors[frog].frog_phase=="active" and recovering.combat.actors[frog].mode=="chase","水枪收势期间不抢先跳跃或重开前摇")
 Tuning.values={"frog.skill":{"range":70.0}}
 var long_slam: Dictionary=base.combat.actors[frog].duplicate(true)
 Tuning.values={"effect.slam":{"windup":2500.0,"recover":3000.0}}
 long_slam.frog_phase="warning"
 long_slam.frog_left=2.5
 _check(Run.Combat.Frog.valid(long_slam),"可调砸击前摇2.5秒通过校验")
 long_slam.frog_phase="landing"
 long_slam.frog_left=3.0
 _check(Run.Combat.Frog.valid(long_slam),"可调砸击收势3秒通过校验")
 Tuning.values={"frog.skill":{"range":70.0}}
 var small:=Run.Combat.Frog.ElectricArea.polygon(Vector2(900,450),frog+"_slam")
 Tuning.values={"frog.skill":{"range":160.0}}
 var large:=Run.Combat.Frog.ElectricArea.polygon(Vector2(900,450),frog+"_slam")
 _check(small!=large,"相同中心修改范围使预警与判伤共用轮廓刷新")
 Tuning.values=saved
 var maze_script: Script=load("res://scripts/maze/maze_entry.gd")
 _check(maze_script!=null and maze_script.can_instantiate(),"真实迷宫显示入口及依赖可解析")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"  "))
 print("COMBAT_TUNING ",checks," checks; failures=",failures)
 get_tree().quit(1 if failures else 0)
