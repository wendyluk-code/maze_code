extends "res://tools/tests/ch2_entry_state.gd"
## 仅在显式隔离的用户目录中建立对照，不改正式试玩进度。
const Run=preload("res://scripts/maze/capture_run.gd")
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
var maze: Node2D
@export var ranged_trial:=false

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 if not _verify_isolation():
  push_error("卡肉对照必须通过独立存档运行器启动")
  get_tree().quit(1)
  return
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"建立隔离探索")
 var run: Dictionary=Run.snapshot(sm)
 Run.ensure_region(run,"fenshui")
 run.combat.fs01_trial=false
 run.combat.cooldown=0.0
 run.combat.selected=0 if ranged_trial else 2
 for id in run.monsters: run.monsters[id].status="alive" if id=="fenshui_silverfish_1" else "skipped"
 var fish: Dictionary=run.combat.actors.fenshui_silverfish_1
 fish.position=[920.0,440.0]
 fish.fish_origin=fish.position.duplicate()
 fish.fish_aim=[0.0,1.0]
 fish.fish_hit=false
 Fish.phase(fish,"recover",2.5)
 sm.data[Run.KEY]=run
 _check(sm.record_maze_location("fenshui",Vector2(880,490)).success,"保存相同站位与生命")
 if failures>0:
  get_tree().quit(1)
  return
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 var controls:=preload("res://tools/previews/fenshui_hitstop_controls.gd").new()
 controls.ranged_trial=ranged_trial
 var initial_ms:=_arg("--hitstop-ms=")
 if initial_ms.is_valid_int() and int(initial_ms) in controls.durations(): controls.choice=controls.durations().find(int(initial_ms))
 add_child(controls)
 controls.attach(maze)
 get_window().title="料理迷宫 · 远程卡肉三档对照（铁山70毫秒）" if ranged_trial else "料理迷宫 · 铁山卡肉三档对照（隔离试玩）"
 if "--fs01-check" in OS.get_cmdline_user_args():
  await get_tree().process_frame
  _check(Run.valid(Run.snapshot(sm)) and controls.choice==0,"真实试玩入口保持合法探索且默认无停顿")
  _check(Run.snapshot(sm).monsters.values().filter(func(row): return row.status=="alive").size()==1,"真实试玩入口只放一只相同保护鱼")
  var event:=InputEventKey.new()
  event.keycode=KEY_F5
  event.pressed=true
  get_viewport().push_input(event)
  await get_tree().process_frame
  _check(controls.choice==1 and (is_equal_approx(maze.capture_flow.axe_hitstop.state.get("ranged_duration",0.0),0.03) if ranged_trial else is_equal_approx(maze.capture_flow.axe_hitstop.state.duration,0.04)),"真实试玩入口接通F5切档")
  FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"  "))
  get_tree().quit(1 if failures else 0)
