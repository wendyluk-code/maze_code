extends SceneTree
## 真实渲染原模板，并从真实事务结果验证条件数值接口；不写存档。
const Rules = preload("res://scripts/battle/tutorial_rules.gd")
var failures: Array[String] = []
var checks := 0
var stage: Control
var art_v3 := false
const V3_FILES := {"yaya_restore": "recover", "yaya_magic_hit": "magic_strike", "yaya_magic_wind": "magic_wind", "yaya_heal_wind": "healing_wind", "tieshan_strong": "power", "tieshan_axe": "axe_charge", "tieshan_guard": "guard", "tieshan_hold": "steadfast"}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func card(id: String, pos: Vector2) -> SproutCard:
	var view := SproutCard.new()
	var values: Dictionary = Rules.data()[id].duplicate(true)
	if art_v3 and V3_FILES.has(id):
		values["illustration_override"] = ImageTexture.create_from_image(Image.load_from_file("F:/maze_code/output/card_art_review_v3/%s.png" % V3_FILES[id]))
	view.configure(SproutCardData.new(values))
	stage.add_child(view)
	view.position = pos
	view.size = SproutCard.CARD_SIZE
	view.scale = Vector2.ONE * 0.85
	return view

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://output/card_display_02/%d_%s%s.png" % [root.size.x, "v3_" if art_v3 else "", label]) == OK, "保存实际渲染 " + label)

func check_art_alpha(view: SproutCard, id: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(784, 675)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe := TextureRect.new()
	probe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	probe.texture = view._material_art.texture
	probe.material = view._material_art.material
	probe.size = Vector2(784, 675)
	viewport.add_child(probe)
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	for point in [Vector2i(5, 5), Vector2i(778, 5), Vector2i(392, 660)]:
		check(rendered.get_pixelv(point).a < 0.01, "真透明开窗 %s/%s" % [id, point])
	check(rendered.get_pixel(392, 270).a > 0.95, "卡槽主体不透明 " + id)
	var cover: Vector2 = (probe.material as ShaderMaterial).get_shader_parameter("cover_scale")
	var source_aspect := probe.texture.get_size().aspect()
	check(is_equal_approx(source_aspect * cover.x / cover.y, view._material_art.size.aspect()), "插画比例不拉伸 " + id)
	rendered.save_png("res://output/card_display_02/%d_alpha_%s.png" % [root.size.x, id])
	viewport.queue_free()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/card_display_02")
	art_v3 = OS.get_cmdline_user_args().has("art-v3")
	root.size = Vector2i(1152, 648) if OS.get_cmdline_user_args().has("small") else Vector2i(1280, 720)
	stage = Control.new()
	root.add_child(stage)
	var expected := {
		"yaya_restore": ["-", "-", "-", "-1", "-1"],
		"yaya_magic_hit": ["-", "-", "-", "-2", "-2"],
		"yaya_magic_wind": ["-", "-", "-", "-2", "-2"],
		"yaya_heal_wind": ["-", "-", "-", "-3", "-3"],
		"tieshan_strong": ["-", "-", "-", "-1", "-"],
		"tieshan_axe": ["+2", "-", "+1", "-1", "-"],
		"tieshan_guard": ["+3（如满足条件）", "-", "+4", "-1", "-"],
		"tieshan_hold": ["2", "8", "-", "-2", "-"],
	}
	var keys := ["attack", "health", "shield", "satiety", "mana"]
	var ids := expected.keys()
	for page in 2:
		for child in stage.get_children(): child.queue_free()
		await process_frame
		for column in 4:
			var id: String = ids[page * 4 + column]
			var view := card(id, Vector2((root.size.x - 1050) / 2.0 + column * 265, 65))
			await process_frame
			check(view._material_root.visible, "原模板可见 " + id)
			for i in 5:
				check(SproutCard.display_number(view._data, keys[i]) == expected[id][i], "XLSX原值 %s/%s" % [id, keys[i]])
			check(view._satiety_slot.text == expected[id][3], "饱腹符号 " + id)
			check(view._mana_slot.text == expected[id][4], "魔力原值 " + id)
			check(view._cost_slots.all(func(slot): return not slot.visible), "无行动费用 " + id)
			check(not view._cost_label.visible, "通用布局无行动费用 " + id)
			check(view._value_label.text.is_empty(), "卡面不显示额外核心数值文案 " + id)
			check(view._material_stat_health.visible == (id == "tieshan_hold"), "不把横线显示0 " + id)
			check(view._material_stat_attack.visible == (id in ["tieshan_axe", "tieshan_hold"]), "攻击初始显隐 " + id)
			check(view._shield_art.visible == (id in ["tieshan_guard", "tieshan_axe"]), "技能金盾显隐 " + id)
			check(not view._shield_slot.text.contains("护盾"), "护盾槽只显示数值 " + id)
			check(view._shield_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "金盾等比缩放 " + id)
			if id == "tieshan_guard": check(view._shield_slot.text == "+4", "守护护盾原值")
			if id == "tieshan_axe": check(view._shield_slot.text == "+1", "斧冲护盾原值")
			if art_v3: await check_art_alpha(view, id)
		await capture("skills_%d" % page)
	for child in stage.get_children(): child.queue_free()
	await process_frame
	var guard := card("tieshan_guard", Vector2(70, 65))
	var role := card("tieshan", Vector2(390, 65))
	role.set_battle_context(true)
	role.set_battle_state({"attack": 6, "hp": 3, "shield": 4, "satiety": 0, "mana": -1})
	check(role._material_stat_attack.text == "6" and role._material_stat_health.text == "3", "角色攻击生命实时")
	check(role._satiety_slot.text == "0" and role._shield_slot.text == "4" and role._shield_art.visible, "角色饱腹护盾实时")
	for active in [false, true]:
		var state := Rules.new_state()
		Rules.begin_turn(state, "player")
		state.zones.player = "yaya" if active else ""
		var ap: int = state.ap
		var satiety: int = state.characters.tieshan.satiety
		var result := Rules.transact(state, "tieshan_guard", "tieshan", false)
		check(result.success, "守护真实事务成功")
		check(state.ap == ap - 1 and state.characters.tieshan.satiety == satiety - 1, "隐藏文字仍支付1AP及1饱腹")
		var bonus := 0
		for event in result.events:
			if event.kind == "strike": bonus = event.attack - Rules.attack_value(state.characters.tieshan)
		guard.set_skill_resolution({"conditional_attack_active": bonus == 3})
		check(guard._material_stat_attack.visible == active, "守护使用条件显隐")
		if active: check(guard._material_stat_attack.text == "+3", "条件攻击保留加号")
		await capture("guard_%s" % active)
	guard.set_skill_resolution({})
	check(not guard._material_stat_attack.visible, "清除事务展示后恢复隐藏")
	role.set_battle_state({"attack": 2, "hp": 7, "shield": 0, "satiety": 4, "mana": -1})
	check(role._material_stat_attack.text == "2" and role._material_stat_health.text == "7" and role._satiety_slot.text == "4", "实时数字二次刷新")
	check(role._shield_slot.text == "0", "角色护盾实时归零")
	var report := {"checks": checks, "failures": failures, "resolution": str(root.size)}
	FileAccess.open("res://output/card_display_02/%d_%sreport.json" % [root.size.x, "v3_" if art_v3 else ""], FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
