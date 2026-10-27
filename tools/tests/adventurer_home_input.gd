extends "res://tools/tests/chapter_ending_input.gd"
const HomePage := preload("res://scripts/ui/adventurer_home.gd")
const BackButton := preload("res://scripts/ui/components/sprout_back_button.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档目录")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await get_tree().process_frame
			await _walkthrough()
			if failures > 0: break
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name()}, "\t"))
	print("ADVENTURER_HOME ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _walkthrough() -> void:
	_seed()
	for checkpoint in ["party", "home", "maze", "title"]:
		_check(sm.advance_chapter_1_outro(checkpoint).success, "完成第一章前置：" + checkpoint)
	await _open_scene()
	var player = scene.get_node("Player")
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
	var ui = get_tree().get_first_node_in_group("ui_layer")
	var near: Vector2 = _stand(target)
	player.position = near
	player.last_valid = near
	await get_tree().physics_frame
	await get_tree().process_frame
	var entry: Control = ui._buttons[target]
	_check(entry.is_visible_in_tree() and player.nearest_interactable() == target, "靠近冒险者之家显示原入口按钮")
	var baseline: Dictionary = sm.data.duplicate(true)
	var saved := FileAccess.get_file_as_bytes(sm._active_save_path)
	await _click(entry)
	_check(not hud.confirmation.visible, "鼠标入口直接进入，不弹二次确认")
	var echo := InputEventKey.new()
	echo.keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	get_viewport().push_input(echo)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("adventurer_home").size() == 1, "长按E重复事件不叠加页面")
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(is_instance_valid(page), "一次点击进入冒险者之家页面")
	if not is_instance_valid(page): return
	_check(not hud.confirmation.visible and not hud.toast_label.visible, "直接进入且不提示未开放")
	_check(page.get_node("Page/Background").texture.resource_path == "res://assets/maps/adventurer_home_collection.png", "使用屋檐地板栅栏背景与独立木牌页签")
	_check(page.back_button is SproutButton and page.back_button.get_script() == BackButton, "返回按钮复用组件库基础按钮")
	var bounds: Rect2 = page.back_button.get_global_rect()
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	_check(bounds.size == Vector2(56, 56) and bounds.position == Vector2(24, 24), "圆形返回按钮位于左上角并保留24像素边距", {"bounds": str(bounds), "viewport": str(viewport)})
	_check(page.back_button._has_point(Vector2(28, 28)) and not page.back_button._has_point(Vector2.ZERO), "返回按钮采用圆形命中区域")
	await RenderingServer.frame_post_draw
	await _shot("home_page")
	HomePage.open_page(get_tree())
	_check(get_tree().get_nodes_in_group("adventurer_home").size() == 1, "重复打开不叠加页面")
	await _key_held(KEY_D, 0.2)
	await _send_key(KEY_E)
	_check(player.position == near and not hud.confirmation.visible, "页面打开时餐厅人物不移动且交互不穿透")
	# 测试鼠标点透：屏幕上原入口所在点现在属于页面背景。
	await _click(entry)
	_check(not hud.confirmation.visible, "页面背景阻挡对餐厅入口的鼠标点击")
	# 新页面在此坐标可能有可点击角色；合法打开的卡牌层需先关闭，再测试页面返回。
	if page.cards_modal.visible:
		await _send_key(KEY_ESCAPE)
	await _click(page.back_button)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("adventurer_home").is_empty() and get_tree().current_scene == scene, "点击返回回到同一餐厅实例")
	_check(player.position == near and not player.input_locked and player.can_process(), "返回保持原站位并恢复输入")
	_check(sm.data == baseline and FileAccess.get_file_as_bytes(sm._active_save_path) == saved, "往返不改变经营状态或存档")
	await _shot("home_returned")
	# 再次以键盘一次E打开；Esc只关闭页面。
	await _send_key(KEY_E)
	_check(is_instance_valid(get_tree().get_first_node_in_group("adventurer_home")) and not hud.confirmation.visible, "一次E直接重新进入，无二次确认")
	await _send_key(KEY_ESCAPE)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("adventurer_home").is_empty() and not hud.confirmation.visible and player.can_process(), "Esc返回且无确认或输入锁残留")
	var start_position: Vector2 = player.position
	# 在入口附近选择真实可走方向，验证返回后移动确实恢复。
	for direction in [{"key": KEY_D, "delta": Vector2(20, 0)}, {"key": KEY_A, "delta": Vector2(-20, 0)}, {"key": KEY_S, "delta": Vector2(0, 20)}, {"key": KEY_W, "delta": Vector2(0, -20)}]:
		if player.is_walkable_footprint(start_position + direction.delta):
			await _key_held(direction.key, 0.06)
			break
	_check(player.position.distance_to(start_position) > 1, "返回餐厅后实际方向键移动成功")
	player.position = Vector2(1000, 850)
	player.last_valid = player.position
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not entry.visible, "离开入口范围仍隐藏原交互按钮")
	await _close_scene()

func _key_held(key: Key, seconds: float) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(seconds).timeout
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	Input.parse_input_event(event)
	await get_tree().physics_frame
