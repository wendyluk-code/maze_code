extends "res://scripts/battle/yaya_battle_demo.gd"
## CARD-TUTORIAL-01：复用原战场、签牌、手牌动画、菜单与结果演出。

const Rules = preload("res://scripts/battle/tutorial_rules.gd")
var battle: Dictionary
var role_nodes: Dictionary = {}
var active_role := ""
var last_events: Array = []
var tutorial_art: Dictionary = {}
var pending_splits: Dictionary = {}
const BattleGuide = preload("res://scripts/battle/battle_guide.gd")
const GuideSteps = preload("res://scripts/battle/battle_guide_steps.gd")
var guide: Control
var guide_key := ""
var split_phase := ""
var split_generation := 0
var split_tween: Tween
const READABLE_DRAFT_SIZE := Vector2(228, 380)

func _update_draft() -> void:
	super._update_draft()
	# 五张完整卡面居中一排；选中只轻抬，不压住相邻卡面或调整按钮。
	for i in range(draft_cards.size()):
		var current := i == draft_selected and state == "draft"
		var card := draft_cards[i]
		card.size = READABLE_DRAFT_SIZE
		card.pivot_offset = READABLE_DRAFT_SIZE * 0.5
		card.position = Vector2(38 + i * 244, 174 if current else 190)
		card.scale = Vector2.ONE * (1.025 if current else 1.0)
		card.get_node("Art").size = READABLE_DRAFT_SIZE
		card.get_node("Glow").size = READABLE_DRAFT_SIZE + Vector2(6, 6)
		replace_buttons[i].position = Vector2(94 + i * 244, 594)
	confirm_button.position.y = 652

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var art_file := FileAccess.open("res://data/battle/tutorial_art.json", FileAccess.READ)
	if art_file:
		var parsed = JSON.parse_string(art_file.get_as_text())
		if parsed is Dictionary: tutorial_art = parsed.get("illustrations", {})
	battle = Rules.new_state()
	theme = SproutTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	board = Control.new()
	board.size = CANVAS
	board.clip_contents = true
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	resized.connect(_fit)
	_fit()
	_build_board()
	guide = BattleGuide.new()
	board.add_child(guide)
	guide.explanation_finished.connect(_guide_practice)
	guide.sentence_changed.connect(func(_focus: String): _refresh_guide())
	# 敌方牌手与敌方角色分开；头像用已有怪物精灵，不使用芽芽冒充。
	var avatar := enemy_hud.get_node("Avatar") as TextureRect
	avatar.texture = _monster_portrait()
	avatar.material = null # 既有头像UV圆裁切着色器不适用于图集区域。
	_sync()
	_opening()

func _monster_portrait() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/monsters/slime/slime_crawl_4directions.png")
	atlas.region = Rect2(0, 0, atlas.atlas.get_width() / 4.0, atlas.atlas.get_height() / 4.0)
	return atlas

func _begin_guide_step() -> void:
	guide_key = "%d:%d" % [battle.turn, battle.step]
	_cancel_selection()
	state = "guide_explain"
	_update_hud()
	guide.begin(GuideSteps.lines(battle.turn, battle.step))
	_refresh_guide()

func _guide_practice() -> void:
	if ending_early or state != "guide_explain": return
	state = "player_turn"
	var action := Rules.expected(battle)
	var instruction := "点击结束回合" if action == "end" else ("向上拖动铁山出击\n拖回原处或右键取消" if action == "attack" else "选择%s，再点击%s\n右键可取消" % [Rules.data()[action].title, "史莱姆A" if action == "yaya_magic_hit" else ("敌方角色" if action == "yaya_magic_wind" else "铁山")])
	guide.practice(instruction)
	_update_hud()
	_refresh_guide()

func _process(_delta: float) -> void:
	if not is_instance_valid(guide) or not guide.visible: return
	# 菜单继承原暂停；孔洞按实际变换同步，不把角色或预览抬到遮罩前面。
	_refresh_guide()

func _guide_rect(node: Control, margin := 6.0) -> Rect2:
	var transform := board.get_global_transform_with_canvas().affine_inverse() * node.get_global_transform_with_canvas()
	return (transform * Rect2(Vector2.ZERO, node.size)).grow(margin).intersection(Rect2(Vector2.ZERO, CANVAS))

