extends "res://tools/tests/hud_currency_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	_check(sm.gold_balance() == 100 and sm.is_gold_display_unlocked(), "独立Godot进程自动载入上一运行的默认存档并恢复资格")
	_check(sm.load_save_slot("user://saves/hud-flow-old.json").success and sm.gold_balance() == 0 and sm.is_gold_display_unlocked() and not sm.data.claimed_chests.is_empty(), "独立进程选择上一运行的零余额存档后恢复获币资格")
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		if failures: break
		DisplayServer.window_set_size(resolution)
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_completed()
		_check(sm.record_maze_location("maze_entry", Roads.SPAWN).success, "建立合法迷宫存档")
		_check(sm.claim_exploration_chest(Chests.all()[0].id, Vector2(725,369)).success, "换档测试真实取得金币")
		scene = load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(scene)
		get_tree().current_scene = scene
		maze = scene
		await _settle()
		await _swap_live(maze.gold_counter, true)
		await _shot("maze_live_slot_restored")
		await _close_scene()
		maze = null
		_check(sm.record_maze_location("restaurant", Roads.SPAWN).success, "换档后恢复餐厅区域")
		await _open_scene()
		await _settle()
		var hud = get_tree().get_first_node_in_group("restaurant_hud")
		await _swap_live(hud.gold_counter)
		await _shot("restaurant_live_slot_restored")
		await _close_scene()
		await _first_settlement()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"display":DisplayServer.get_name()}, "\t"))
	get_tree().quit(1 if failures else 0)

func _swap_live(counter, always_visible: bool = false) -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var prior := "user://saves/hud-live.json"
	_check(sm._write_atomic(prior, sm.data), "保存合法获币档")
	_check(sm.create_new_game().success, "同场景真实新建档")
	await get_tree().create_timer(0.25).timeout
	_check(counter.visible == always_visible and counter.value_label.text == "0" and not sm.is_gold_display_unlocked(), "同一场景换新档数值归零：迷宫常显、餐厅隐藏且资格不串档")
	_check(sm.load_save_slot(prior).success, "同场景真实载入获币档")
	await get_tree().create_timer(0.25).timeout
	_check(counter.is_visible_in_tree() and counter.value_label.text == "100", "同一场景切回后同步恢复金币资格与数值")

func _first_settlement() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://hud-first-order.json"
	_check(sm.save(), "首单专项初始化")
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success, "真实接单取料烹饪建立待上菜状态")
	await _open_scene()
	await _settle()
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(not hud.reputation_counter.visible, "真实烹饪完成未上菜隐藏声望图标和数字")
	var target = scene.get_node("InteractPoints/BarCounter")
	var player = scene.get_node("Player")
	player.global_position = _stand(target)
	player.last_valid = player.global_position
	await get_tree().physics_frame
	_check(await _wait_until(func(): return tm.steps[tm.idx].get("type", "") == "interact" and tm.current_stage == 6, 120), "站位到达后等待真实上菜交互步骤就绪")
	var path: String = sm.active_save_path()
	sm._active_save_path = ""
	await _send_key(KEY_E)
	await _settle()
	_check(not sm.has_first_order_settlement() and not hud.reputation_counter.visible, "真实E上菜保存失败不提前解锁声望")
	sm._active_save_path = path
	await _send_key(KEY_E)
	await _settle()
	var guide = scene.get_node("UIOverlay/TutorialGuide")
	_check(sm.has_first_order_settlement() and hud.reputation_counter.is_visible_in_tree() and hud.reputation_label.text == "60" and guide.dialog.visible, "真实E上菜成功在对白期间首次显示声望图标和60")
	_counter(hud.reputation_counter, 60, "reputation.png")
	var tracker = get_tree().get_first_node_in_group("order_tracking")
	await _measure_mask(guide.dim, [tracker._task_button, hud.reputation_counter])
	await _shot("reputation_first_settlement")
	tracker.collapse_details()
	guide.dialog._shown = 0.0
	await _click(tracker._task_button)
	_check(not tracker._expanded and guide.dialog.visible, "对白蒙层拦截背后任务点击")
	await _close_scene()
	sm.load_data()
	await _open_scene()
	await _settle()
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	_check(hud.reputation_counter.is_visible_in_tree() and hud.reputation_label.text == "60", "首单成功后读档恢复声望图标与数值")
	await _close_scene()

func _measure_mask(mask: CanvasItem, controls: Array) -> void:
	await RenderingServer.frame_post_draw
	var dark := get_viewport().get_texture().get_image()
	var original_alpha := mask.self_modulate.a
	mask.self_modulate.a = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var light := get_viewport().get_texture().get_image()
	mask.self_modulate.a = original_alpha
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for control in controls:
		var rect: Rect2i = Rect2i(control.get_global_rect())
		var sum := 0.0
		var samples := 0
		for y in range(rect.position.y, rect.end.y, 3):
			for x in range(rect.position.x, rect.end.x, 3):
				sum += light.get_pixel(x,y).get_luminance() - dark.get_pixel(x,y).get_luminance()
				samples += 1
		_check(sum / maxf(samples,1) > 0.025, "真实渲染像素证明蒙层压暗：" + str(control.name), {"mean_luminance_delta":sum / maxf(samples,1)})
