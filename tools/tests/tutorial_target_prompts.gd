extends "res://tools/tests/tieshan_bubble_interaction.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		await _target_prompts()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _first_order()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _target_prompts() -> void:
	sm.data=sm._defaults()
	sm._active_save_path="user://target-prompts.json"
	sm.data.prologue_done=true
	sm.data.chapter_1_intro="guest_arrived"
	_check(sm.accept_first_order().success,"真实首单接取")
	scene=RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().create_timer(0.3).timeout
	tm.start()
	await get_tree().create_timer(0.5).timeout
	tm.set_process(false)
	var player=get_tree().get_first_node_in_group("player")
	var ui=scene.get_node("UIOverlay")
	player.input_locked=false
	player.set_physics_process(true)
	var initial_idx:int=tm.idx
	for index in tm.steps.size():
		var step:Dictionary=tm.steps[index]
		if step.get("type") not in ["interact","move_to"]: continue
		tm.idx=index
		tm.current_stage=int(step.get("stage",0))
		var target=tm.resolve_target(step.target)
		for prop in ui._buttons:
			player.global_position=prop.global_position
			player.last_valid=player.position
			var nearest=player.nearest_interactable()
			ui._process(0)
			for other in ui._buttons:
				_check(not ui._buttons[other].visible or (other==target and other==nearest),"教学%s/%s只展示目标" % [step.type,step.target])
			if nearest==target and target.display_name!="吧台":
				_check(ui._buttons[target].visible,"当前目标近距显示%s" % step.target)
	# 对白、非交互步骤与无效索引不遗留上一帧按钮。
	for index in [0,-1,tm.steps.size()]:
		tm.idx=index
		ui._process(0)
		_check(ui._buttons.values().all(func(button):return not button.visible),"非交互阶段无E")
	tm.idx=initial_idx
	tm.active=false
	var pot=tm.resolve_target("魔法汤锅")
	player.global_position=pot.global_position
	player.last_valid=player.position
	ui._process(0)
	_check(player.nearest_interactable()==pot and ui._buttons[pot].visible,"教学结束恢复近距按钮")
	tm._cancel_current_run()
	tm.set_process(true)
	scene.queue_free()
	await get_tree().process_frame
