extends SceneTree
## 实际场景 + Input.parse_input_event（输入事件注入）驱动，不直接调用出牌/结束事务。
const Rules = preload("res://scripts/battle/tutorial_rules.gd")
var scene: Control
var ui: Control
var checks := 0
var failures: Array[String] = []
var evidence: Array = []
var started := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
	return value

func wait_state(value: String, seconds := 12.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while is_instance_valid(ui) and ui.state != value and Time.get_ticks_msec() < until:
		if value == "player_turn" and ui.state == "guide_explain":
			await read_guide()
			# 逐句输入的阅读时间不计入演出状态超时。
			until = Time.get_ticks_msec() + int(seconds * 1000)
		await process_frame
	return check(is_instance_valid(ui) and ui.state == value, "等待场景状态 %s，实际%s" % [value, ui.state if is_instance_valid(ui) else "已释放"])

func guide_key(down: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = down
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame

func read_guide() -> void:
	# 适配真实对白输入；不跳教学、不直接调用 _advance 或战斗业务。
	var limit := Time.get_ticks_msec() + 15000
	while is_instance_valid(ui) and ui.state == "guide_explain" and Time.get_ticks_msec() < limit:
		await guide_key(false)
		await guide_key(true)
		await guide_key(false)
		await create_timer(0.04).timeout
	check(is_instance_valid(ui) and ui.state == "player_turn", "逐句对白完成后只开放本步操作")

func click(point: Vector2) -> void:
	var global: Vector2 = ui.board.get_global_transform_with_canvas() * point
	var move := InputEventMouseMotion.new()
	move.position = global
	Input.parse_input_event(move)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = global
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	# 新显示的容器需要完成布局后，才能读取下一个按钮的真实矩形。
	await create_timer(0.2).timeout

func drag(point: Vector2, destination: Vector2) -> void:
	var start: Vector2 = ui.board.get_global_transform_with_canvas() * point
	var end: Vector2 = ui.board.get_global_transform_with_canvas() * destination
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = start
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.relative = end - start
	Input.parse_input_event(motion)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = end
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame

func capture(label: String) -> void:
	await create_timer(1.0).timeout # 等待数值飘字收起，保留可读的稳定画面。
	for hud in [ui.player_hud, ui.enemy_hud]:
		check(hud.hp_label.text == str(maxi(0, hud.hp)), "牌手生命数字同步 " + label)
		for i in range(2):
			check(is_equal_approx(hud.ready_spoons[i].modulate.a, 1.0 if i < hud.points else 0.0), "瓷勺行动点同步 %s/%d" % [label, i])
	var visible_roles: Array[Rect2] = []
	for id in ui.role_nodes:
		var field: Control = ui.role_nodes[id]
		if not field.visible or not field.get_node("Portrait").visible: continue
		var rect := Rect2(field.position, field.size)
		var frame_rect := SproutCard.MATERIAL.edge_rect("frame")
		var visible_rect := Rect2(field.position + frame_rect.position * field.size / SproutCard.CARD_SIZE, frame_rect.size * field.size / SproutCard.CARD_SIZE)
		check(Rect2(Vector2.ZERO, ui.CANVAS).encloses(visible_rect), "角色可见卡框完整位于画布 " + id)
		check(not rect.intersects(Rect2(ui.player_hud.position, ui.player_hud.size)) and not rect.intersects(Rect2(ui.enemy_hud.position, ui.enemy_hud.size)), "角色不遮挡头像 " + id)
		for other in visible_roles: check(not rect.intersects(other), "角色槽位无重叠 " + id)
		visible_roles.append(rect)
		var template: SproutCard = field.get_node("Portrait/TemplateCard")
		var expected_art: String = ui.tutorial_art.get(ui.card_data(id).id, "")
		if not expected_art.is_empty(): check(template._material_art.texture.resource_path == expected_art, "角色使用新版对应插画 " + id)
		var paragraph := TextParagraph.new()
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.width = template._material_effect.size.x - template.EFFECT_TEXT_INSET * 2
		paragraph.add_string(template._material_effect.text, SproutTheme.FONT_CN, template._material_effect.get_theme_font_size("font_size"))
		check(paragraph.get_size().y <= template._material_effect.size.y, "放大技能正文不超框 " + id)
		check(is_equal_approx(template._material_effect.position.x, template.CARD_SIZE.x - template._material_effect.position.x - template._material_effect.size.x), "正文左右留白对称 " + id)
		var content_rect := Rect2(template._material_effect.position + Vector2(template.EFFECT_TEXT_INSET, 0), template._material_effect.size - Vector2(template.EFFECT_TEXT_INSET * 2, 0))
		if template._shield_art.visible:
			check(not content_rect.intersects(Rect2(template._shield_art.position, template._shield_art.size)), "正文安全区不与护盾重叠 " + id)
	check(ui._prepare_position("slime_a").y < ui._role_position(false, true).y and ui._prepare_position("yaya").y > ui._role_position(true, true).y, "准备区位于战斗区外侧")
	check(is_equal_approx(ui._role_position(false, true).y - ui._prepare_position("slime_a").y, ui._prepare_position("yaya").y - ui._role_position(true, true).y), "准备区错层距离上下对称")
	check(is_equal_approx(ui._prepare_position("yaya").x + ui._prepare_position("tieshan").x + ui.ROLE_SIZE.x, 1320), "我方左右对称")
	check(is_equal_approx(ui._prepare_position("slime_a").x + ui._prepare_position("slime_b").x + ui.ROLE_SIZE.x, 1320), "敌方左右对称")
	if ui.battle.characters.has("slime_b2"):
		check(ui._prepare_position("slime_a2").x < ui._prepare_position("slime_a1").x and ui._prepare_position("slime_b2").x > ui._prepare_position("slime_b1").x, "四名敌方左右各二，固定血脉槽位")
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://output/bt_ui_02/%s_%s.png" % [str(root.size.x), label]
	var result := root.get_texture().get_image().save_png(path)
	check(result == OK, "实际渲染截图 " + label)
	evidence.append({"label": label, "path": path, "state": ui.battle.duplicate(true)})

func select_card(id: String) -> bool:
	# 每张牌的左侧露出区直接命中，保留原扇形，不先展开整组。
	await click(Vector2(300, 600))
	var index: int = ui.hand_cards.find(id)
	if not check(index >= 0, "手牌存在 " + id): return false
	var card: Control = ui.hand_nodes[index]
	await click(card.position + Vector2(16, 25))
	await create_timer(0.25).timeout
	check(not ui.hand_expanded and ui.preview.visible, "选单牌保留扇形并显示完整预览")
	check(not ui.preview_text.get_parent().visible and not ui.guide.dialog.visible, "预览无旁侧重复说明")
	check(card.position.y < ui._hand_pose(index, ui.hand_nodes.size()).position.y, "所选单牌凸出")
	for i in range(ui.hand_nodes.size()):
		if i != index: check(ui.hand_nodes[i].position.is_equal_approx(ui._hand_pose(i, ui.hand_nodes.size()).position), "未选手牌保持原扇形槽位")
	if evidence.filter(func(item): return item.label == "single_card").is_empty(): await capture("single_card")
	return check(ui.selected >= 0 and ui.hand_cards[ui.selected] == id, "点击选中 " + id)

func run() -> void:
	started = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute("res://output/bt_ui_02")
	var resolution := Vector2i(1280, 720)
	if OS.get_cmdline_user_args().has("small"): resolution = Vector2i(1152, 648)
	root.size = resolution
	change_scene_to_file("res://scenes/start_screen.tscn")
	await scene_changed
	await create_timer(0.5).timeout
	var entry: Button = current_scene.battle_button
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = entry.get_global_rect().get_center()
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await scene_changed
	scene = current_scene
	check(scene.scene_file_path == "res://scenes/battle/yaya_battle_demo.tscn", "真实开始页鼠标入口")
	ui = scene.get_child(0)
	await create_timer(1.45).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/bt_ui_02/%d_initiative.png" % root.size.x)
	if not await wait_state("draft"): finish(); return
	check(ui.initiative_player_first, "教学固定我方先手")
	await create_timer(0.5).timeout
	await capture("draft")
	# 起手最后一张关键牌也走真实点击、换牌按钮及动画；无后台锁牌文案。
	await click(ui.draft_cards[0].position + Vector2(95, 100))
	await click(ui.replace_buttons[0].position + Vector2(58, 21))
	if not await wait_state("draft"): finish(); return
	check(ui.battle.replacements == 1 and ui.battle.hand.has("tieshan_strong") and ui.battle.hand.has("tieshan_guard"), "真实换牌保持关键起手")
	check(not ui.draft_hint.text.contains("锁") and not ui.draft_hint.text.contains("强力"), "无后台保障提示")
	await click(ui.confirm_button.position + Vector2(120, 28))
	if not await wait_state("player_turn"): finish(); return
	check(ui.battle.hand.size() == 6 and ui.battle.draw_count == 1 and ui.battle.characters.yaya.mana == 4, "第1回合真实抽牌与魔力")
	await capture("turn_1")
	# 菜单确认窗取消后恢复输入，且不改变战斗。
	var menu_snapshot: Dictionary = ui.battle.duplicate(true)
	await click(ui.battle_menu.gear.position + Vector2(24, 24))
	check(ui.battle_menu.is_open and paused, "战斗菜单暂停")
	var restart: Control = ui.battle_menu.restart_button
	var menu_point: Vector2 = ui.board.get_global_transform_with_canvas().affine_inverse() * restart.get_global_rect().get_center()
	await click(menu_point)
	check(ui.battle_menu.confirmation.visible, "重开确认窗可见")
	await capture("menu_confirmation")
	var cancel: Control = ui.battle_menu.confirmation.cancel_button
	menu_point = ui.board.get_global_transform_with_canvas().affine_inverse() * cancel.get_global_rect().get_center()
	await click(menu_point)
	check(not paused and not ui.battle_menu.is_open and ui.battle == menu_snapshot, "取消恢复输入且状态不变")
	# 确认重开后创建新场景，旧异步流程与旧输入不再生效。
	var old_scene := scene
	await click(ui.battle_menu.gear.position + Vector2(24, 24))
	restart = ui.battle_menu.restart_button
	menu_point = ui.board.get_global_transform_with_canvas().affine_inverse() * restart.get_global_rect().get_center()
	await click(menu_point)
	var accept: Control = ui.battle_menu.confirmation.confirm_button
	menu_point = ui.board.get_global_transform_with_canvas().affine_inverse() * accept.get_global_rect().get_center()
	await click(menu_point)
	await process_frame
	scene = current_scene
	ui = scene.get_child(0)
	if not await wait_state("draft"): finish(); return
	check(not is_instance_valid(old_scene) and not paused and ui.battle.turn == 0 and ui.battle.draw_count == 0, "确认重开释放旧场景并重置回合")
	await click(ui.confirm_button.position + Vector2(120, 28))
	if not await wait_state("player_turn"): finish(); return
	# 场景里尝试乱序、非法目标、资源不足，快照必须不变。
	var snapshot: Dictionary = ui.battle.duplicate(true)
	if not await select_card("tieshan_guard"): finish(); return
	await click(ui.role_nodes.tieshan.position + Vector2(58, 35))
	check(ui.battle == snapshot, "场景乱序原子拒绝")
	if not await select_card("tieshan_strong"): finish(); return
	await click(ui.role_nodes.yaya.position + Vector2(58, 35))
	check(ui.battle == snapshot, "场景非法目标原子拒绝")
	ui.battle.ap = 0
	ui._sync()
	snapshot = ui.battle.duplicate(true)
	if not await select_card("tieshan_strong"): finish(); return
	await click(ui.role_nodes.tieshan.position + Vector2(58, 35))
	check(ui.battle == snapshot, "场景行动点不足原子拒绝")
	ui.battle.ap = 2
	ui._sync()
	ui.battle.characters.tieshan.satiety = 0
	snapshot = ui.battle.duplicate(true)
	if not await select_card("tieshan_strong"): finish(); return
	await click(ui.role_nodes.tieshan.position + Vector2(58, 35))
	check(ui.battle == snapshot, "场景饱腹不足原子拒绝")
	ui.battle.characters.tieshan.satiety = 8
	ui._sync()
	if not await select_card("tieshan_strong"): finish(); return
	snapshot = ui.battle.duplicate(true)
	var hand_card: Control = ui.hand_nodes[ui.selected]
	await drag(hand_card.position + Vector2(16, 25), Vector2(1200, 500))
	check(ui.battle == snapshot and ui.selected == -1 and not ui.dragging, "取消拖牌恢复输入且不消耗资源")
	for turn in range(1, 9):
		if turn == 8:
			var held_key := InputEventKey.new()
			held_key.keycode = KEY_E
			held_key.pressed = true
			Input.parse_input_event(held_key)
			await process_frame
		for action in Rules.STEPS[turn - 1]:
			var before_step: int = ui.battle.step
			if action == "attack":
				var at: Vector2 = ui.role_nodes.tieshan.position + Vector2(58, 70)
				var before_cancel: Dictionary = ui.battle.duplicate(true)
				await drag(at, at + Vector2(0, 20))
				check(ui.battle == before_cancel and not ui.attack_selected, "取消普通出击不消耗资源")
				await drag(at, at + Vector2(0, -80))
			else:
				if not await select_card(action): finish(); return
				var target := "slime_a" if action == "yaya_magic_hit" else ("slime_a2" if action == "yaya_magic_wind" else "tieshan")
				await click(ui.role_nodes[target].position + Vector2(58, 35))
			if not await wait_state("result" if turn == 8 else "player_turn"): finish(); return
			if not check(ui.battle.step == before_step + 1, "真实输入推进第%d回合 %s" % [turn, action]): finish(); return
			var c: Dictionary = ui.battle.characters.tieshan
			var card: SproutCard = ui.role_nodes.tieshan.get_node("Portrait/TemplateCard")
			check(card._material_stat_health.text == str(c.hp) and card._material_stat_attack.text == str(Rules.attack_value(c)), "动态牌面同步")
		if turn == 8: break
		await capture("turn_%d_done" % turn)
		await click(ui.end_button.position + Vector2(35, 49))
		if not await wait_state("player_turn"): finish(); return
		check(ui.battle.turn == turn + 1 and ui.battle.draw_count == turn + 1, "真实结束按钮及后续每回合抽一张")
	check(ui.battle.player_hp == 26 and ui.battle.enemy_hp == 0, "8回合最终26/0")
	check(ui.battle.characters.tieshan.hp == 8 and ui.battle.characters.yaya.alive, "铁山8血与芽芽存活")
	check(ui.battle.characters.slime_a.revive == 1, "史莱姆A尚未复活")
	var until := Time.get_ticks_msec() + 6000
	while not ui.result_ready and Time.get_ticks_msec() < until: await process_frame
	check(ui.result_ready, "胜利动画与按E继续就绪")
	check(not ui.result_armed and current_scene == scene, "胜利前按住E不会穿透或提前返回")
	await capture("victory")
	# 演出结束后新按E返回；使用真实键盘事件。
	for down in [false, true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = down
		Input.parse_input_event(key)
		await process_frame
	var return_until := Time.get_ticks_msec() + 6000
	while (current_scene == null or current_scene.scene_file_path != "res://scenes/start_screen.tscn") and Time.get_ticks_msec() < return_until:
		await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/start_screen.tscn" and not paused, "胜利后新按E返回且无暂停残留")
	# 结束战斗走同一确认/失败演出，状态与画面生命一致。
	change_scene_to_file("res://scenes/battle/yaya_battle_demo.tscn")
	await scene_changed
	scene = current_scene
	ui = scene.get_child(0)
	if not await wait_state("draft"): finish(); return
	await click(ui.battle_menu.gear.position + Vector2(24, 24))
	var finish_button: Control = ui.battle_menu.finish_button
	menu_point = ui.board.get_global_transform_with_canvas().affine_inverse() * finish_button.get_global_rect().get_center()
	await click(menu_point)
	accept = ui.battle_menu.confirmation.confirm_button
	menu_point = ui.board.get_global_transform_with_canvas().affine_inverse() * accept.get_global_rect().get_center()
	await click(menu_point)
	if not await wait_state("result"): finish(); return
	check(ui.battle.player_hp == 0 and ui.battle.winner == "enemy" and ui.player_hud.hp == 0, "结束战斗按失败结算且生命显示一致")
	until = Time.get_ticks_msec() + 6000
	while not ui.result_ready and Time.get_ticks_msec() < until: await process_frame
	check(ui.result_ready and not paused, "失败演出就绪且无暂停残留")
	await capture("defeat")
	finish()

func finish() -> void:
	var path := "res://output/bt_ui_02/scene_report_%d.json" % root.size.x
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence, "user_data_dir": OS.get_user_data_dir(), "elapsed_ms": Time.get_ticks_msec() - started}, "\t"))
	file.close()
	print("CARD_TUTORIAL_SCENE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
