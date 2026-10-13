extends "res://tools/tests/yaya_battle_menu_input.gd"
## BR-01：真实入口、自然胜负与主动结束；仅注入键鼠，不调用结算业务。
var started_at := Time.get_datetime_string_from_system()

func _ready() -> void:
	output = "res://output/br01/flow"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	_run_results.call_deferred()

func _e(down: bool, repeat := false, physical := false) -> void:
	var event := InputEventKey.new()
	if physical: event.physical_keycode = KEY_E
	else: event.keycode = KEY_E
	event.pressed = down
	event.echo = repeat
	get_viewport().push_input(event)
	await get_tree().process_frame

func _run_results() -> void:
	for resolution in [Vector2i(1280,720), Vector2i(1152,648)]:
		DisplayServer.window_set_size(resolution)
		get_viewport().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		var outcomes := ["forfeit"] if OS.get_cmdline_user_args().has("--early-only") else ["victory", "defeat", "forfeit", "opening_forfeit"]
		for outcome in outcomes:
			await _enter_battle()
			if outcome == "opening_forfeit":
				await _e(true)
				await _finish_menu()
			else:
				if not await _until("draft"): break
				await _click(Vector2(640,638))
				if not await _until("player_turn"): break
				await _shot(outcome + "_before")
				if outcome == "forfeit":
					await _click(Vector2(1242,342))
					await _pause(1.35)
					await _e(true)
					await _finish_menu()
				else:
					for i in range(10):
						if battle.state == "result": break
						if outcome == "victory":
							# 最后一击前按住 E，覆盖跨伤害动画的防穿透。
							if battle.enemy_hp <= 2: await _e(true)
							await _attack_gesture()
							await _pause(0.85)
						if battle.state == "result": break
						if outcome == "defeat" and battle.player_hp <= 2: await _e(true)
						await _click(Vector2(1242,342))
						await _pause(4.2)
			_check(battle.state == "result", outcome + "进入真实结算")
			if battle.state != "result": break
			await _result_checks(outcome)
			if failures: break
		if failures: break
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"started_at":started_at,"finished_at":Time.get_datetime_string_from_system(),"display":DisplayServer.get_name(),"user_dir":OS.get_user_data_dir(),"checks":results.size(),"failures":failures,"results":results}, "\t"))
	print("BR01_RESULT_ACCEPTANCE ", results.size(), " checks / ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _finish_menu() -> void:
	await _control_click(battle.battle_menu.gear)
	await _control_click(battle.battle_menu.finish_button)
	await _control_click(battle.battle_menu.confirmation.confirm_button)

func _result_checks(outcome: String) -> void:
	if outcome in ["forfeit", "opening_forfeit"]:
		_check(not battle.result_ready, outcome + "入场演出尚未完成")
		await _e(false)
		await _e(true)
	await _e(true, true)
	await _click(Vector2(640,345))
	_check(get_tree().current_scene == battle, outcome + "入场期间E与鼠标不退出")
	var step: int = battle.enemy_step
	var round_before: int = battle.round_number
	var ap: int = battle.action_point
	var cards: Array = battle.hand_cards.duplicate()
	await _pause(1.6)
	var overlay: Control = battle.board.get_node("Result")
	var art: TextureRect = overlay.get_node("Wordmark")
	var prompt: Control = overlay.get_node("ContinuePrompt")
	_check(battle.result_ready and not battle.result_armed and battle.result_e_held, outcome + "演出完仍需先松E")
	_check(art.texture.resource_path.ends_with("victory_wordmark_v1.png" if outcome == "victory" else "defeat_wordmark_v1.png"), outcome + "胜负原图正确")
	_check(prompt.get_script() == load("res://scripts/ui/components/continue_prompt.gd"), outcome + "直接实例公共继续组件")
	_check(overlay.find_children("*", "Button", true, false).is_empty() and overlay.find_children("*", "Panel", true, false).is_empty() and overlay.find_children("*", "Label", true, false).size() == 2, outcome + "无矩形窗统计再战返回按钮")
	_check(art.texture.get_image().detect_alpha() != Image.ALPHA_NONE and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, outcome + "真实alpha完整等比显示")
	_check(Rect2(Vector2.ZERO,battle.size).encloses(art.get_global_rect()) and Rect2(Vector2.ZERO,battle.size).encloses(prompt.get_global_rect()), outcome + "图案与底部提示完整在屏幕内")
	_check(prompt.position.y == 636 and prompt.size.y == 44, outcome + "沿用餐厅底部位置")
	await _shot(outcome)
	await _e(true, true)
	await _e(true)
	for code in [KEY_ESCAPE,KEY_ENTER,KEY_SPACE,KEY_TAB]: await _key(code)
	await _click(Vector2(1242,342))
	await _click(_role_point(true))
	if not battle.hand_nodes.is_empty(): await _click(_card_point(0))
	await _mouse(Vector2(600,350),true,MOUSE_BUTTON_RIGHT)
	await _mouse(Vector2(600,350),false,MOUSE_BUTTON_RIGHT)
	await _pause(1.5)
	_check(get_tree().current_scene == battle and battle.state == "result" and battle.enemy_step == step and battle.round_number == round_before and battle.action_point == ap and battle.hand_cards == cards, outcome + "长按重复其他键鼠不退出不支付且旧异步停止")
	if outcome == "opening_forfeit": _check(not is_instance_valid(battle.draft), "开场旧计时器不再生成选牌")
	await _e(false)
	_check(battle.result_armed, outcome + "松键后就绪")
	await _e(true,false,outcome == "opening_forfeit")
	await _pause(0.3)
	await _e(false)
	var menu := get_tree().current_scene
	_check(menu.scene_file_path.ends_with("start_screen.tscn") and not get_tree().paused and not menu.battle_button.disabled, outcome + "新按E返回上级且输入恢复")
	await _shot(outcome + "_returned")
