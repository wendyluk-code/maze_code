extends "res://tools/tests/fenshui_flow.gd"
const Salt=preload("res://data/maze/salt_pool_roads.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures>0: _finish_probe(); return
 await _new_scene()
 maze.capture_flow.set_process(false)
 for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
 for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key]=[]
 maze.travel_region("fenshui",Salt.FENSHUI_RETURN)
 await get_tree().create_timer(1.4).timeout
 maze=get_tree().current_scene
 _check(is_instance_valid(maze) and maze.region_id=="fenshui","旧流程固定等待后到达分水庭")
 if not is_instance_valid(maze) or maze.region_id!="fenshui": _finish_probe(); return
 maze.capture_flow.set_process(false)
 maze.camera.snap_to_target()
 maze._update_prompts()
 var status={"position":str(maze.player.position),"near":maze._near_destination(),"entry_ready":maze._entry_ready,"busy":maze._busy,"locked":maze.player.input_locked,"confirmation":maze.confirmation.visible,"story":maze.yf_encounter.phase,"focus":maze.capture_flow.window_focused,"prompt":maze.settlement_prompt.visible,"saved_region":sm.maze_exploration_state().region}
 _check(maze.settlement_prompt.visible,"旧流程固定等待后的盐池路标提示",status)
 maze.capture_flow.window_focused=true
 var deadline:=Time.get_ticks_msec()+4000
 while maze.yf_encounter.phase=="unseen" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
 maze._update_prompts()
 _check(maze.yf_encounter.phase=="intro" and maze.player.input_locked and not maze.settlement_prompt.visible,"聚焦后未完成的入口剧情触发并按原规则隐藏路标",{"phase":maze.yf_encounter.phase,"locked":maze.player.input_locked,"prompt":maze.settlement_prompt.visible,"position":str(maze.player.position)})
 _finish_probe()

func _finish_probe() -> void:
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)
