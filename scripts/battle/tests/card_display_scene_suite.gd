extends "res://scripts/battle/tests/bt_fx_01_scene_suite.gd"
## 原真实入口/八回合/分裂验收之外，补充五牌排版、乱序换牌与条件使用。
var art_installed := 0
var observed_casts: Dictionary = {}
var expected_condition := false
var condition_case := "full"
const V3_FILES := {"yaya_restore": "recover", "yaya_magic_hit": "magic_strike", "yaya_magic_wind": "magic_wind", "yaya_heal_wind": "healing_wind", "tieshan_strong": "power", "tieshan_axe": "axe_charge", "tieshan_guard": "guard", "tieshan_hold": "steadfast"}

func _initialize() -> void:
	process_frame.connect(_observe_display)
	super._initialize()

func _observe_display() -> void:
	if not is_instance_valid(current_scene) or current_scene.scene_file_path != "res://scenes/battle/yaya_battle_demo.tscn": return
	var candidate: Control = current_scene.get_child(0)
	if OS.get_cmdline_user_args().has("art-v3") and candidate.get_instance_id() != art_installed:
		art_installed = candidate.get_instance_id()
		for id in V3_FILES:
			candidate.tutorial_art[id] = "res://assets/ui/card_materials/_card_display_v3_validation/%s.png" % V3_FILES[id]
		candidate._sync()
	var fly: Control = candidate.board.get_node_or_null("SkillResolutionCard")
	if fly == null or observed_casts.has(fly.get_instance_id()): return
	var view: SproutCard = fly.get_node("TemplateCard")
	if view._data.id != "tieshan_guard": return
	observed_casts[fly.get_instance_id()] = true
	check(view._material_stat_attack.visible == expected_condition, "正式控制器条件使用显隐 " + condition_case)
	check(view._shield_slot.text == "+4" and view._shield_art.visible, "正式使用金盾+4")
	check(view._material_effect.text.contains("+3"), "条件技能说明保留原文")
	check_skill_art(view, candidate)
	if expected_condition: check(view._material_stat_attack.text == "+3", "正式使用条件攻击+3")
	_cast_shot(condition_case)

func _cast_shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/card_display_02/%d_cast_%s.png" % [root.size.x, label])

func check_skill_art(view: SproutCard, controller: Control) -> void:
	var path: String = controller.tutorial_art.get(view._data.id, "")
	check(not path.is_empty() and ResourceLoader.exists(path), "技能插画映射可读取 " + view._data.id)
	check(view._material_art.texture.resource_path == path, "实际卡面使用对应技能插画 " + view._data.id)

func select_card(id: String) -> bool:
	var selected_ok: bool = await super.select_card(id)
	if selected_ok:
		check_skill_art(ui.hand_nodes[ui.selected].get_node("TemplateCard"), ui)
	return selected_ok

