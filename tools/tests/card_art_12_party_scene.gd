extends "res://tools/tests/chapter_ending_input.gd"
## 仅覆盖真实餐厅入队，不执行旧章末标题时长或整图组件断言。
const ArtCatalog = preload("res://scripts/ui/components/card_art_catalog.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _party_flow_only()
			await _party_cancel_only()
	var report := {"checks":checks,"failures":failures,"results":results,"user_dir":ProjectSettings.globalize_path("user://")}
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CARD_ART_12_PARTY_SCENE ", checks, " checks, ", failures, " failures; user_dir=", report.user_dir)
	get_tree().quit(1 if failures else 0)

func _party_flow_only() -> void:
	_seed()
	await _open_scene()
	_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro.phase == "party" and tm._chapter_outro._party.visible,180), "真实餐厅进入入队")
	if not is_instance_valid(tm._chapter_outro):
		await _close_scene()
		return
	var outro = tm._chapter_outro
	var party = outro._party
	var held := InputEventKey.new()
	held.keycode = KEY_E
	held.pressed = true
	get_viewport().push_input(held)
	await get_tree().create_timer(0.15).timeout
	_check(outro.phase == "party" and party.visible, "早E不跳过入场")
	_check(await _wait_until(func(): return not outro._busy,180), "真实扇形展开完成")
	_check(outro.phase == "party" and party.visible and not party._armed, "长按E不穿透")
	_check(party.cards.size() == 2 and party.cards[0].rotation < 0 and party.cards[1].rotation > 0, "双卡扇形")
	var records := ArtCatalog.display_records()
	for index in 2:
		var card := party.cards[index].get_node_or_null("TemplateCard") as SproutCard
		_check(card != null, "实际原生TemplateCard")
		if card == null: continue
		var id := "yaya" if index == 0 else "tieshan"
		for raw in records:
			if raw.id != id: continue
			_check(card._data.id == id and card._material_effect.text == raw.effect, "角色与原表技能原文：" + id)
			_check(card._material_art.texture != null and card._material_art.texture.resource_path == ArtCatalog.path_for(id), "实际唯一插画：" + id)
			_check(card._satiety_slot.text == raw.display_values.satiety and card._material_stat_attack.text == raw.display_values.attack and card._material_stat_health.text == raw.display_values.health, "真实资源与攻血：" + id)
			if id == "yaya": _check(card._mana_slot.text == "3", "芽芽魔力3")
			_check(card.size.is_equal_approx(SproutCard.CARD_SIZE), "原生布局不压窄：" + id)
			var label: Label = card._material_effect
			var paragraph := TextParagraph.new()
			paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			paragraph.width = label.size.x
			paragraph.add_string(label.text, label.get_theme_font("font"), label.get_theme_font_size("font_size"))
			_check(paragraph.get_size().y <= label.size.y, "最终有效正文高度容纳：" + id)
			print("PARTY_FINAL_TEXT ", id, " size=", label.size, " position=", label.position, " font=", label.get_theme_font_size("font_size"), " original=", raw.effect)
	await _shot("party_actual_native")
	var echo := InputEventKey.new()
	echo.keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	get_viewport().push_input(echo)
	await get_tree().process_frame
	_check(outro.phase == "party", "重复E不继续")
	var release := InputEventKey.new()
	release.keycode = KEY_E
	get_viewport().push_input(release)
	await get_tree().process_frame
	await _send_key(KEY_E)
	_check(await _wait_until(func(): return outro.phase == "home" and not outro._busy,180), "松键后新E进入home")
	_check(not party.visible and scene.get_node("UIOverlay/TutorialGuide").dialog._lines == [outro.HOME_LINE], "真实home对白接续")
	await _shot("party_to_home")
	await _close_scene()

func _party_cancel_only() -> void:
	_seed()
	await _open_scene()
	_check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro._party.visible,180), "真实取消场景展卡")
	if not is_instance_valid(tm._chapter_outro):
		await _close_scene()
		return
	var party = tm._chapter_outro._party
	var before: Dictionary = sm.data.duplicate(true)
	tm._cancel_current_run()
	_check(not party.visible and party._tween == null, "取消隐藏并停止动画")
	await get_tree().create_timer(1.3).timeout
	_check(sm.data == before and not tm.active, "取消无旧回调推进")
	_check(not scene.get_node("Player").input_locked and scene.get_node("Player").is_physics_processing(), "取消恢复移动输入")
	_check(not scene.get_node("Camera").paused, "取消恢复镜头")
	await _shot("party_cancel_restored")
	await _close_scene()
