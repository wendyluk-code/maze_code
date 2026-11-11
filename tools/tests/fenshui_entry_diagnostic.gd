extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const FenshuiRoads=preload("res://data/maze/fenshui_roads.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures>0: _finish(); return
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"开始探索")
 _check(Run.change_region(sm,"fenshui",FenshuiRoads.SPAWN).success,"事务切入分水庭")
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 var guide: Node=maze.get_node("FenshuiBattleGuide")
 _check(await until_true(func(): return guide.dialog.visible),"入口引导显示")
 var player: Node2D=maze.player
 var origin: Vector2=player.position
 var destination: Vector2=origin+Vector2(-1,0)
 var before={"position":str(origin),"walkable":player.terrain.is_walkable(origin),"terrain_step":str(player.terrain.move_on_road(origin,Vector2(-1,0))),"body_allowed":maze.capture_flow.movement_allowed(origin,destination),"portal_allowed":player._portal_step_allowed(origin,destination),"process":player.is_physics_processing(),"paused":maze.capture_flow.combat_paused(),"tree_paused":get_tree().paused}
 Input.action_press("ui_left")
 var direction:=Input.get_vector("ui_left","ui_right","ui_up","ui_down")
 var frames: Array=[]
 for i in 12:
  await get_tree().physics_frame
  frames.append({"position":str(player.position),"direction":str(Input.get_vector("ui_left","ui_right","ui_up","ui_down")),"focused":maze.capture_flow.window_focused,"paused":maze.capture_flow.combat_paused(),"recovering":maze.capture_flow.player_recovering()})
 Input.action_release("ui_left")
 trace.append({"before":before,"held_direction":str(direction),"after":str(player.position),"frames":frames,"viewport_mode":viewport.process_mode,"maze_mode":maze.process_mode,"tree_paused":get_tree().paused})
 _check(player.position.distance_to(origin)>0.1,"入口非模态引导期间按左键移动",trace.back())
 _finish()
