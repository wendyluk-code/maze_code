extends "res://tools/tests/adventurer_home_input.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离用户存档")
	if failures == 0:
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await _walkthrough()
			await _greeting_cards()
			if failures: break
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name()}, "\t"))
	print("HOME_GREETING_CARDS ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _greeting_cards() -> void:
	_seed()
	_check(sm.unlock_ch1_cards().success, "通过真实接口解锁首章已有卡牌")
	for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
	await _open_scene()
	var baseline: Dictionary = sm.data.duplicate(true)
	var saved := FileAccess.get_file_as_bytes(sm._active_save_path)
	HomePage.open_page(get_tree())
	await get_tree().process_frame
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(page.residents.size() == 2 and get_tree().get_nodes_in_group("home_wanderer").is_empty(), "两人常驻迎接，旧散步循环未创建")
	var starts: Array = []
	for actor in page.residents:
		starts.append(actor.position)
		_check(actor.modulate.a == 1 and actor.body.animation == "greet" and actor.body.is_playing(), actor.character_id + "直接可见且播放挥手招呼")
	await get_tree().create_timer(1.8).timeout
	for index in page.residents.size():
		var actor = page.residents[index]
		_check(actor.position == starts[index] and actor.modulate.a == 1 and not actor.body.is_playing(), actor.character_id + "招呼后站定，不移动或消失")
	await _shot("greeting")
	for actor in page.residents:
		await _click(actor.hit_button)
		var modal = page.cards_modal
		_check(modal.visible and modal.cards.size() == 8 and modal.cards.all(func(card): return card.id.begins_with(actor.character_id + "_")), "点击" + actor.character_id + "只显示该角色已拥有八张卡")
		if not modal.visible: return
		_check(page.back_button.disabled and page.residents.all(func(other): return other.hit_button.disabled), "蒙层禁用下层角色与返回按钮")
		_check(modal.card_index == 0 and modal.previous_button.disabled, "每次打开从第一张开始且首端不越界")
		await get_tree().create_timer(0.4).timeout
		await _shot(actor.character_id + "_cards_first")
		for card in modal.strip.get_children():
			_check(card.scale.y >= 0.9, "卡面保持可读尺寸而非缩成窄条", {"size": str(card.size), "scale": str(card.scale)})
			_check(card.position.y + card.size.y * card.scale.y <= modal.viewport_area.size.y, "完整卡牌高度位于滑动窗口内")
			_check(card._number_label.get_global_rect().end.y <= modal.viewport_area.get_global_rect().end.y, "底部卡号实际布局完整可见")
		await _drag(modal, Vector2(-180, 0), false)
		_check(modal.card_index == 1, "鼠标向左拖动翻到下一张")
		await _drag(modal, Vector2(180, 0), true)
		_check(modal.card_index == 0, "触屏向右滑动返回上一张")
		await _drag(modal, Vector2(15, 110), false)
		_check(modal.card_index == 0, "竖拖与轻触不误翻页")
		await _click(modal.next_button)
		_check(modal.card_index == 1, "下一张按钮生效")
		for index in 8: await _send_key(KEY_RIGHT)
		_check(modal.card_index == 7 and modal.next_button.disabled, "键盘可看完所有卡牌，末端不越界")
		await get_tree().create_timer(0.25).timeout
		await _shot(actor.character_id + "_cards_last")
		for index in 6:
			await _send_key(KEY_TAB)
			_check(modal.is_ancestor_of(get_viewport().gui_get_focus_owner()), "Tab焦点限制在蒙层")
		await _click(page.back_button)
		_check(modal.visible and is_instance_valid(page), "点击蒙层后方返回位置不穿透")
		await _send_key(KEY_ESCAPE)
		_check(not modal.visible and is_instance_valid(page) and not actor.hit_button.disabled and actor.hit_button.has_focus(), "Esc只关卡牌层并恢复角色焦点")
		await _click(actor.hit_button)
		_check(modal.visible and modal.card_index == 0, "重复打开重置卡牌位置")
		await _click(modal._close_button)
		_check(not modal.visible and not page.back_button.disabled, "关闭按钮恢复下层输入")
	var subset := {"unlocked": true, "card_ids": ["yaya_02", "tieshan_04", "yaya_08"]}
	page.cards_modal.present("yaya", subset)
	_check(page.cards_modal.cards.size() == 2 and page.cards_modal.cards[0].id == "yaya_02" and page.cards_modal.cards[1].id == "yaya_08", "混合子集严格按拥有ID筛选，不显示未拥有牌")
	await _shot("owned_subset")
	page.cards_modal.present("tieshan", subset)
	_check(page.cards_modal.cards.size() == 1 and page.cards_modal.previous_button.disabled and page.cards_modal.next_button.disabled, "单卡两端按钮禁用")
	page.cards_modal.present("yaya", {"unlocked": false, "card_ids": []})
	_check(page.cards_modal.cards.is_empty() and page.cards_modal.empty_label.visible, "未解锁显示空态，不借浏览解锁")
	await _shot("empty_cards")
	page.cards_modal.close_modal()
	_check(sm.data == baseline and FileAccess.get_file_as_bytes(sm._active_save_path) == saved, "浏览不改变拥有状态、卡组或存档")
	await _click(page.back_button)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("home_greeter").is_empty() and scene.can_process(), "关闭页面释放角色并恢复餐厅")
	await _close_scene()
	sm.data = sm._defaults()
	HomePage.open_page(get_tree())
	await get_tree().process_frame
	page = get_tree().get_first_node_in_group("adventurer_home")
	_check(page.residents.is_empty(), "未收录角色不显示")
	await _send_key(KEY_ESCAPE)
	await get_tree().process_frame

func _drag(modal: Control, delta: Vector2, touch: bool) -> void:
	var start: Vector2 = modal.viewport_area.get_global_transform_with_canvas() * Vector2(550, 220)
	var end: Vector2 = start + delta * modal.design.scale.x
	if touch:
		var down := InputEventScreenTouch.new()
		down.index = 0; down.position = start; down.pressed = true
		get_viewport().push_input(down)
		var motion := InputEventScreenDrag.new()
		motion.index = 0; motion.position = end; motion.relative = end - start
		get_viewport().push_input(motion)
		var up := InputEventScreenTouch.new()
		up.index = 0; up.position = end
		get_viewport().push_input(up)
	else:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = start
		get_viewport().push_input(down)
		var motion := InputEventMouseMotion.new()
		motion.position = end; motion.relative = end - start; motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT; up.position = end
		get_viewport().push_input(up)
	await get_tree().create_timer(0.25).timeout