func _guide_role(id: String) -> Rect2:
	return _guide_rect(role_nodes[id], 8) if role_nodes.has(id) else Rect2()

func _refresh_guide() -> void:
	if not is_instance_valid(guide) or not guide.visible: return
	var rects: Array[Rect2] = []
	var point := Rect2()
	var focus: String = guide.focus
	if guide.explaining:
		var tieshan: SproutCard = role_nodes.tieshan.get_node("Portrait/TemplateCard")
		var yaya: SproutCard = role_nodes.yaya.get_node("Portrait/TemplateCard")
		match focus:
			"health":
				rects.assign([_guide_rect(player_hud), _guide_rect(enemy_hud)])
			"enemy": rects.append(_guide_rect(enemy_hud))
			"ap":
				for spoon in player_hud.ready_spoons: rects.append(_guide_rect(spoon, 8))
			"stats":
				rects.assign([_guide_rect(tieshan._material_stat_attack, 12), _guide_rect(tieshan._material_stat_health, 12)])
			"shield": rects.append(_guide_rect(tieshan._shield_art, 5))
			"resources": rects.assign([_guide_rect(tieshan._satiety_slot, 12), _guide_rect(yaya._mana_slot, 12)])
			"zones": rects.assign([_guide_role("tieshan"), _guide_rect(combat_slots[1])])
			"yaya": rects.append(_guide_role("yaya"))
			"tieshan": rects.append(_guide_role("tieshan"))
			"allies": rects.assign([_guide_role("yaya"), _guide_role("tieshan")])
			"slimes":
				for id in role_nodes:
					if battle.characters[id].side == "enemy" and role_nodes[id].visible:
						rects.append(_guide_rect(role_nodes[id], 20))
			"end": rects.append(_guide_rect(end_button))
			"hand":
				var index := hand_cards.find(Rules.expected(battle))
				if index >= 0: rects.append(_guide_rect(hand_nodes[index], 5))
	else:
		var action := Rules.expected(battle)
		if action == "end":
			rects.append(_guide_rect(end_button))
		elif action == "attack":
			rects.append(_guide_role("tieshan"))
			rects.append(_guide_rect(combat_slots[1]))
		else:
			var index := hand_cards.find(action)
			if selected >= 0:
				if action == "yaya_magic_hit": rects.append(_guide_role("slime_a"))
				elif action == "yaya_magic_wind":
					for id in role_nodes:
						if battle.characters[id].side == "enemy" and battle.characters[id].alive: rects.append(_guide_role(id))
				else: rects.append(_guide_role("tieshan"))
			elif index >= 0:
				# 露出的左上部分就是实际点击区，避免指针指到扇形下的邻牌。
				var card := _guide_rect(hand_nodes[index], 2)
				point = Rect2(card.position, Vector2(25, mini(60, card.size.y)))
			rects.append(Rect2(930, 532, 280, 188))
			if preview.visible: rects.append(_guide_rect(preview, 3))
			if is_instance_valid(drag_card): rects.append(_guide_rect(drag_card))
	if not point.has_area() and not rects.is_empty(): point = rects[0]
	if focus in ["slimes", "ap"] and guide.explaining:
		# 分裂槽位在母体两侧；指示放在整个敌阵外缘，避免压住相邻子体。
		for rect in rects: point = point.merge(rect)
	rects.append(_guide_rect(battle_menu.gear))
	guide.highlight(rects, point)

