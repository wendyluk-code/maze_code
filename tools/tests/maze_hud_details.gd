extends "res://tools/tests/combat_04_state.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(), "存档隔离")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size=resolution
		suffix="_%dx%d"%[resolution.x,resolution.y]
		_setup()
		maze=load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze); get_tree().current_scene=maze
		await get_tree().create_timer(0.7).timeout
		var flow=maze.capture_flow
		var stamina=get_tree().get_first_node_in_group("stamina_counter")
		var food=flow.party_food.get_parent()
		_check(not is_instance_valid(flow.party_panel), "小队缩略模块移除")
		_check(absf(stamina.get_global_rect().position.x-food.get_global_rect().end.x-24)<1, "饱腹与体力间隔24像素")
		_check(absf(food.get_global_rect().get_center().y-stamina.counter.get_global_rect().get_center().y)<1, "饱腹体力同高度")
		await _capture_image("hud")
		for slot in [0,3,1,2]:
			var button=flow.skill_bar.buttons[slot]
			await _click(button)
			_check(not flow.character_details.visible, "单击不打开详情")
			var event:=InputEventMouseButton.new()
			event.position=button.get_global_rect().get_center()
			event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.double_click=true
			get_viewport().push_input(event)
			event=InputEventMouseButton.new()
			event.position=button.get_global_rect().get_center(); event.button_index=MOUSE_BUTTON_LEFT
			get_viewport().push_input(event)
			await get_tree().create_timer(0.15).timeout
			if slot in [1,2]:
				_check(flow.character_details.visible and flow.character_details.character_id==("yaya" if slot==1 else "tieshan"), "双击打开对应详情")
				_check(maze.player.input_locked,"详情锁定玩家")
				await _capture_image("details_"+str(slot))
				await _send_key(KEY_ESCAPE)
				await get_tree().create_timer(0.1).timeout
				_check(not flow.character_details.visible and not maze.player.input_locked,"关闭恢复输入")
			else: _check(not flow.character_details.visible,"锅铲空位双击无详情")
		maze.queue_free(); await get_tree().process_frame
	_report()