func draft_checks() -> void:
	var last_right := 0.0
	check(ui.draft_cards.size() == 5, "起手完整五张")
	for i in range(5):
		var view: SproutCard = ui.draft_cards[i].get_node("TemplateCard")
		check_skill_art(view, ui)
		check(ui.draft_cards[i].size == Vector2(228, 380), "起手放大 " + str(i))
		check(ui.draft_cards[i].position.x >= last_right, "五牌没有相互遮挡 " + str(i))
		last_right = ui.draft_cards[i].position.x + ui.draft_cards[i].size.x
		var draft: Control = ui.draft_cards[i]
		var frame_bottom := SproutCard.MATERIAL.edge_rect("frame").end.y / SproutCard.CARD_SIZE.y
		var visible_bottom: float = draft.position.y + draft.pivot_offset.y + (draft.size.y * frame_bottom - draft.pivot_offset.y) * draft.scale.y
		check(last_right <= 1280 and visible_bottom < ui.replace_buttons[i].position.y, "可见卡框与操作不重叠 " + str(i))
		if view._data.id == "tieshan_guard": check(not view._material_stat_attack.visible, "起手守护条件UI隐藏")
		await click(ui.draft_cards[i].position + Vector2(114, 150))
		check(ui.draft_selected == i, "五牌实际鼠标命中 " + str(i))
		check(ui.draft_cards[i].scale.is_equal_approx(Vector2.ONE * 1.025), "选中轻抬不压邻牌")
		check(ui._hit(ui.draft_cards[i], ui.draft_cards[i].position + Vector2(114, 350)), "放大后的下部命中区")
	for slot in [4, 1, 3]:
		await click(ui.draft_cards[slot].position + Vector2(114, 150))
		var count: int = ui.battle.replacements
		await click(ui.replace_buttons[slot].position + Vector2(58, 21))
		if not await wait_state("draft"): return
		check(ui.battle.replacements == count + 1, "乱序调整真实交换 " + str(slot))
		check(ui.battle.hand.size() + ui.battle.deck.size() + ui.battle.discard.size() == 16, "乱序调整牌数守恒")
		check(ui.battle.hand.has("tieshan_strong") and ui.battle.hand.has("tieshan_guard"), "后台保留关键起手")
	var snapshot: Dictionary = ui.battle.duplicate(true)
	await click(ui.replace_buttons[3].position + Vector2(58, 21))
	check(ui.battle == snapshot, "调整三次后隐藏按钮不可继续支付")
	await capture("readable_draft")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/card_display_02/%d_readable_draft.png" % root.size.x)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://output/card_display_02")
	DirAccess.make_dir_recursive_absolute("res://output/bt_ui_02")
	DirAccess.make_dir_recursive_absolute("res://output/bt_fx_01")
	root.size = Vector2i(1152, 648) if OS.get_cmdline_user_args().has("small") else Vector2i(1280, 720)
	for active in [false, true]:
		expected_condition = active
		condition_case = "active" if active else "inactive"
		change_scene_to_file("res://scenes/battle/yaya_battle_demo.tscn")
		await scene_changed
		scene = current_scene
		ui = scene.get_child(0)
		if not await wait_state("draft"): finish(); return
		await create_timer(0.5).timeout
		if not active: await draft_checks()
		await click(ui.confirm_button.position + Vector2(120, 28))
		if not await wait_state("player_turn"): finish(); return
		if not await select_card("tieshan_strong"): finish(); return
		await click(ui.role_nodes.tieshan.position + Vector2(58, 35))
		if not await wait_state("player_turn"): finish(); return
		# 独立验收样例只调整事务前战斗位，随后仍用真实鼠标走正式事务。
		if active:
			ui.battle.zones.player = "yaya"
			ui._sync()
		if not await select_card("tieshan_guard"): finish(); return
		var ap: int = ui.battle.ap
		var satiety: int = ui.battle.characters.tieshan.satiety
		await click(ui.role_nodes.tieshan.position + Vector2(58, 35))
		if not await wait_state("player_turn"): finish(); return
		check(ui.battle.ap == ap - 1 and ui.battle.characters.tieshan.satiety == satiety - 1, "正式使用仍扣1AP/1饱腹 " + condition_case)
		check(ui.battle.enemy_hp == (3 if active else 6), "条件规则结算保持 " + condition_case)
		check(ui.board.get_node_or_null("SkillResolutionCard") == null, "使用展示结束清理 " + condition_case)
		check(ui.role_nodes.tieshan.get_node("Portrait/TemplateCard")._material_stat_attack.text == "2", "角色临时攻击恢复 " + condition_case)
	expected_condition = false
	condition_case = "full"
	await super.run()

func finish() -> void:
	FileAccess.open("res://output/card_display_02/%d_scene_report.json" % root.size.x, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "casts": observed_casts.size(), "evidence": evidence, "user_data_dir": OS.get_user_data_dir()}, "\t"))
	super.finish()
