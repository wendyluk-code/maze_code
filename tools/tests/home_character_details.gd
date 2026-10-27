extends "res://tools/tests/adventurer_home_input.gd"
const Progression := preload("res://scripts/characters/character_progression.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离用户存档")
	if failures == 0:
		_seed()
		for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
		_service_checks()
		for resolution in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x, resolution.y]
			await get_tree().process_frame
			await _details_flow()
			if failures: break
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "display": DisplayServer.get_name()}, "\t"))
	print("HOME_DETAILS ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _put(id: String, level: int, rank: int, experience := 0, breaks := -1) -> void:
	var entries: Dictionary = sm.data.get(Progression.KEY, {}).duplicate(true)
	entries[id] = {"level": level, "rank": rank, "exp": experience, "breakthroughs": floori((level - 1) / 5.0) if breaks < 0 else breaks}
	sm.data[Progression.KEY] = entries

func _service_checks() -> void:
	var baseline: Dictionary = sm.data.duplicate(true)
	_check(Progression.record(sm, "yaya").rank == 1 and sm.data == baseline, "旧档默认1阶只读不写")
	_check(not Progression.record(sm, "unknown").valid, "拒绝未拥有角色")
	_put("yaya", 5, 3)
	_put("tieshan", 2, 6, 120)
	sm.data.gold = 99
	_check(Progression.breakthrough(sm, "yaya").reason == "insufficient_gold", "金币不足不突破")
	sm.data.gold = 100
	sm.data[Progression.KEY].yaya["future_field"] = "preserve"
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(Progression.breakthrough(sm, "yaya").reason == "save_failed" and sm.data == before, "保存失败完整回滚")
	sm._active_save_path = path
	_check(Progression.breakthrough(sm, "yaya").success, "5级100金币突破成功")
	var row := Progression.record(sm, "yaya")
	_check(row.level == 5 and row.rank == 3 and row.breakthroughs == 1 and sm.gold_balance() == 0, "突破不升级不升星且只扣一次金币")
	_check(sm.data[Progression.KEY].yaya.future_field == "preserve" and sm.data[Progression.KEY].tieshan == before[Progression.KEY].tieshan, "保留未知字段及另一角色")
	_check(Progression.breakthrough(sm, "yaya").reason == "not_eligible", "重复突破拒绝")
	sm.load_data()
	_check(Progression.record(sm, "yaya").breakthroughs == 1 and Progression.record(sm, "tieshan").rank == 6, "JSON浮点读档保留独立阶位与突破")
	for level in range(1, 31):
		_put("yaya", level, 1)
		_put("tieshan", level, 6)
		var yaya := Progression.record(sm, "yaya")
		var tieshan := Progression.record(sm, "tieshan")
		_check(yaya.valid and tieshan.valid and yaya.attack == level and tieshan.attack == level * 2 and yaya.satiety_max == 2 + floori(level / 5.0) and tieshan.satiety_max == 1 + floori(level / 5.0) and tieshan.recovery_percent < yaya.recovery_percent, "等级%d基础成长和阶位独立" % level)
	for bad in [null, [], "bad", {"level": 1, "rank": 7, "exp": 0, "breakthroughs": 0}, {"level": 5, "rank": 1, "exp": 1, "breakthroughs": 0}]:
		sm.data[Progression.KEY]["yaya"] = bad
		_check(not Progression.record(sm, "yaya").valid and not Progression.breakthrough(sm, "yaya").success, "坏记录禁止展示奖励和突破")
	sm.data = baseline.duplicate(true)
	_put("yaya", 5, 1)
	sm.data.gold = 200
	sm.begin_replay()
	_check(Progression.breakthrough(sm, "yaya").reason == "preview", "重播不能突破正式档")
	sm.end_replay()
	sm.data = baseline.duplicate(true)
	sm.save()

func _details_flow() -> void:
	_put("yaya", 1, 1, 120)
	_put("tieshan", 1, 1)
	sm.save()
	await _open_scene()
	var player = scene.get_node("Player")
	var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
	var ui = get_tree().get_first_node_in_group("ui_layer")
	player.position = _stand(target)
	player.last_valid = player.position
	await get_tree().physics_frame
	await get_tree().process_frame
	var entry: Control = ui._buttons[target]
	_check(entry.is_visible_in_tree(), "实际餐厅靠近入口显示按钮")
	await _click(entry)
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(is_instance_valid(page), "实际入口打开角色簿")
	if not is_instance_valid(page): return
	await _click(page.character_buttons.yaya)
	var modal = page.cards_modal
	_check(modal.visible and modal.character_id == "yaya" and modal.experience_label.text == "120 / 500", "点击芽芽展示真实经验")
	_check(not modal.breakthrough_button.visible and modal.stars[0].texture.resource_path.ends_with("star_lit.png") and modal.stars[1].texture.resource_path.ends_with("star_dim.png"), "1级隐藏突破且仅1星亮")
	_check(modal.attribute_values[0].text == "1" and modal.attribute_values[2].text == "2 / 2" and modal.attribute_values[3].text == "0.020%", "芽芽1级当前属性")
	_check(modal.faction_icon.texture.resource_path.ends_with("grass.png"), "芽芽显示草系图标")
	_check(modal.name_label.get_theme_font("font").resource_path == "res://assets/ui/game_font.tres", "文字使用游戏真实字体")
	await _shot("yaya_attributes")
	_check(modal.experience_bar.value == 24.0, "经验填充与120/500一致")
	await _click(modal.tabs[1])
	_check(modal.skills.visible and modal.skill_badges[0].text == "已解锁" and modal.skill_badges[5].text == "6阶解锁", "技能页按阶位高亮与锁定")
	for body in modal.skill_bodies:
		_check(body.get_line_count() <= 2 and body.get_visible_line_count() == body.get_line_count(), "技能正文完整可见")
	await _shot("yaya_skills")
	await _send_key(KEY_ESCAPE)
	_check(not modal.visible and is_instance_valid(page) and not page.back_button.disabled, "Esc只返回角色列表")
	await _click(page.character_buttons.tieshan)
	_check(modal.character_id == "tieshan" and modal.attribute_values[0].text == "2" and modal.attribute_values[2].text == "1 / 1" and modal.attribute_values[3].text == "0.010%", "铁山独立数值")
	_check(modal.faction_icon.texture.resource_path.ends_with("earth.png"), "铁山显示土系图标")
	await _shot("tieshan_attributes")
	_put("tieshan", 5, 3)
	sm.data.gold = 99
	modal.refresh()
	_check(modal.breakthrough_button.visible and modal.breakthrough_button.disabled, "5级金币不足按钮显示禁用")
	_check(modal.experience_bar.value == 0.0, "突破门槛空经验条无绿色填充")
	await _shot("tieshan_breakthrough_disabled")
	sm.data.gold = 100
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not modal.breakthrough_button.disabled, "金币恰够按钮启用")
	await _shot("tieshan_breakthrough")
	await _click(modal.breakthrough_button)
	_check(not modal.breakthrough_button.visible and sm.gold_balance() == 0 and Progression.record(sm, "tieshan").rank == 3, "实际点击突破保存并隐藏按钮不升星")
	sm.load_data()
	modal.refresh()
	_check(not modal.breakthrough_button.visible, "读档后不重复显示已突破按钮")
	_put("tieshan", 30, 6)
	modal.refresh()
	_check(modal.experience_label.text == "已满级" and not modal.breakthrough_button.visible and modal.attribute_values[3].text == "0.0245%", "30级满级与恢复精度")
	await _shot("tieshan_max_level")
	await _click(modal.tabs[1])
	_check(modal.skill_badges.all(func(label): return label.text == "已解锁"), "6阶六技能全部解锁")
	await _shot("tieshan_skills_rank6")
	await _click(modal._close_button)
	_check(not modal.visible and not page.back_button.disabled, "点击面板外关闭按钮返回角色簿")
	await _shot("collection_after_selection")
	await _click(page.back_button)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("adventurer_home").is_empty() and player.can_process(), "关闭角色簿恢复原餐厅输入")
	await _close_scene()

