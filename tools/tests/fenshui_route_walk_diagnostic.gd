extends "res://tools/tests/ch2_entry_state.gd"

const Run = preload("res://scripts/maze/capture_run.gd")
const Fenshui = preload("res://data/maze/fenshui_roads.gd")
const Salt = preload("res://data/maze/salt_pool_roads.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"使用隔离存档")
 if failures: _finish(); return
 _completed()
 var story_case: bool=_arg("--phase=")=="story"
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"unseen" if story_case else "done","line":0}
 sm.data.fenshui_battle_guide_seen=not story_case
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"从正式探索出发")
 _check(Run.change_region(sm,"fenshui",Fenshui.SPAWN).success,"从正式分水庭入口开始")
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 var maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 var deadline:=Time.get_ticks_msec()+8000
 while (not maze._entry_ready or maze.player.input_locked) and Time.get_ticks_msec()<deadline:
  await get_tree().process_frame
 _check(maze._entry_ready and not maze.player.input_locked,"实际入场完成且输入恢复")
 if failures: _finish(); return
 if story_case:
  var guide=maze.get_node("FenshuiBattleGuide")
  var show_deadline:=Time.get_ticks_msec()+4000
  while not guide.dialog.visible and Time.get_ticks_msec()<show_deadline: await get_tree().process_frame
  _check(guide.dialog.visible and maze.yf_encounter.phase=="unseen","入口战斗引导先显示，原剧情尚未触发")
  var story_deadline:=Time.get_ticks_msec()+4000
  while maze.yf_encounter.phase!="intro" and Time.get_ticks_msec()<story_deadline:
   var direction: Vector2=maze.player.position.direction_to(Vector2(1495,250))
   Input.action_press("ui_left",maxf(-direction.x,0.0))
   Input.action_press("ui_down",maxf(direction.y,0.0))
   await get_tree().physics_frame
  Input.action_release("ui_left")
  Input.action_release("ui_down")
  await get_tree().process_frame
  _check(maze.yf_encounter.phase=="intro","从入口实际走过触发线启动剧情",{"position":str(maze.player.position),"retry":maze.yf_encounter.retry,"paused":maze.capture_flow.combat_paused(),"focus":maze.capture_flow.window_focused})
  _check(maze.yf_encounter.dialog.visible and not guide.dialog.visible,"剧情对白显示并暂时收起战斗引导")
  _finish()
  return
 var points: Array[Vector2]=[Vector2(1495,250),Vector2(1399,283),Vector2(1295,317),Vector2(1214,352),Vector2(1100,350),Vector2(1000,320),Vector2(900,300),Vector2(850,296),Vector2(877,230),Vector2(911,160),Vector2(887,118),Salt.FENSHUI_RETURN]
 for target in points:
  var result: bool=await _walk_to(maze,target,7.0)
  _check(result,"不传送行走至路径点 "+str(target),{"position":str(maze.player.position),"locked":maze.player.input_locked,"busy":maze._busy,"paused":maze.capture_flow.combat_paused(),"health":Run.snapshot(sm).combat.get("hp",-1)})
  if not result: break
 if failures==0:
  maze._update_prompts()
  _check(maze.settlement_prompt.visible,"实际走到盐池路标并显示交互")
 _finish()

func _walk_to(maze: Node,target: Vector2,seconds: float) -> bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
 while maze.player.position.distance_to(target)>5.0 and Time.get_ticks_msec()<deadline:
  var direction: Vector2=maze.player.position.direction_to(target)
  Input.action_press("ui_right",maxf(direction.x,0.0))
  Input.action_press("ui_left",maxf(-direction.x,0.0))
  Input.action_press("ui_down",maxf(direction.y,0.0))
  Input.action_press("ui_up",maxf(-direction.y,0.0))
  await get_tree().physics_frame
 for action in ["ui_right","ui_left","ui_down","ui_up"]: Input.action_release(action)
 await get_tree().physics_frame
 return maze.player.position.distance_to(target)<=6.0

func _finish() -> void:
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)