func card_data(id: String) -> CardData:
	if id == "芽芽": id = "yaya"
	var source := id
	var c: Dictionary = battle.characters.get(id, {}) if battle else {}
	if not c.is_empty(): source = c.form if not c.form.is_empty() else c.source
	var raw: Dictionary = Rules.data()[source].duplicate(true)
	var art_path := str(tutorial_art.get(source, ""))
	if not art_path.is_empty(): raw["illustration_path"] = art_path
	raw["portrait"] = _monster_portrait() if raw.faction == "monster" else null
	# 怪物复用同一已批准卡框，已有精灵作为插画；后续美术只替换插画引用。
	if raw.faction == "monster":
		raw["material_path"] = "res://assets/ui/battle/cards/yaya/yaya.png"
		raw["illustration_override"] = _monster_portrait()
	if not c.is_empty():
		raw["is_role_card"] = true
		raw["card_type"] = "角色牌" if c.form.is_empty() else "赋形牌"
		raw["character_name"] = _role_name(id) if raw.faction == "monster" else Rules.data()[c.source].character_name
		raw["title"] = _role_name(id)
		raw["satiety_max"] = c.satiety_max
		raw["mana_enabled"] = c.mana >= 0
		if not c.form.is_empty(): raw["effect"] += "\n" + Rules.data()[c.source].effect
	return CardData.new(raw)

func _card_data(id: String) -> CardData:
	# 起手牌和战斗手牌沿用父类的共享模板节点，数据统一读取教学规则。
	return card_data(id)

func _card(parent: Node, id: String, rect: Rect2) -> Control:
	var card := super._card(parent, id, rect)
	var view: SproutCard = card.get_node("TemplateCard")
	view.set_readable_battle_text(true)
	card.resized.connect(func(): view.scale = card.size / CardView.CARD_SIZE)
	return card

func _role_name(id: String) -> String:
	var names := {"yaya": "芽芽", "tieshan": "铁山", "slime_a": "史莱姆A", "slime_b": "史莱姆B", "slime_a1": "小小史莱姆A1", "slime_a2": "小小史莱姆A2", "slime_b1": "小小史莱姆B1", "slime_b2": "小小史莱姆B2"}
	return names.get(id, id)

func _art(parent: Node, id: String, rect: Rect2) -> Control:
	var wrapper := Control.new()
	wrapper.position = rect.position
	wrapper.size = rect.size
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(wrapper)
	var view := CardView.new()
	view.name = "TemplateCard"
	view.configure(card_data(id))
	view.set_readable_battle_text(true)
	view.set_battle_context(battle.characters.has(id))
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(view)
	view.resized.connect(func(): view.scale = wrapper.size / CardView.CARD_SIZE)
	wrapper.resized.connect(func(): view.scale = wrapper.size / CardView.CARD_SIZE)
	view.scale = rect.size / CardView.CARD_SIZE
	return wrapper

func _make_field(enemy: bool, at: Vector2) -> Control:
	return _new_role("slime_a" if enemy else "yaya", at)

func _new_role(id: String, at: Vector2) -> Control:
	var field := Control.new()
	field.position = at
	field.size = ROLE_SIZE
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.pivot_offset = ROLE_SIZE * 0.5
	battlefield.add_child(field)
	var art := _art(field, id, Rect2(Vector2.ZERO, ROLE_SIZE))
	art.name = "Portrait"
	var tag := _text(field, "", Rect2(-8, -24, ROLE_SIZE.x + 16, 23), 14, INK, true)
	tag.name = "Tag"
	role_nodes[id] = field
	return field

func _prepare_position(id: String) -> Vector2:
	# 固定血脉槽位：分裂体替代父体，阵亡不压缩其他角色的位置。
	var xs := {"yaya": 400, "tieshan": 752, "slime_a": 400, "slime_b": 752,
		"slime_a1": 400, "slime_a2": 222, "slime_b1": 752, "slime_b2": 930}
	# 双方围绕y=360镜像，准备区比同方战斗区向外错开48像素。
	return Vector2(xs[id], 412 if battle.characters[id].side == "player" else 28)

