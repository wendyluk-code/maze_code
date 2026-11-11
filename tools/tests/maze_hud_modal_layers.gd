extends "res://tools/tests/combat_02_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _new_scene()
			var stamina = maze._ui_root.get_node("StaminaCounter")
			for modal in [maze.backpack_warehouse,maze.confirmation,maze.loot_modal,maze.capture_flow.dialog,maze.capture_flow.reward,maze.capture_flow.attempt,maze.capture_flow.character_details]:
				_check(modal.get_canvas_layer_node()==stamina.get_canvas_layer_node() and modal.get_index()>stamina.get_index(),"迷宫蒙层绘制于体力和饱食度之后："+str(modal.get_script().resource_path))
			maze._open_backpack()
			await get_tree().create_timer(0.2).timeout
			_check(maze.backpack_warehouse.visible,"迷宫实际打开背包")
			await _capture_image("maze_backpack_hud_below")
			await _send_key(KEY_ESCAPE)
			_check(not maze.backpack_warehouse.visible,"关闭背包恢复")
			await _close_scene()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
