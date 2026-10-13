extends SceneTree
## 旧演示兼容：实际输入、两角色布局及我方后手翻牌，不调用出牌事务。
var ui: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)

func wait_state(value: String) -> void:
	var until := Time.get_ticks_msec() + 15000
	while ui.state != value and Time.get_ticks_msec() < until: await process_frame
	check(ui.state == value, "旧演示状态 " + value)

func click(point: Vector2) -> void:
	var global: Vector2 = ui.board.get_global_transform_with_canvas() * point
	var motion := InputEventMouseMotion.new()
	motion.position = global
	Input.parse_input_event(motion)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = global
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await create_timer(0.25).timeout

func drag(point: Vector2, destination: Vector2) -> void:
	var start: Vector2 = ui.board.get_global_transform_with_canvas() * point
	var end: Vector2 = ui.board.get_global_transform_with_canvas() * destination
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = start
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.relative = end - start
	Input.parse_input_event(motion)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = end
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await create_timer(0.3).timeout

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/bt_ui_02/demo_%s.png" % label) == OK, "旧演示截图 " + label)

func run() -> void:
	root.size = Vector2i(1280, 720)
	ui = load("res://scenes/battle/yaya_battle_demo.tscn").instantiate()
	ui.tutorial_battle = false
	ui.initiative_override = -1
	root.add_child(ui)
	current_scene = ui
	await create_timer(1.5).timeout
	check(not ui.initiative_player_first, "保留我方后手抽签结果")
	await capture("player_second")
	await wait_state("draft")
	check(is_equal_approx(ui.player_field.position.x + ui.enemy_field.position.x + ui.ROLE_SIZE.x, 1320), "旧演示双方两角色左右对称")
	await click(ui.confirm_button.position + Vector2(120, 28))
	await wait_state("player_turn")
	await capture("two_roles")
	await click(ui.hand_nodes[0].position + Vector2(16, 25))
	check(ui.selected == 0 and not ui.hand_expanded and ui.preview.visible, "旧演示单牌查看")
	await capture("single_card")
	await click(Vector2(300, 560))
	check(ui.selected == -1 and not ui.preview.visible, "旧演示空白取消")
	var before: int = ui.action_point
	var at: Vector2 = ui.player_field.position + Vector2(84, 100)
	await drag(at, at + Vector2(0, 20))
	check(not ui.attack_selected and ui.action_point == before, "旧演示取消出击")
	await drag(at, at + Vector2(0, -80))
	await wait_state("player_turn")
	check(ui.player_in_battle and ui.player_field.position.is_equal_approx(ui._role_position(true, true)), "旧演示出击落入中央")
	check(ui.action_point == before - 1, "旧演示出击仅支付一次")
	await capture("central_attack")
	await click(ui.end_button.position + Vector2(35, 49))
	await wait_state("player_turn")
	check(ui.player_field.position.is_equal_approx(ui._role_position(true, ui.player_in_battle)), "旧演示回合结束归位")
	var file := FileAccess.open("res://output/bt_ui_02/demo_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "user_data_dir": OS.get_user_data_dir()}, "\t"))
	file.close()
	print("BT_UI_02_DEMO checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
