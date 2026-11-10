extends "res://tools/tests/rock_lunge_flow.gd"
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实盐池入口")
 var baseline: Dictionary=Run.snapshot(sm)
 for release in [0.45,1.0]:
  var run: Dictionary=baseline.duplicate(true)
  for id in run.monsters:
   if id!=Boss.ID: run.monsters[id].status="skipped"
  var a: Dictionary=run.combat.actors[Boss.ID]
  a.position=[800.0,425.0]
  a.mode="chase"
  a.rock_phase="charge"
  a.rock_left=0.01
  a.rock_aim=[1.0,0.0]
  var point:=Vector2(900,425)
  run.combat.hero=Run.Combat.pack(point)
  sm.data[Run.KEY]=run
  sm.record_maze_location("salt_pool",point)
  Run.Combat.Rock.Tuning.values={"rock.roar":{"release":release}}
  var tick: Dictionary=Run.combat_tick(sm,point,0.02)
  var after: Dictionary=Run.snapshot(sm)
  var next: Dictionary=Run.combat_tick(sm,point,0.02)
  var attack: Dictionary=Run.combat_attack(sm,point,Vector2.LEFT)
  _check(tick.success and next.success and attack.success and Run.valid(after),"允许的咆哮时长可以提交并继续时钟与输入："+str(release),{"result":tick,"next":next,"attack":attack,"valid":Run.valid(after),"elapsed":after.combat.elapsed,"shake":after.combat.get("rock_shake_left")})
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)
