extends "res://tools/tests/chapter_ending_input.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(960,540), Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _hover_case()
		await _generic_case()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("COOKING_HINT ", checks," checks, ", failures," failures")
	get_tree().quit(1 if failures else 0)

func _move_to_card(card: Control, ratio := Vector2(0.5,0.7)) -> void:
	var point := card.get_global_transform_with_canvas() * (card.size * ratio)
	get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion)
	await get_tree().process_frame
	await get_tree().process_frame

func _hover_case() -> void:
	_seed()
	await _open_scene()
	_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro._party.visible, 120),"卡牌展开出现")
	var overlay = tm._chapter_outro._party
	await _move_to_card(overlay.cards[0])
	_check(not _has_hint(overlay),"入队展示不创建能力浮层")
	_check(await _wait_until(func(): return overlay._ready_for_input,240),"等待展开完成")
	await _move_to_card(overlay.cards[0])
	_check(not _has_hint(overlay),"展开后悬停芽芽无能力浮层")
	await get_tree().create_timer(0.1).timeout
	_shot("party_no_hint")
	await _move_to_card(overlay.cards[1])
	_check(not _has_hint(overlay),"铁山卡不显示烹饪")
	await _move_to_card(overlay.cards[0])
	await _send_key(KEY_E)
	_check(not overlay.visible,"悬停后按E仍正常继续")
	await _close_scene()

func _generic_case() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var card := SproutCard.new()
	canvas.add_child(card)
	var data := SproutCardData.new()
	data.effect = "烹饪"
	card.configure(data)
	await _move_to_card(card)
	_check(not card._ability_hint.panel.visible,"普通卡牌默认不自动悬停说明")
	card.set_ability_details_enabled(true)
	await get_tree().process_frame
	_check(card._ability_hint.panel.visible,"详情调用方显式开启后可显示说明")
	_check(card._ability_hint.description.text == "使用带“烹饪”能力的牌会获得一张「食材」牌；若手牌已有另外两张「食材」，三张会自动合成一张「佳肴」。","原文说明保留")
	card.set_ability_details_enabled(false)
	_check(not card._ability_hint.panel.visible,"关闭详情立即隐藏说明")
	card.set_ability_details_enabled(true)
	data.effect = "本回合使用过料理时抽牌"
	card.configure(data)
	await get_tree().process_frame

	_check(not card._ability_hint.panel.visible,"仅料理词语不误触发")
	data.effect = "烹饪"
	card.configure(data)
	card.hide()
	await get_tree().process_frame
	_check(not card._ability_hint.panel.visible,"隐藏卡牌不遗留悬浮层")
	canvas.queue_free()
	await get_tree().process_frame

func _has_hint(root: Node) -> bool:
	if root.get_script() == preload("res://scripts/ui/components/ability_hint.gd"):
		return true
	for child in root.get_children():
		if _has_hint(child):
			return true
	return false
