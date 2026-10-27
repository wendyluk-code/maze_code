extends "res://tools/tests/rec01_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720), Vector2i(1920,1080)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _review_flow()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _wait_stage(view: Control, expected: String) -> bool:
	for i in 180:
		if view.stage == expected: return true
		await get_tree().create_timer(0.02).timeout
	_check(false, "演出阶段超时:"+expected, view.stage)
	return false

func _centered(button: Control) -> bool:
	return absf(button.get_global_rect().get_center().x - get_viewport().get_visible_rect().get_center().x) < 2.0

func _review_flow() -> void:
	_seed()
	for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
	sm.data.gold = 100000
	sm.save()
	await _open_scene()
	var player = scene.get_node("Player")
	var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
	player.position = _stand(target)
	player.last_valid = player.position
	await get_tree().physics_frame
	await get_tree().process_frame
	await _click(get_tree().get_first_node_in_group("ui_layer")._buttons[target])
	var page = get_tree().get_first_node_in_group("adventurer_home")
	await _click(page.tabs[1])
	var panel = page.summon_panel
	for entry in [["salia","SaliaName"],["yufeng","YufengName"],["dingdang","DingdangName"]]:
		_check(panel.get_node(entry[1]).get_global_rect().encloses(panel.rarity_badges[entry[0]].get_global_rect()), "姓名稀有度同一底板:"+entry[0])
	var buttons: Rect2 = panel.single_button.get_global_rect().merge(panel.ten_button.get_global_rect())
	_check(absf(buttons.get_center().x - get_viewport().get_visible_rect().get_center().x) < 2, "招募双按钮整体居中")
	_check(absf(panel.single_price.get_global_rect().get_center().x-panel.single_button.get_global_rect().get_center().x)<2 and absf(panel.ten_price.get_global_rect().get_center().x-panel.ten_button.get_global_rect().get_center().x)<2, "价格对应按钮中心")
	await _shot("r2_summon")
	# 真实十连：萨莉亚8张，从新卡到6星再溢出200尘；御风新卡加一次重复。
	var rolls: Array = []
	for i in 8: rolls.append_array([0.0,0.0])
	for i in 2: rolls.append_array([0.2,0.0])
	var batch: Dictionary = sm.recruit(10, func(): return rolls.pop_front())
	_check(batch.success and sm.stardust_balance() == 200, "真实十连新卡连续重复与溢出")
	var saved: Dictionary = sm.data.duplicate(true)
	var disk := FileAccess.get_file_as_bytes(sm._active_save_path)
	var view = page.recruit_results
	view.present(batch.results)
	for i in 10:
		_check(view.index == i and view.displayed_rank == 1 and view.stage == "enter" and view.title.text == "恭喜获得", "每张先出现1星且无进度标题:%d"%i)
		_check(not view.caption.visible and not view.draw_line.visible, "翻卡前文字隐藏")
		if i == 0:
			await _shot("r2_card_back")
			await get_tree().create_timer(0.25).timeout
			await _shot("r2_entry_turn")
		await _wait_stage(view,"name")
		_check(view.caption.visible and not view.draw_line.visible and view.current_face.scale.is_equal_approx(Vector2(0.44,0.44)), "翻牌后先名字且卡面缩小")
		_check(view.caption.modulate.a < 1.0, "姓名使用渐显")
		await _wait_stage(view,"upgrade")
		var result: Dictionary = batch.results[i]
		_check(not view.draw_line.visible and view.outcome_line.text == "升至%d星" % int(result.rank) and view.outcome_line.modulate.a < 1.0, "只渐显最终升星文案")
		if result.kind == "stardust":
			if not await _wait_stage(view,"dust"): break
			await get_tree().process_frame
			_check(view.loot.visible and view.loot._title_label.text == "恭喜获得" and view.loot.item_views[0].icon.size == Vector2(43,43), "自动转尘复用43像素奖励窗")
			_check(_centered(view.loot._confirm_button), "奖励收下按钮居中")
			await _shot("r2_auto_dust_%d"%i)
			await _click(view.loot._confirm_button)
		else:
			if not await _wait_stage(view,"ready"): break
			_check(view.displayed_rank == int(result.rank) and not view.loot.visible, "正确升星且不产尘:%d"%i)
			if i in [2,5]: await _shot("r2_upgraded_%d"%i)
			await _click(view.next_button)
	_check(view.overview and view.grouped.size() == 2 and view.title.text == "恭喜获得", "十连按角色合并总览")
	_check(view.grouped[0] == {"id":"salia","rank":6,"count":8,"duplicates":7,"stardust":200}, "新卡首次不重复，六星溢出另外统计")
	_check(view.grouped[1] == {"id":"yufeng","rank":2,"count":2,"duplicates":1,"stardust":0}, "同角色只显示最高星级")
	_check(_centered(view.next_button), "总览单按钮居中")
	_check(view.next_button.size.x == 160 and view.skip_button.size.x == 160 and view.next_button.alignment == HORIZONTAL_ALIGNMENT_CENTER and view.next_button.icon == null, "短按钮文字居中无图标占位")
	for button in [view.next_button, view.skip_button, view.loot._confirm_button]:
		_check(button is SproutButton and button.get_theme_stylebox("focus") is StyleBoxEmpty and button.focus_mode == Control.FOCUS_ALL, "暖金按钮保留键盘焦点且无绿框")
		for state in ["normal","hover","pressed"]:
			var tint: Color = button.get_theme_stylebox(state).modulate_color
			_check(tint.r >= tint.g, "按钮状态不使用绿色:"+state)
	_check(view.next_button.text == "确认" and view.skip_button.text == "确认", "确认文案与原跳转行为")
	var boxes: Array = []
	for child in view.content.get_children():
		if child is VBoxContainer: boxes.append(child)
	_check(boxes[0].get_node("Rank").get_theme_font_size("font_size") == 28 and boxes[0].get_node("Count").get_theme_font_size("font_size") == 16, "总览字体层次")
	_check(boxes[0].has_node("Dust") and not boxes[1].has_node("Dust") and boxes[0].get_node("Dust").get_child(1).text == "+200", "有星尘图标加数值，无星尘隐藏第三行")
	await _send_key(KEY_TAB)
	_check(view.next_button.has_focus(), "键盘Tab保持确认可达")
	await _shot("r2_grouped_keyboard_focus")
	await _shot("r2_grouped_overview")
	await _click(view.next_button)
	_check(sm.data == saved and FileAccess.get_file_as_bytes(sm._active_save_path) == disk, "完整演出内存磁盘均不重复发奖")
	# 精确示例：新角色3张 => 重复2次/3星；使用三次真实事务的快照。
	var example: Array = []
	for i in 3:
		var pick := [0.4,0.0]
		example.append_array(sm.recruit(1,func(): return pick.pop_front()).results)
	view.present(example)
	await _click(view.skip_button)
	_check(view.grouped[0].count == 3 and view.grouped[0].duplicates == 2 and view.grouped[0].rank == 3, "三张新角色示例聚合")
	await _shot("r2_three_cards_example")
	await _click(view.next_button)
	# 同批前已拥有的首张也计重复。
	var existing: Dictionary = sm.recruit(1,func(): return 0.2)
	view.present(existing.results)
	_check(_centered(view.next_button), "单抽演出按钮居中")
	_check(not view.overview and view.stage == "enter", "单抽也先翻牌且不进入聚合页")
	await _wait_stage(view,"ready")
	_check(view.outcome_line.text == "升至%d星" % int(existing.results[0].rank) and view.title.text == "恭喜获得", "单抽只显示最终星级")
	await _click(view.next_button)
	saved = sm.data.duplicate(true)
	disk = FileAccess.get_file_as_bytes(sm._active_save_path)
	# 每种异步阶段取消，关闭后等待旧动画时长，确保不会重开弹窗。
	for phase in ["enter","name","upgrade","flipping","dust"]:
		view.present([batch.results[6] if phase in ["flipping","dust"] else batch.results[2], batch.results[9]])
		if phase != "enter": await _wait_stage(view,phase)
		await _click(view.skip_button)
		_check(view.overview, "动画中跳过到总览:"+phase)
		await _click(view.next_button)
		for repeat in 3: view._advance()
		await get_tree().create_timer(1.6).timeout
		_check(not view.visible and not view.loot.visible and not view.flipping, "关闭及连击无旧回调:"+phase)
	_check(sm.data == saved and FileAccess.get_file_as_bytes(sm._active_save_path) == disk, "所有中断只读已保存结果")
	view.present([batch.results[6]])
	await _wait_stage(view,"dust")
	await _click(view.loot._confirm_button)
	_check(not view.visible, "满星单抽收下直接结束不再确认")
	# 独立展示数据覆盖6/10个位置；不修改统一角色目录或存档。
	var layout_view = preload("res://tools/tests/rec01_layout_view.gd").new()
	view.get_parent().add_child(layout_view)
	for amount in [5,6,10]:
		layout_view.amount = amount
		layout_view.present([batch.results[6]])
		layout_view._show_overview()
		await get_tree().process_frame
		_check(layout_view.grouped.size() == amount, "总览独立位置数量:%d"%amount)
		for child in layout_view.content.get_children():
			_check(get_viewport().get_visible_rect().encloses(child.get_global_rect()) and not child.get_global_rect().intersects(layout_view.next_button.get_global_rect()), "多行内容不溢出或覆盖按钮:%d"%amount)
		await _shot("r2_layout_%d"%amount)
		await _click(layout_view.next_button)
	layout_view.queue_free()
	# 页面真实按钮仍锁住招募重入；Esc两次释放结果层再返回。
	await _click(panel.ten_button)
	var gold: int = sm.gold_balance()
	page._on_summon_requested(10,9000)
	_check(sm.gold_balance() == gold and page._summoning, "真实抽取期间拒绝重复扣款")
	await _send_key(KEY_ESCAPE)
	await _click(view.next_button)
	_check(not page._summoning, "结果结束释放主页招募锁")
	await _click(page.back_button)
	_check(player.can_process() and not player.input_locked, "返回餐厅输入恢复")
	await _close_scene()