func _sync() -> void:
	hand_cards.assign(battle.hand)
	deck.assign(battle.deck)
	discard.assign(battle.discard)
	player_hp = battle.player_hp
	enemy_hp = battle.enemy_hp
	action_point = battle.ap
	enemy_action_point = battle.enemy_ap
	round_number = battle.turn
	turn_owner_player = battle.owner == "player"
	for id in battle.characters:
		if not role_nodes.has(id): _new_role(id, _prepare_position(id))
		var c: Dictionary = battle.characters[id]
		var field: Control = role_nodes[id]
		# 规则事务已经提交，演出拥有这些角色的首次显隐和位置。
		var split_parent: String = id if pending_splits.has(id) else c.parent
		if pending_splits.has(split_parent):
			if id == split_parent:
				(field.get_node("Tag") as Label).text = "等待分裂体" if c.revive < 0 else "复活 %d" % c.revive
			elif split_phase != "separating": field.hide()
			continue
		var replaced: bool = c.source == "slime" and not c.alive and battle.characters.has(id + "1")
		var retired_child: bool = not c.parent.is_empty() and battle.characters[c.parent].alive
		field.visible = not retired_child
		field.get_node("Portrait").visible = not replaced
		# 父体的复活反馈保留在牌外，父体不再占用分裂体卡面。
		var tag: Label = field.get_node("Tag")
		tag.position.y = -44 if replaced else -18
		field.position = _role_position(c.side == "player", true) if battle.zones[c.side] == id else _prepare_position(id)
		field.modulate = Color.WHITE if c.alive else Color(0.65, 0.65, 0.65, 0.55)
		var view: SproutCard = field.get_node("Portrait/TemplateCard")
		view.configure(card_data(id))
		view.set_battle_state({"attack": Rules.attack_value(c), "hp": c.hp, "satiety": c.satiety, "mana": c.mana, "shield": c.shield})
		var status := ""
		if not c.alive:
			status = "等待分裂体" if c.revive < 0 else ("复活 %d" % c.revive if c.revive > 0 else "已阵亡")
		elif c.satiety == 0: status = "饥饿"
		if c.alive and c.shield > 0:
			status += (" · " if not status.is_empty() else "") + "护盾%d" % c.shield
		(field.get_node("Tag") as Label).text = status
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(end_button) or battle == null: return
	var active := state == "player_turn"
	player_hud.sync(battle.player_hp, battle.ap, battle.owner == "player" and state != "draft")
	enemy_hud.sync(battle.enemy_hp, battle.enemy_ap, battle.owner == "enemy")
	end_button.disabled = not active
	end_button.text = "结束\n回合" if active or state == "guide_explain" else ("敌方\n回合" if state == "enemy_turn" else "请稍候")
	if is_instance_valid(battle_menu): battle_menu.gear.disabled = state == "result" or ending_early

func _replace_card(index: int) -> void:
	if state != "draft" or index != draft_selected: return
	var result := Rules.replace(battle, index)
	if not result.success: return
	state = "replacing"
	_update_draft()
	var card := draft_cards[index]
	var out := _battle_tween()
	out.tween_property(card, "scale:x", 0.02, 0.16)
	await out.finished
	if ending_early: return
	hand_cards.assign(battle.hand)
	(card.get_node("TemplateCard") as SproutCard).configure(card_data(hand_cards[index]))
	var intro := _battle_tween()
	intro.tween_property(card, "scale:x", 1.0, 0.22)
	await intro.finished
	if ending_early: return
	replace_count = battle.replacements
	state = "draft"
	_update_draft()

func _playable(index: int) -> String:
	if index < 0 or index >= hand_cards.size(): return "请选择手牌"
	var id := hand_cards[index]
	var target := "slime_a" if id == "yaya_magic_hit" else ("slime_a2" if id == "yaya_magic_wind" else "tieshan")
	return Rules.validate(battle, id, target)

func _layout_hand() -> void:
	super._layout_hand()

func _show_preview(id: String, reason := "") -> void:
	if hand_expanded:
		preview.hide()
		return
	var view: SproutCard = preview_art.get_node("TemplateCard")
	view.configure(card_data(id))
	view.set_battle_context(battle.characters.has(id))
	if battle.characters.has(id):
		var c: Dictionary = battle.characters[id]
		view.set_battle_state({"attack": Rules.attack_value(c), "hp": c.hp, "satiety": c.satiety, "mana": c.mana, "shield": c.shield})
	else: view.set_battle_state({})
	var d := card_data(id)
	preview_text.text = "%s\n%s\n\n%s" % [d.title, d.card_type, d.effect]
	if battle.characters.has(id):
		var c: Dictionary = battle.characters[id]
		preview_text.text = "%s\n攻击%d · 生命%d/%d\n护盾%d\n饱腹%s · 魔力%s\n\n%s" % [d.title, Rules.attack_value(c), c.hp, c.max_hp, c.shield, str(c.satiety) if c.satiety >= 0 else "—", str(c.mana) if c.mana >= 0 else "—", d.effect]
	if not reason.is_empty(): preview_text.text += "\n\n" + reason
	preview.show()

