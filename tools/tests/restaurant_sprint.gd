extends "res://tools/tests/ch2_entry_state.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	evidence=_arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	_completed()
	sm.data["ch2_exploration_guide"]={"revision":2,"step":"done","seen":{"customer_arrival":true},"banked":{}}
	await _open_scene()
	tm._cancel_current_run()
	var p=scene.get_node("Player")
	p.input_locked=false
	p.set_physics_process(true)
	var origin: Vector2=p.walk_zone.get_spawn_point(p.collision_radius_world())
	var before: Dictionary=sm.data.duplicate(true)
	Input.action_press("ui_right")
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(is_equal_approx(p.velocity.length(),260.0),"普通行走260")
	_shift(true)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(is_equal_approx(p.velocity.length(),390.0),"按住Shift速度390")
	await get_tree().create_timer(0.15).timeout
	_check(p.get_node("SprintWind").strength>0.5,"加速移动显示风线")
	await _shot("restaurant_shift")
	_shift(false)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(is_equal_approx(p.velocity.length(),260.0),"松Shift恢复260")
	await get_tree().create_timer(0.2).timeout
	_check(p.get_node("SprintWind").strength==0.0,"松Shift风线淡出")
	_shift(true)
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	hud._lock_player()
	var locked_position: Vector2=p.position
	await get_tree().create_timer(0.1).timeout
	_check(p.position==locked_position and not p.is_physics_processing(),"剧情锁定时Shift不能移动")
	hud._unlock_player()
	p.set_physics_process(false)
	await get_tree().create_timer(0.1).timeout
	_check(p.position==locked_position,"弹窗停物理帧时不能加速移动")
	p.set_physics_process(true)
	p.global_position=origin
	p.last_valid=origin
	for direction in ["ui_right","ui_down","ui_left","ui_up"]:
		Input.action_release("ui_right")
		Input.action_press(direction)
		for i in 30:
			await get_tree().physics_frame
			_check(p.is_walkable_footprint(p.global_position),"加速不穿越不可走区域")
		Input.action_release(direction)
	_shift(false)
	_check(sm.data==before,"加速不修改经营数值或存档状态")
	await _close_scene()
	var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
func _shift(pressed: bool) -> void:
	var event=InputEventKey.new()
	event.keycode=KEY_SHIFT
	event.physical_keycode=KEY_SHIFT
	event.pressed=pressed
	Input.parse_input_event(event)
