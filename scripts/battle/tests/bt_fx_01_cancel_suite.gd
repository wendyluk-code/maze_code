extends "res://scripts/battle/tests/tutorial_scene_suite.gd"
## 群伤与取消专项：隔离预置第5回合，事务由真实鼠标施法触发。

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/bt_fx_01/%d_group_%s.png" % [root.size.x, label])

func start_case() -> void:
	change_scene_to_file("res://scenes/start_screen.tscn")
	await scene_changed
	await create_timer(0.3).timeout
	var entry: Button = current_scene.battle_button
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = entry.get_global_rect().get_center()
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await scene_changed
	scene = current_scene
	ui = scene.get_child(0)
	await wait_state("draft")
	await click(ui.confirm_button.position + Vector2(120, 28))
	await wait_state("player_turn")
	# 测试前置状态：两母体均1血，下一步仍用原第5回合群伤规则。
	ui.battle.turn = 5
	ui.battle.step = 0
	ui.battle.hand = ["yaya_magic_wind"]
	ui.battle.characters.yaya.mana = 4
	for id in ["slime_a", "slime_b"]: ui.battle.characters[id].hp = 1
	ui._sync()
	ui._rebuild_hand()
	await select_card("yaya_magic_wind")
	await click(ui.role_nodes.slime_a.position + Vector2(58, 35))
	check(ui.battle.ap == 1 and ui.battle.step == 1 and ui.pending_splits.size() == 2, "群伤一次提交两母体分裂，仅支付一次")

func wait_phase(phase: String) -> void:
	var until := Time.get_ticks_msec() + 5000
	while ui.split_phase != phase and Time.get_ticks_msec() < until: await process_frame
	check(ui.split_phase == phase, "等待分裂阶段 " + phase)

func menu_confirm(action: String) -> void:
	await click(ui.battle_menu.gear.position + Vector2(24, 24))
	var button: Control = ui.battle_menu.restart_button if action == "restart" else ui.battle_menu.finish_button
	await click(ui.board.get_global_transform_with_canvas().affine_inverse() * button.get_global_rect().get_center())
	var accept: Control = ui.battle_menu.confirmation.confirm_button
	await click(ui.board.get_global_transform_with_canvas().affine_inverse() * accept.get_global_rect().get_center())

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/bt_fx_01")
	root.size = Vector2i(1152, 648) if OS.get_cmdline_user_args().has("small") else Vector2i(1280, 720)
	for phase in ["waiting", "dissolving", "separating"]:
		for action in ["restart", "finish"]:
			await start_case()
			if phase != "waiting": await wait_phase(phase)
			await shot(phase + "_before_" + action)
			var old_ui := ui
			var old_scene := scene
			await menu_confirm(action)
			if action == "restart":
				scene = current_scene
				ui = scene.get_child(0)
				await wait_state("draft")
				check(not is_instance_valid(old_ui) and not is_instance_valid(old_scene) and ui.battle.turn == 0 and ui.pending_splits.is_empty(), "重开释放旧演出，无旧状态侵入 " + phase)
			else:
				await wait_state("result")
				check(ui.pending_splits.is_empty() and not ui.split_tween and ui.fx.dissolves.is_empty(), "结束立即杀分裂Tween并清理 " + phase)
				var snapshot: Dictionary = ui.battle.duplicate(true)
				await create_timer(1.8).timeout
				check(ui.result_ready and ui.battle == snapshot, "结算不被旧异步推进 " + phase)
				for down in [false, true, false]:
					var key := InputEventKey.new()
					key.keycode = KEY_E
					key.pressed = down
					Input.parse_input_event(key)
					await process_frame
				await create_timer(0.7).timeout
				check(current_scene.scene_file_path == "res://scenes/start_screen.tscn" and not paused, "失败E返回与输入恢复 " + phase)
	# 双母体完整分离后的四角色位置、复活和再分裂。
	await start_case()
	await wait_phase("dissolving")
	await create_timer(0.12).timeout
	await shot("dissolving")
	await wait_phase("separating")
	await create_timer(0.16).timeout
	await shot("separating")
	await wait_state("player_turn")
	check(ui.battle.ap == 1 and ui.battle.step == 1, "群伤动画后AP与步骤只结算一次")
	for id in ["slime_a1", "slime_a2", "slime_b1", "slime_b2"]:
		check(ui.role_nodes[id].visible and ui.role_nodes[id].position == ui._prepare_position(id), "四子体终态固定槽位 " + id)
	await shot("settled")
	# 原规则直接驱动等价复活样例，不调整任何生产规则。
	for id in ["slime_a1", "slime_a2"]: Rules.damage(ui.battle, id, 99, "spell")
	ui._sync()
	check(ui.battle.characters.slime_a.revive == 3, "两子体阵亡才启动原3回合倒计时")
	for i in range(3): Rules.begin_turn(ui.battle, "enemy")
	ui._sync()
	check(ui.battle.characters.slime_a.alive and ui.role_nodes.slime_a.get_node("Portrait").visible and not ui.role_nodes.slime_a1.visible, "原复活重新显母体、隐藏退役子体")
	ui.battle.events = []
	Rules.damage(ui.battle, "slime_a", 99, "spell")
	ui.state = "resolving"
	ui._stage_splits(ui.battle.events)
	ui._sync()
	await ui._show_events(ui.battle.events)
	check(ui.pending_splits.is_empty() and ui.role_nodes.slime_a1.visible and ui.role_nodes.slime_a2.visible, "复活后再次分裂演出恰好一次")
	var report := FileAccess.open("res://output/bt_fx_01/cancel_%d.json" % root.size.x, FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "user_data_dir": OS.get_user_data_dir()}, "\t"))
	report.close()
	print("BT_FX_CANCEL checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