func _start_player_turn(_first := false) -> void:
	state = "turn_intro"
	var before: Array = battle.hand.duplicate()
	Rules.begin_turn(battle, "player")
	_sync()
	await _banner("我 方 回 合", GREEN)
	if ending_early: return
	if battle.hand.size() > before.size():
		var id: String = battle.hand.back()
		var fly := _art(board, id, Rect2(_deck_position(true), DECK_SIZE))
		fly.z_index = 160
		var draw := _battle_tween().set_parallel(true)
		draw.tween_property(fly, "position", _hand_pose(battle.hand.size() - 1, battle.hand.size()).position, 0.36)
		draw.tween_property(fly, "size", HAND_SIZE, 0.36)
		await draw.finished
		if ending_early: return
		fly.queue_free()
	state = "player_turn"
	_sync()
	_rebuild_hand()
	_begin_guide_step()

func _end_turn() -> void:
	if state != "player_turn": return
	var result := Rules.transact(battle, "end")
	if not result.success:
		_toast(result.reason)
		return
	state = "ending"
	guide.cancel()
	_cancel_selection()
	_sync()
	await _enemy_turn()

func _enemy_turn() -> void:
	state = "enemy_turn"
	Rules.begin_turn(battle, "enemy")
	_sync()
	await _banner("敌 方 回 合", RED)
	if ending_early: return
	var actor: String = Rules.ENEMY_ACTORS[battle.turn - 1]
	battle.events = []
	battle.enemy_ap -= 1
	battle.characters[actor].acted = true
	Rules.strike(battle, actor)
	last_events = battle.events.duplicate(true)
	_stage_splits(last_events)
	await _show_events(last_events)
	if ending_early: return
	Rules.end_turn(battle, "enemy")
	_sync()
	await _start_player_turn()

func _perform(action: String, target: String) -> void:
	if state != "player_turn": return
	# 只读记录成功使用前的条件；规则事务仍按既有时序结算。
	var conditional_attack_active: bool = action == "tieshan_guard" and battle.zones.player not in ["", "tieshan"]
	var result := Rules.transact(battle, action, target)
	if not result.success:
		_toast(result.reason)
		_cancel_selection()
		return
	state = "resolving"
	guide.cancel()
	last_events = result.events
	_stage_splits(last_events)
	_cancel_selection()
	_sync()
	_rebuild_hand()
	if action != "attack":
		var fly := _art(board, action, Rect2(Vector2(820, 450), HAND_SIZE))
		fly.name = "SkillResolutionCard"
		(fly.get_node("TemplateCard") as SproutCard).set_skill_resolution({"conditional_attack_active": conditional_attack_active})
		fly.z_index = 160
		var cast := _battle_tween().set_parallel(true)
		cast.tween_property(fly, "position", Vector2(800, 300), 0.22)
		cast.tween_property(fly, "modulate:a", 0.0, 0.5)
		_sound(630)
		await cast.finished
		if ending_early: return
		fly.queue_free()
		if action in ["yaya_magic_wind", "yaya_heal_wind"]:
			for id in battle.characters:
				var c: Dictionary = battle.characters[id]
				if c.alive and c.side == ("enemy" if action == "yaya_magic_wind" else "player"):
					fx.burst(role_nodes[id].position + ROLE_SIZE * 0.5, GREEN, true)
	await _show_events(last_events)
	if ending_early: return
	_sync()
	if not battle.winner.is_empty():
		await _result(battle.winner == "player")
		return
	state = "player_turn"
	_update_hud()
	_layout_hand()
	_begin_guide_step()

