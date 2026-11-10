extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Skills=preload("res://scripts/maze/team_attack.gd")
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures==0:
  _completed()
  sm.cancel_maze_entry()
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
  var run: Dictionary=Run.snapshot(sm)
  var slot: int=-1
  for i in range(1,5):
   if Skills.kind(run,i)=="yaya": slot=i
  _check(slot>0,"已有队伍包含芽芽")
  if slot>0:
   run.combat.cooldown=0.0
   Skills.select(run,slot)
   sm.data[Run.KEY]=run
   _check(Run.combat_attack(sm,Roads.SPAWN,Vector2.DOWN).success,"时序检查起手")
   Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(),false,null,Vector2.DOWN)
   Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(),false,null,Vector2.DOWN)
   var timed: Dictionary=Run.snapshot(sm)
   _check(not timed.combat.shots.is_empty() and is_zero_approx(float(timed.combat.shots[-1].time)),"刚释放的第二颗不提前移动一个战斗步")
   var bounded: Dictionary=timed.duplicate(true)
   if not bounded.combat.shots.is_empty():
    var shot: Dictionary=bounded.combat.shots[0].duplicate(true)
    bounded.combat.shots.clear()
    for j in range(32): bounded.combat.shots.append(shot.duplicate(true))
    _check(Run.valid(bounded),"32颗在途状态仍合法")
    bounded.combat.shots.append(shot.duplicate(true))
    _check(not Run.valid(bounded),"33颗超过有界上限应拒绝")
   var max_shots: int=0
   var rounds: int=0
   for i in range(160):
    run=Run.snapshot(sm)
    var aim: Vector2=Vector2.RIGHT.rotated(i*0.3)
    if float(run.combat.cooldown)<=0.00001 and float(run.combat.get("action_left",0))<=0:
     var result: Dictionary=Run.combat_attack(sm,Roads.SPAWN,aim)
     _check(result.success,"连续真实出手事务",result)
     rounds+=1
    var tick: Dictionary=Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(),false,null,aim)
    if not tick.success:
     _check(false,"真实推进事务不可失败",tick)
     break
    run=Run.snapshot(sm)
    max_shots=maxi(max_shots,run.combat.shots.size())
   _check(rounds>=5 and Run.valid(Run.snapshot(sm)),"多轮旋转连发后完整状态合法",{"rounds":rounds,"max_shots":max_shots})
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("YAYA_FLOW ",checks," checks, ",failures," failures")
 get_tree().quit(1 if failures else 0)

