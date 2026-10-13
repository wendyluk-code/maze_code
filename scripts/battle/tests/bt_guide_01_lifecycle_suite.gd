extends "res://scripts/battle/tests/tutorial_scene_suite.gd"
## 说明阶段取消、重开和退出；旧对白不得在新场景继续生效。

func menu_action(action: String) -> void:
	await click(ui.battle_menu.gear.position + Vector2(24, 24))
	var button: Control = ui.battle_menu.restart_button if action == "restart" else ui.battle_menu.finish_button
	await click(ui.board.get_global_transform_with_canvas().affine_inverse() * button.get_global_rect().get_center())
	await click(ui.board.get_global_transform_with_canvas().affine_inverse() * ui.battle_menu.confirmation.confirm_button.get_global_rect().get_center())

func run() -> void:
	started = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute("res://output/bt_guide_01")
	root.size = Vector2i(1152, 648) if OS.get_cmdline_user_args().has("small") else Vector2i(1280, 720)
	change_scene_to_file("res://scenes/battle/yaya_battle_demo.tscn")
	await scene_changed
	scene = current_scene
	ui = scene.get_child(0)
	await wait_state("draft")
	await click(ui.confirm_button.position + Vector2(120, 28))
	await wait_state("guide_explain")
	var old_guide: Control = ui.guide
	var old_ui := ui
	await guide_key(true) # 在说明打字期间保持E，再重开。
	await menu_action("restart")
	scene = current_scene
	ui = scene.get_child(0)
	await wait_state("draft")
	check(not is_instance_valid(old_guide) and not is_instance_valid(old_ui), "重开释放旧对白与遮罩")
	check(ui.battle.turn == 0 and ui.battle.step == 0 and not ui.guide.visible and not paused, "重开从起手开始，无输入锁残留")
	await click(ui.confirm_button.position + Vector2(120, 28))
	await wait_state("guide_explain")
	await create_timer(0.2).timeout
	check(ui.guide.sentence == 0 and ui.battle.step == 0, "旧E长按不能跨场景推进新说明")
	await guide_key(true, true)
	check(ui.guide.sentence == 0, "新说明忽略旧键重复")
	await guide_key(false)
	await guide_key(true)
	await guide_key(false)
	check(ui.guide.dialog._shown == ui.guide.sentences[0][0].length(), "松开后新按可补全新说明")
	await menu_action("finish")
	await wait_state("result")
	check(not ui.guide.visible and not ui.guide.explaining and ui.guide.cutouts.is_empty(), "说明中退出清除对白、孔洞和指针")
	var snapshot: Dictionary = ui.battle.duplicate(true)
	await create_timer(2.0).timeout
	check(ui.result_ready and ui.battle == snapshot and not paused, "结算不被旧教学回调覆盖")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/bt_guide_01/%d_explanation_exit.png" % root.size.x)
	for down in [false, true, false]: await guide_key(down)
	await create_timer(0.8).timeout
	check(current_scene.scene_file_path == "res://scenes/start_screen.tscn" and not paused, "失败按E返回并恢复开始页输入")
	var entry: Button = current_scene.battle_button
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = entry.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await scene_changed
	scene = current_scene
	ui = scene.get_child(0)
	await wait_state("draft")
	check(ui.battle.turn == 0 and not ui.guide.visible, "返回后鼠标重新进入起手成功")
	var file := FileAccess.open("res://output/bt_guide_01/lifecycle_%d.json" % root.size.x, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "user_data_dir": OS.get_user_data_dir()}, "\t"))
	file.close()
	print("BT_GUIDE_LIFECYCLE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
