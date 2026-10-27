extends "res://tools/tests/combat_02_flow.gd"
## 在主目录当前真实迷宫运行；必须沿用既有验收运行器的隔离用户目录。

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "正式存档隔离")
	_check(DisplayServer.get_name() != "headless", "必须使用实际渲染窗口")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _new_scene()
			await _hud_cases()
			if not _prepare_region_fixture():
				await _close_scene()
				continue
			maze.travel_region("fenshui", preload("res://data/maze/fenshui_roads.gd").SPAWN)
			await get_tree().create_timer(1.2).timeout
			maze = get_tree().current_scene
			_check(maze.region_id == "fenshui", "实际转场进入分水庭")
			if maze.region_id != "fenshui":
				await _capture_image("fenshui_transition_failed")
				await _close_scene()
				continue
			await _hud_cases()
			await _close_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()}, "\t"))
	print("MAP_HUD_SCENE ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _prepare_region_fixture() -> bool:
	# 本票不验战斗脱战；仅在两组HUD验收之间重置隔离夹具的瞬时战斗状态。
	# 暂停原区模拟后清除portal_combat_locked实际检查的每个条件，仍走生产切区。
	maze.capture_flow.set_process(false)
	maze.player.clear_combat_input()
	var combat: Dictionary = sm.data[Run.KEY].combat
	var modes: Dictionary = {}
	for id in combat.actors:
		modes[id] = combat.actors[id].mode
	var before := {"locked": Run.portal_combat_locked(sm), "modes": modes,
		"axe_pending": combat.get("axe_pending", false), "action_left": combat.get("action_left", 0.0),
		"shots": combat.get("shots", []).size(), "enemy_shots": combat.get("enemy_shots", []).size()}
	combat.axe_pending = false
	combat.action_left = 0.0
	combat.shots = []
	combat.enemy_shots = []
	for actor in combat.actors.values(): actor.mode = "idle"
	var ready: bool = not Run.portal_combat_locked(sm)
	_check(ready, "隔离夹具已清除战斗锁条件，允许真实切区", before)
	return ready

func _hud_cases() -> void:
	var flow = maze.capture_flow
	var stamina = maze._ui_root.get_node("StaminaCounter")
	var nodes: Array = [flow.skill_bar, flow.controls_hint, stamina]
	flow.window_focused = true
	# 输入经视口同步分发；先等待转场及布局稳定。
	await get_tree().process_frame
	for disabled in [false, true]:
		flow.set_process(not disabled)
		for cycle in 3:
			# 禁处理样例保留混合显隐；正常样例由真实逐帧逻辑提供状态。
			if disabled:
				flow.skill_bar.visible = cycle != 1
				flow.controls_hint.visible = cycle != 2
			var original: Array = []
			for node in nodes: original.append(node.visible)
			var physics_before: bool = maze.player.is_physics_processing()
			_mouse_now(maze.map_ui.mini_button)
			_check(maze.map_ui.expanded, "真实点击展开地图")
			if not maze.map_ui.expanded:
				await _capture_image("map_hud_open_failed_" + maze.region_id)
				return
			var run_before: Dictionary = Run.snapshot(sm).duplicate(true)
			var map_before: Dictionary = sm.departure_state().map.duplicate(true)
			var save_before := FileAccess.get_file_as_bytes(sm._active_save_path)
			var resources: Array = maze.map_ui.visible_resources.duplicate(true)
			var position_before: Vector2 = maze.player.position
			Input.action_press("ui_left")
			await get_tree().create_timer(0.25).timeout
			Input.action_release("ui_left")
			for node in nodes: _check(not node.is_visible_in_tree(), "全图期间目标控件隐藏，禁处理=%s" % disabled)
			_check(not flow.party_food.is_visible_in_tree() and not stamina.info.is_visible_in_tree(), "饱腹度和感叹号随体力隐藏")
			_check(maze.player.position == position_before, "地图期间移动输入无效")
			_check(Run.snapshot(sm) == run_before and sm.departure_state().map == map_before, "展开期间探索数值与地图状态不变")
			_check(FileAccess.get_file_as_bytes(sm._active_save_path) == save_before, "展开期间隔离存档字节不变")
			_check(maze.map_ui.visible_resources == resources and maze.map_ui.full_view.is_visible_in_tree(), "地图内容和资源路标保留")
			await _capture_image("map_hud_open_%s_%s_%d" % [maze.region_id, disabled, cycle])
			if cycle % 2 == 0:
				_mouse_now(maze.map_ui.close_button)
			else:
				var event := InputEventKey.new()
				event.keycode = KEY_ESCAPE
				event.pressed = true
				get_viewport().push_input(event, true)
				event = event.duplicate()
				event.pressed = false
				get_viewport().push_input(event, true)
			_check(not maze.map_ui.expanded and not maze.player.input_locked, "关闭按钮/Esc恢复输入锁")
			_check(maze.player.is_physics_processing() == physics_before, "恢复原物理处理状态")
			for i in nodes.size(): _check(nodes[i].visible == original[i], "关闭同步恢复原显隐")
			_check(Run.snapshot(sm) == run_before, "关闭事件不改探索数值")
			await _capture_image("map_hud_closed_%s_%s_%d" % [maze.region_id, disabled, cycle])
	# 禁用战斗计时测量真实移动恢复，避免怪物事务干扰输入验收。
	flow.set_process(false)
	maze.player.position = Vector2(790,326) if maze.region_id == "maze_entry" else preload("res://data/maze/fenshui_roads.gd").SPAWN
	var origin: Vector2 = maze.player.position
	Input.action_press("ui_right")
	await get_tree().create_timer(0.15).timeout
	Input.action_release("ui_right")
	_check(maze.player.position.distance_to(origin) > 1, "关闭后真实方向输入恢复移动")

func _mouse_now(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
