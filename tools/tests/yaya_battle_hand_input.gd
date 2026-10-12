extends "res://tools/tests/yaya_battle_input.gd"
## 使用真实输入与自然抽牌，检查生命配置和展开/收起手牌。

func _ready() -> void:
	output = "res://output/battle_hand_expand"
	DirAccess.make_dir_recursive_absolute(output)
	_hand_run.call_deferred()

func _hand_run() -> void:
	for config in [[false, 0, 0, 30, 30], [true, 0, 0, 10, 5], [false, 15, 8, 15, 8]]:
		battle = Battle.instantiate()
		battle.tutorial_battle = config[0]
		battle.player_starting_health = config[1]
		battle.enemy_starting_health = config[2]
		add_child(battle)
		_check(battle.player_hp == config[3] and battle.enemy_hp == config[4], "普通/教学/剧情配置初始化正确 " + str(config))
		_check(battle.player_hud.get_children().filter(func(node): return node is Label).size() == 1 and battle.enemy_hud.get_children().filter(func(node): return node is Label).size() == 1, "双方头像仅显示当前生命数字")
		battle.queue_free()
		await get_tree().process_frame
	for resolution in [Vector2i(1280,720), Vector2i(1152,648)]:
		DisplayServer.window_set_size(resolution)
		get_viewport().size = resolution
		suffix = "_%dx%d" % [resolution.x, resolution.y]
		battle = Battle.instantiate()
		add_child(battle)
		if not await _until("draft"): break
		await _click(Vector2(640,638))
		if not await _until("player_turn"): break
		await _pause()
		_check(battle.player_hud.hp_label.text == "10" and battle.enemy_hud.hp_label.text == "5", "当前教学开局我方10敌方5")
		_check(battle.battlefield.find_children("*", "Label", true, false).all(func(label): return label.text not in ["准备区", "战斗区"]), "不显示准备区战斗区文案")
		for side in ["AllyDeck", "EnemyDeck"]:
			for layer in range(3):
				_check(is_equal_approx(battle.battlefield.get_node(side + str(layer)).rotation, PI * 0.5), "牌库卡背实际横转90度")
		_check(battle.battle_menu.gear.get_theme_stylebox("normal") is StyleBoxEmpty and battle.battle_menu.gear.position.y == 20, "齿轮叠在右上手牌上且没有底框")
		await _shot("clean_board")
		# 条件不足的牌也必须完整展开供阅读。
		await _choose("热锅协作")
		_check(battle.hand_expanded and battle.selected == 4 and battle.action_point == 2, "任意手牌包括不可用牌都能点击展开且不扣点")
		_check_expanded()
		await _shot("expanded_five")
		await _click(Vector2(40,340))
		await _pause()
		_check_collapsed("点击空白")
		await _choose("温火照料")
		var source := _card_point(battle.selected)
		await _mouse(source, true)
		await _move(Vector2(920,340))
		await _pause()
		_check(not battle.hand_expanded and battle.dragging and is_instance_valid(battle.drag_card), "拖出卡牌立即收拢其余手牌")
		await _shot("drag_collapsed")
		await _mouse(Vector2(920,340), false)
		await _pause()
		_check_collapsed("非法拖放")
		_check(battle.hand_cards.size() == 5 and battle.action_point == 2, "非法拖放不消耗卡或行动点")
		await _choose("小小掌勺人")
		source = _card_point(battle.selected)
		await _mouse(source, true)
		await _move(_role_point(true))
		await _mouse(_role_point(true), false)
		if not await _until("player_turn"): break
		await _pause()
		_check_collapsed("成功出牌")
		_check(battle.player_form == "小小掌勺人" and battle.hand_cards.size() == 4 and battle.action_point == 1 and battle.player_hp == 10, "出牌结算且牌手生命不被角色形态覆盖")
		battle.queue_free()
		await get_tree().process_frame
		# 20生命剧情配置，连续真实结束五个回合，自然抽到十张手牌。
		battle = Battle.instantiate()
		battle.player_starting_health = 20
		battle.enemy_starting_health = 20
		add_child(battle)
		if not await _until("draft"): break
		await _click(Vector2(640,638))
		if not await _until("player_turn"): break
		for turn in range(5):
			await _click(Vector2(1242,342))
			if not await _until("player_turn"): break
		_check(battle.hand_cards.size() == 10 and battle.deck.is_empty(), "通过五轮自然抽牌积累十张手牌")
		await _choose(battle.hand_cards[0])
		_check_expanded()
		await _shot("expanded_ten")
		for index in [6, 7, 9]:
			await _click(_card_point(index))
			await _pause()
			_check(battle.selected == index, "双排展开可直接点到任意卡牌 " + str(index))
			_check_expanded()
		await _key(KEY_ESCAPE)
		await _pause()
		_check_collapsed("Esc取消十张牌")
		await _shot("collapsed_ten")
		battle.queue_free()
		await get_tree().process_frame
		if failures: break
	var report := FileAccess.open(output + "/hand-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": results.size(), "failures": failures, "results": results}, "\t"))
	print("YAYA_HAND_ACCEPTANCE ", results.size(), " checks / ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _check_expanded() -> void:
	var rectangles: Array[Rect2] = []
	var clear := true
	for card in battle.hand_nodes:
		var rect := Rect2(card.get_transform() * Vector2.ZERO, card.size * card.scale)
		if not Rect2(Vector2.ZERO, Vector2(1280,720)).encloses(rect): clear = false
		for previous in rectangles:
			if rect.intersects(previous): clear = false
		rectangles.append(rect)
	_check(clear and battle.hand_expanded, "所有展开卡面完整位于画布且互不遮挡")
	_check(battle.hand_nodes.all(func(card): return not card.get_node("Glow").visible), "展开与点击卡牌均没有选中框")
	_check(battle.hand_nodes[battle.selected].scale.is_equal_approx(Vector2.ONE * 1.28), "点击的卡牌放大到1.28倍")

func _check_collapsed(reason: String) -> void:
	var restored: bool = not battle.hand_expanded and battle.selected == -1
	for i in range(battle.hand_nodes.size()):
		if not battle.hand_nodes[i].position.is_equal_approx(battle._hand_pose(i, battle.hand_nodes.size()).position): restored = false
	_check(restored, reason + "后回到右下角初始收拢位置")
