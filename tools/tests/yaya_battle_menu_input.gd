extends "res://tools/tests/yaya_battle_input.gd"
## 真实菜单鼠标/键盘流程，覆盖暂停、取消、重开及主动失败返回。

func _ready() -> void:
	output = "res://output/battle_corner_menu"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	_menu_run.call_deferred()

func _control_click(control: Control) -> void:
	var center := control.get_global_transform_with_canvas() * (control.size * 0.5)
	await _click(battle.board.get_global_transform_with_canvas().affine_inverse() * center)

func _enter_battle() -> void:
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	await _pause(0.4)
	var entry: Button = get_tree().current_scene.battle_button
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = entry.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event)
		await get_tree().process_frame
	await _pause(0.1)
	battle = get_tree().current_scene
	_check(battle.scene_file_path.ends_with("yaya_battle_demo.tscn"), "从上一级真实入口进入战斗")

func _menu_run() -> void:
	for resolution in [Vector2i(1280,720), Vector2i(1152,648)]:
		DisplayServer.window_set_size(resolution)
		get_viewport().size = resolution
		suffix = "_%dx%d" % [resolution.x, resolution.y]
		await _enter_battle()
		if not await _until("draft"): break
		await _control_click(battle.battle_menu.gear)
		_check(get_tree().paused and battle.battle_menu.dropdown.visible, "起手阶段齿轮可打开下拉菜单并暂停")
		await _key(KEY_ESCAPE)
		_check(not get_tree().paused and battle.state == "draft", "Esc关闭菜单恢复起手输入")
		await _click(Vector2(640,638))
		if not await _until("player_turn"): break
		await _move(Vector2(1000,450))
		await _pause()
		_check(battle.hand_nodes.all(func(card): return not card.get_node("Glow").visible), "未选手牌不显示任何选中框")
		for i in range(3):
			await _move(_card_point(i))
			await _pause()
			await _click(_card_point(i))
			_check(battle.hand_expanded and battle.hand_nodes.all(func(card): return not card.get_node("Glow").visible), "连续点击仅放大卡牌、不显示选框")
		await _move(_card_point(3))
		_check(battle.hand_nodes.all(func(card): return not card.get_node("Glow").visible), "悬停其他牌同样没有选框")
		await _shot("single_selection")
		await _key(KEY_ESCAPE)
		await _move(Vector2(1000,450))
		await _pause()
		_check(battle.hand_nodes.all(func(card): return not card.get_node("Glow").visible), "取消选牌后所有选中框消失")
		_check(battle.hand_nodes.all(func(card): return card.position.x >= 850 and card.position.y >= 614 and card.position.x + card.size.x <= 1260), "我方手牌收在右下角且横向完整可操作")
		for i in range(5):
			var enemy: Control = battle.enemy_backs.get_child(i)
			var ally: Control = battle.hand_nodes[i]
			_check(is_equal_approx(enemy.position.x, ally.position.x) and is_equal_approx(enemy.position.y + ally.position.y + ally.size.y,720), "敌方手牌位于右上并与我方镜像")
		await _shot("corner_board")
		await _control_click(battle.battle_menu.gear)
		await _shot("dropdown")
		await _control_click(battle.battle_menu.restart_button)
		var modal: Control = battle.battle_menu.confirmation
		_check(modal.visible and modal._cancel_button.has_focus(), "重开弹出二次确认且默认聚焦取消")
		await _shot("restart_confirm")
		var old_id := battle.get_instance_id()
		var hp: int = battle.player_hp
		await _key(KEY_ENTER)
		_check(not get_tree().paused and battle.get_instance_id() == old_id and not modal.visible, "默认Enter取消重开，原局恢复")
		await _control_click(battle.battle_menu.gear)
		await _control_click(battle.battle_menu.finish_button)
		_check(modal.visible and battle.state == "player_turn", "结束仅打开确认，不提前结算")
		await _shot("finish_confirm")
		for i in range(5): await _key(KEY_TAB)
		_check([modal._cancel_button, modal._confirm_button, modal._close_button].has(get_viewport().gui_get_focus_owner()), "确认框焦点循环不进入底层控件")
		await _click(Vector2(1242,342))
		_check(battle.round_number == 1 and battle.player_hp == hp and modal.visible, "弹窗遮罩阻止回合按钮穿透")
		await _key(KEY_ESCAPE)
		_check(not get_tree().paused and not modal.visible and battle.player_hp == hp, "Esc取消结束不扣血不结算")
		await _control_click(battle.battle_menu.gear)
		await _control_click(battle.battle_menu.finish_button)
		await _control_click(modal._cancel_button)
		_check(not get_tree().paused and not modal.visible, "取消按钮恢复战斗")
		# 先真实支付一张牌，再重开，确认不会只重置界面。
		await _choose("小小掌勺人")
		await _click(_role_point(true))
		if not await _until("player_turn"): break
		_check(battle.discard.size() == 1 and battle.action_point == 1, "重开前已产生真实牌局进度")
		await _control_click(battle.battle_menu.gear)
		await _control_click(battle.battle_menu.restart_button)
		await _control_click(modal._confirm_button)
		await _pause(0.1)
		battle = get_tree().current_scene
		_check(battle.get_instance_id() != old_id and not get_tree().paused, "确认重开创建新战斗且解除暂停")
		if not await _until("draft"): break
		_check(battle.discard.is_empty() and battle.player_hp == 10 and battle.enemy_hp == 5 and battle.action_point == 2 and battle.round_number == 0 and battle.hand_cards.size() == 5, "重开恢复教学10/5生命、行动、弃牌、回合并重新选牌")
		await _click(Vector2(640,638))
		if not await _until("player_turn"): break
		await _click(Vector2(1242,342))
		await _pause(1.35)
		await _control_click(battle.battle_menu.gear)
		var enemy_before: int = battle.enemy_step
		var form_before: String = battle.enemy_form
		await _pause(1.3)
		_check(get_tree().paused and battle.enemy_step == enemy_before and battle.enemy_form == form_before, "敌方出牌期间菜单冻结动画和业务结算")
		await _key(KEY_ESCAPE)
		if not await _until("player_turn"): break
		_check(battle.enemy_form == "小小掌勺人", "取消菜单后敌方动作续播且交还回合")
		await _click(Vector2(1242,342))
		await _pause(1.35)
		await _control_click(battle.battle_menu.gear)
		await _control_click(battle.battle_menu.finish_button)
		await _control_click(battle.battle_menu.confirmation._confirm_button)
		_check(battle.state == "result" and battle.player_hp == 0 and not get_tree().paused, "敌方行动中确认结束立即锁定失败结果")
		var step_at_end: int = battle.enemy_step
		await _pause(1.25)
		_check(battle.board.has_node("Result") and battle.state == "result" and battle.enemy_step == step_at_end, "失败结算可见且旧异步动作未继续")
		await _shot("forfeit_result")
		await _pause(1.8)
		_check(get_tree().current_scene == battle and battle.state == "result", "演出完毕不会自动返回")
		await _fresh_continue()
		await _pause(0.3)
		_check(get_tree().current_scene.scene_file_path.ends_with("start_screen.tscn") and not get_tree().paused, "失败动画播完新按E返回上一级且输入恢复")
		await _shot("returned")
		# 从开场计时器期间结束，覆盖与动画等待不同的异步路径。
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
		await _enter_battle()
		await _control_click(battle.battle_menu.gear)
		await _control_click(battle.battle_menu.finish_button)
		await _control_click(battle.battle_menu.confirmation._confirm_button)
		await _pause(1.3)
		_check(battle.state == "result" and not is_instance_valid(battle.draft), "开场结束后旧抽签计时器不再进入选牌")
		await _pause(1.8)
		_check(get_tree().current_scene == battle and battle.state == "result", "演出完毕不会自动返回")
		await _fresh_continue()
		await _pause(0.3)
		_check(get_tree().current_scene.scene_file_path.ends_with("start_screen.tscn"), "开场结束同样播失败后新按E返回")
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
		await get_tree().process_frame
		if failures: break
	var report := FileAccess.open(output + "/menu-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": results.size(), "failures": failures, "results": results}, "\t"))
	print("YAYA_MENU_ACCEPTANCE ", results.size(), " checks / ", failures, " failures")
	get_tree().quit(1 if failures else 0)