func _show_events(events: Array) -> void:
	_sync()
	for event in events:
		if event.kind == "strike":
			var field: Control = role_nodes[event.actor]
			# 战斗牌的临时攻击只显示本次出击，随后恢复永久状态。
			var c: Dictionary = battle.characters[event.actor]
			(field.get_node("Portrait/TemplateCard") as SproutCard).set_battle_state({"attack": event.attack, "hp": c.hp, "satiety": c.satiety, "mana": c.mana, "shield": c.shield})
			var at := field.position
			fx.aim_visible = true
			fx.aim_valid = true
			fx.aim_from = field.position + ROLE_SIZE * 0.5
			fx.aim_to = (enemy_hud.position if event.target == "enemy" else player_hud.position) + Vector2(52, 60) if event.target in ["enemy", "player"] else role_nodes[event.target].position + ROLE_SIZE * 0.5
			var tween := _battle_tween()
			tween.tween_property(field, "position:y", at.y + (-18 if c.side == "player" else 18), 0.13)
			tween.tween_property(field, "position", at, 0.17)
			await tween.finished
			if ending_early: return
			fx.burst(fx.aim_to, RED, true)
			fx.aim_visible = false
			_sound(150)
		elif event.kind == "damage" and role_nodes.has(event.target):
			_float(role_nodes[event.target], "−%d / 护盾−%d" % [event.amount, event.absorbed], RED)
		elif event.kind == "slime": _float(role_nodes[event.target], "粘液 · 饱腹−1", GOLD)
	await _animate_splits()
	if ending_early: return
	_sync()
	await get_tree().create_timer(0.25, false).timeout

func _stage_splits(events: Array) -> void:
	# 仅消费本次阵亡事件；同步、复活及群伤的多次刷新不会重新启动。
	for event in events:
		if event.kind != "death": continue
		var id: String = event.target
		if battle.characters[id].source != "slime" or pending_splits.has(id): continue
		pending_splits[id] = role_nodes[id].position
	if not pending_splits.is_empty(): split_phase = "waiting"

