extends "res://tools/tests/home_character_details.gd"
const NEW_IDS := ["jiaopopo", "ahong", "xiluomei", "chengyan", "lanjiao"]
const Recruit = preload("res://scripts/characters/recruitment.gd")
const Face = preload("res://scripts/ui/components/party_character_face.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_seed()
		for checkpoint in ["party", "home", "maze", "title"]: sm.advance_chapter_1_outro(checkpoint)
		_check(not sm.owned_characters().has("ahong"), "登记不会自动授予角色")
		for id in NEW_IDS:
			var config: Dictionary = Progression.CHARACTERS[id]
			var pool: Array = []
			for candidate in Progression.CHARACTERS:
				if Progression.CHARACTERS[candidate].rarity == config.rarity: pool.append(candidate)
			var rarity_roll: float = {"SSR":0.01, "SR":0.2, "R":0.8}[config.rarity]
			var member_roll := (float(pool.find(id)) + 0.5) / float(pool.size())
			var samples := [rarity_roll, member_roll]
			sm.data.gold = 10000
			var result: Dictionary = sm.recruit(1, func(): return samples.pop_front())
			_check(result.success and result.results[0].id == id and sm.owned_characters().has(id), id + "实际招募事务获得")
			sm.load_data()
			_check(Progression.record(sm,id).valid, id + "读档保留拥有与成长")
			_put(id,30,6)
			var row := Progression.record(sm,id)
			_check(row.attack == config.attack + 29 * config.attack_growth and row.health == config.health + 29 * config.health_growth, id + "30级属性")
			_put(id,1,1)
			_check(load(Progression.portrait_path(id)) != null, id + "立绘资源可加载")
		# 用真实保存失败验证新增角色不会在失败后留存。
		var before: Dictionary = sm.data.duplicate(true)
		var original_path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(not sm.recruit(1, func(): return 0.5).success and sm.data == before, "招募保存失败完整回滚")
		sm._active_save_path = original_path
		sm.save()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await get_tree().process_frame
			await _new_flow()
		for id in NEW_IDS:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(470,720)
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			var face := Face.new()
			viewport.add_child(face)
			face.configure(id,1)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_check(viewport.get_texture().get_image().save_png(evidence.path_join(id + "_card.png")) == OK,id + "导出模板卡面")
			viewport.queue_free()
	var report := {"checks":checks,"failures":failures,"results":results}
	FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	get_tree().quit(1 if failures else 0)

func _new_flow() -> void:
	await _open_scene()
	var player = scene.get_node("Player")
	var target = scene.get_node("InteractPoints/AdventurerHomeDoor")
	var ui = get_tree().get_first_node_in_group("ui_layer")
	player.position = _stand(target)
	player.last_valid = player.position
	await get_tree().physics_frame
	await get_tree().process_frame
	await _click(ui._buttons[target])
	var page = get_tree().get_first_node_in_group("adventurer_home")
	_check(is_instance_valid(page), "餐厅实际进入冒险者之家")
	if not is_instance_valid(page): return
	await _shot("new_collection")
	for id in NEW_IDS:
		_check(page.character_buttons.has(id), id + "已拥有列表")
		# 后排按钮滚动到可见位置后使用真实鼠标点击。
		var button: Control = page.character_buttons[id]
		var parent: Node = button.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		if parent is ScrollContainer:
			parent.ensure_control_visible(button)
			await get_tree().process_frame
			await get_tree().process_frame
		await _click(button)
		var modal = page.cards_modal
		_check(modal.visible and modal.character_id == id, id + "点击打开详情")
		_check(modal.name_label.text == Progression.CHARACTERS[id].name, id + "姓名正确")
		_check(modal.attribute_values[0].text == str(int(Progression.CHARACTERS[id].attack)), id + "初始攻击")
		await _shot(id + "_attributes")
		await _click(modal.tabs[1])
		for body in modal.skill_bodies:
			_check(body.get_visible_line_count() == body.get_line_count(), id + "技能全文无截断")
		await _shot(id + "_skills")
		await _send_key(KEY_ESCAPE)
		_check(not modal.visible, id + "Esc返回角色簿")
	# 五张成品卡直接由正式招募卡面模板绘制。
	var layer := CanvasLayer.new()
	layer.layer = 150
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#e5d5ba")
	backdrop.size = get_viewport().get_visible_rect().size
	layer.add_child(backdrop)
	var factor := get_viewport().get_visible_rect().size.x / 2500.0
	for i in NEW_IDS.size():
		var face := Face.new()
		layer.add_child(face)
		face.configure(NEW_IDS[i], 1)
		face.scale = Vector2.ONE * factor
		face.position = Vector2((20 + i * 495) * factor, 30)
	await _shot("five_cards")
	layer.queue_free()
	await get_tree().process_frame
	await _click(page.back_button)
	await get_tree().process_frame
	_check(player.can_process(), "退出角色库恢复输入")
	await _close_scene()

