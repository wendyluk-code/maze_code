extends "res://tools/tests/combat_04_state.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution; suffix="_%dx%d"%[resolution.x,resolution.y]
			await _access()
	_report()

func _access() -> void:
	_setup(); Run.finish(sm,false,Roads.SPAWN)
	scene=load("res://scenes/restaurant_map_2d.tscn").instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene=scene
	await get_tree().create_timer(1.0).timeout
	for i in 6:
		await _send_key(KEY_E); await get_tree().create_timer(0.15).timeout
	var ui=get_tree().get_first_node_in_group("ui_layer")
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	for display in ["冒险者之家入口","迷宫入口"]:
		var target: Node2D
		for node in get_tree().get_nodes_in_group("interactable"):
			if str(node.get("display_name"))==display: target=node
		_check(is_instance_valid(target),"入口目标存在："+display)
		if not is_instance_valid(target): continue
		var point:=_stand(target)
		await get_tree().create_timer(0.25).timeout
		_check(ui._buttons[target].visible and ui.is_target_in_interaction_range(target),"靠近入口显示原交互按钮："+display)
		if display=="冒险者之家入口":
			await _click(ui._buttons[target])
			await get_tree().create_timer(0.2).timeout
			var home=get_tree().get_first_node_in_group("adventurer_home")
			_check(is_instance_valid(home),"真实入口鼠标打开冒险者之家")
			if is_instance_valid(home):
				await _click(home.character_buttons.yaya)
				_check(home.cards_modal.visible,"真实入口角色详情可用")
				await _send_key(KEY_ESCAPE); await _click(home.back_button)
		else:
			await _send_key(KEY_E)
			await get_tree().create_timer(0.2).timeout
			_check(hud.confirmation.visible and not ui._buttons[target].visible,"真实入口E打开队伍并隐藏交互提示")
			await _click(hud.confirmation.cancel_button)
		await get_tree().create_timer(0.1).timeout
		_check(not hud._player.input_locked and hud._player.is_physics_processing(),"关闭页面恢复实际玩家输入："+display)
		# 移动到已知合法且远离目标的初始出生附近，检查原距离显隐。
		var other: Node2D=scene.get_node("InteractPoints/Store")
		_stand(other)
		await get_tree().create_timer(0.15).timeout
		_check(not ui._buttons[target].visible,"离开入口原按钮隐藏："+display)
		hud._player.position=point
	scene.queue_free(); await get_tree().process_frame