func _animate_splits() -> void:
	if pending_splits.is_empty(): return
	var generation := split_generation
	split_phase = "dissolving"
	split_tween = _battle_tween().set_parallel(true)
	for id in pending_splits:
		var portrait: Control = role_nodes[id].get_node("Portrait")
		portrait.pivot_offset = ROLE_SIZE * 0.5
		fx.dissolve(pending_splits[id] + ROLE_SIZE * 0.5, GREEN)
		split_tween.tween_property(portrait, "scale", Vector2(0.18, 0.12), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		split_tween.tween_property(portrait, "modulate:a", 0.0, 0.38)
	await split_tween.finished
	if generation != split_generation or ending_early: return
	split_phase = "separating"
	split_tween = _battle_tween().set_parallel(true)
	for id in pending_splits:
		role_nodes[id].get_node("Portrait").hide()
		for suffix in ["1", "2"]:
			var child: Control = role_nodes[id + suffix]
			child.position = pending_splits[id]
			child.scale = Vector2.ONE * 0.32
			child.modulate = Color.WHITE
			child.modulate.a = 0.0
			child.show()
			split_tween.tween_property(child, "position", _prepare_position(id + suffix), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			split_tween.tween_property(child, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			split_tween.tween_property(child, "modulate:a", 1.0, 0.2)
	await split_tween.finished
	if generation != split_generation or ending_early: return
	_cancel_split_effects()
	_sync()

func _cancel_split_effects() -> void:
	split_generation += 1
	if split_tween and split_tween.is_valid(): split_tween.kill()
	split_tween = null
	for id in pending_splits:
		if not is_instance_valid(role_nodes.get(id)): continue
		var portrait: Control = role_nodes[id].get_node("Portrait")
		portrait.scale = Vector2.ONE
		portrait.modulate = Color.WHITE
		for suffix in ["1", "2"]:
			if role_nodes.has(id + suffix):
				role_nodes[id + suffix].scale = Vector2.ONE
	pending_splits.clear()
	split_phase = ""
	if is_instance_valid(fx): fx.dissolves.clear()

func _exit_tree() -> void:
	if is_instance_valid(guide): guide.cancel()
	_cancel_split_effects()

func _result(victory: bool) -> void:
	guide.cancel()
	_cancel_split_effects()
	_sync()
	await super._result(victory)

func _role_at(point: Vector2) -> String:
	for id in role_nodes:
		if role_nodes[id].visible and role_nodes[id].get_node("Portrait").visible and _hit(role_nodes[id], point): return id
	return ""

func _input(event: InputEvent) -> void:
	if not is_instance_valid(board): return
	if state == "result":
		super._input(event)
		return
	if ending_early or (is_instance_valid(battle_menu) and battle_menu.is_open): return
	if state == "guide_explain":
		# 齿轮仍由原菜单接收；其余输入只翻对白，透明孔洞也不操作背景。
		if event is InputEventMouseButton and _hit(battle_menu.gear, board.get_global_transform_with_canvas().affine_inverse() * event.position): return
		guide.consume(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_selection()
		return
	if event is InputEventMouseMotion:
		pointer = board.get_global_transform_with_canvas().affine_inverse() * event.position
		if state != "player_turn": return
		if held and pointer.distance_to(press_origin) > 12:
			dragging = true
			if selected >= 0 and not is_instance_valid(drag_card):
				drag_card = _art(board, hand_cards[selected], Rect2(pointer - HAND_SIZE * 0.5, HAND_SIZE))
				drag_card.z_index = 160
				hand_expanded = false
				_layout_hand()
		if dragging:
			if is_instance_valid(drag_card): drag_card.position = pointer - HAND_SIZE * 0.5
			fx.aim_visible = true
			fx.aim_from = press_origin
			fx.aim_to = pointer
			fx.aim_valid = _attack_drop_valid(pointer) if attack_selected else (selected >= 0 and Rules.validate(battle, hand_cards[selected], _role_at(pointer)).is_empty())
		else:
			hovered = _hand_at(pointer)
			_layout_hand()
			if hovered >= 0: _show_preview(hand_cards[hovered], _playable(hovered))
			else:
				var id := _role_at(pointer)
				if not id.is_empty(): _show_preview(id)
				else: preview.hide()
		return
	if not event is InputEventMouseButton: return
	pointer = board.get_global_transform_with_canvas().affine_inverse() * event.position
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_selection()
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if state == "draft":
		if event.pressed:
			for i in range(draft_cards.size()):
				if _hit(draft_cards[i], pointer):
					draft_selected = i
					_update_draft()
		return
	if state != "player_turn": return
	if event.pressed:
		if _hit(end_button, pointer) or _hit(battle_menu.gear, pointer): return
		var index := _hand_at(pointer)
		var role := _role_at(pointer)
		if index >= 0:
			_select_card(index)
			held = true
			press_origin = pointer
		elif selected >= 0 and not role.is_empty():
			_perform(hand_cards[selected], role)
		elif not role.is_empty() and battle.characters[role].side == "player":
			var reason := Rules.validate(battle, "attack", role)
			if not reason.is_empty():
				_toast(reason)
				return
			active_role = role
			attack_selected = true
			held = true
			press_origin = pointer
			selected = -1
			hand_expanded = false
			preview.hide()
		else: _cancel_selection()
	else:
		if held and attack_selected:
			var deploy := _attack_drop_valid(pointer)
			if deploy: _perform("attack", active_role)
			else: _cancel_selection()
		elif held and dragging and selected >= 0:
			var role := _role_at(pointer)
			if not role.is_empty(): _perform(hand_cards[selected], role)
			else: _cancel_selection()
		else: held = false

func _restore_role() -> void:
	if battle: _sync()

func _menu_action(action: String) -> void:
	if ending_early or state == "result": return
	if action == "restart":
		_restart_battle()
		return
	battle.player_hp = 0
	battle.winner = "enemy"
	battle.phase = "result"
	_sync()
	await _result(false)

func _restart_battle() -> void:
	ending_early = true
	guide.cancel()
	_cancel_split_effects()
	var fresh := (load("res://scenes/battle/yaya_battle_demo.tscn") as PackedScene).instantiate()
	fresh.return_scene_path = return_scene_path
	var owner_scene := get_parent()
	owner_scene.get_parent().add_child(fresh)
	if get_tree().current_scene == owner_scene: get_tree().current_scene = fresh
	owner_scene.process_mode = Node.PROCESS_MODE_DISABLED
	owner_scene.queue_free()
