extends "res://tools/tests/combat_07_flow.gd"
const Exit=preload("res://data/maze/settlement_exit.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	_check(not Roads.is_walkable(Vector2(13,699)) and not Exit.can_bank(Vector2(13,699)),"旧出口不可走且不可结算")
	for y in range(695,739):
		_check(not Roads.is_walkable(Vector2(90,y)),"不能绕过路标")
	_check(Roads.is_walkable(Exit.FRONT) and Exit.can_bank(Exit.FRONT),"路标前可站立及交互")
	_check(Roads.move_on_road(Exit.FRONT,Vector2(-200,0)).x>=98,"快速移动不会穿过路标")
	await _new_scene()
	maze.capture_flow.set_process(false)
	maze.player.position=Exit.FRONT
	maze.camera.snap_to_target()
	maze._update_prompts()
	_check(not maze.exit_prompt.visible and maze.settlement_prompt.visible,"只显示路标前下一区域提示")
	await _capture_image("portal_front")
	maze.player.position=Vector2(13,699)
	maze._update_prompts()
	_check(not maze.exit_prompt.visible and maze._near_destination()=="","旧位置不再显示E出口")
	maze.player.position=Exit.FRONT
	maze._open_confirmation("下一区域")
	_check(maze.confirmation.visible,"前侧交互打开既有选择")
	maze._close_confirmation()
	_check(not maze.player.input_locked,"取消恢复操作")
	maze.return_to_restaurant(true)
	await get_tree().create_timer(0.8).timeout
	_check(sm.maze_exploration_state().region=="restaurant" and not Run.snapshot(sm).active,"路标前仍能正常带食材返回")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
