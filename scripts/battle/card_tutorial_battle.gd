extends "res://scripts/battle/yaya_battle_demo.gd"
## CARD-TUTORIAL-01：复用原战场、签牌、手牌动画、菜单与结果演出。

const Rules = preload("res://scripts/battle/tutorial_rules.gd")
const CardView = preload("res://scripts/ui/components/sprout_card.gd")
const CardData = preload("res://scripts/ui/components/sprout_card_data.gd")
const LESSONS := [
	"战斗牌会立即出击。强力永久增加攻击；守护获得4护盾，先抵挡伤害。角色底部为攻击与生命，右侧为饱腹度与魔力。左下两枚水滴是行动点。",
	"法术无需出击，也可选择准备区角色。用魔力一击攻击史莱姆A。每次用牌消耗1行动点，并支付牌面饱腹、魔力费用。",
	"赋形直接采用新攻击与生命，保留永久增益和原技能。用坚守不移后，向上拖动铁山普通出击：消耗1行动点、1饱腹。",
	"先用强力，再普通出击。战斗牌不占用全队每回合一次的普通出击；角色交战同时互伤。小小史莱姆阵亡也会触发粘液。",
	"魔力之风伤害所有敌方角色，包括准备区与战斗区。法术不触发粘液。可保留行动点结束回合，未主动行动者恢复2饱腹。",
	"治愈之风治疗全体，溢出转为护盾。随后铁山普通出击。两个分裂体都阵亡后，原史莱姆才开始3回合复活倒计时。",
	"恢复只治疗一个己方角色，溢出不转护盾。为铁山恢复后结束回合，让他休息。饱腹为0时攻击−2、受伤+2，恢复正数即解除。",
	"B2仍在战斗区，普通攻击会被挡住。斧冲直接攻击敌方牌手，本次攻击+2、护盾+1。牌手生命归零立即获胜。"
]
var battle: Dictionary
var role_nodes: Dictionary = {}
var lesson_label: Label
var step_label: Label
var active_role := ""
var last_events: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	_panel(battlefield, Rect2(24, 310, 248, 252), Color(0.99, 0.96, 0.87, 0.93), GOLD)
	step_label = _text(battlefield, "", Rect2(37, 320, 223, 45), 19)
	lesson_label = _text(battlefield, "", Rect2(37, 370, 223, 182), 17)
	lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func card_data(id: String) -> CardData:
	if id == "芽芽": id = "yaya"
	var source := id
	var c: Dictionary = battle.characters.get(id, {}) if battle else {}
	if not c.is_empty(): source = c.form if not c.form.is_empty() else c.source
	var raw: Dictionary = Rules.data()[source].duplicate(true)
	if source == "tieshan_axe": raw["effect"] += "\n本次攻击+2，护盾+1。"
	if source == "tieshan_guard": raw["effect"] += "\n护盾+4。"
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
	if id == "yaya": return _role_position(true, false)
	if id == "tieshan": return _role_position(true, false) + Vector2(-142, 0)
	var order := ["slime_a", "slime_b", "slime_a1", "slime_a2", "slime_b1", "slime_b2"]
	var xs := [435, 293, 151, 775, 917, 1059]
	return Vector2(xs[order.find(id)], 105)

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
		field.position = _role_position(c.side == "player", true) if battle.zones[c.side] == id else _prepare_position(id)
		field.modulate = Color.WHITE if c.alive else Color(0.65, 0.65, 0.65, 0.55)
		var view: SproutCard = field.get_node("Portrait/TemplateCard")
		view.configure(card_data(id))
		view.set_battle_state({"attack": Rules.attack_value(c), "hp": c.hp, "satiety": c.satiety, "mana": c.mana, "shield": c.shield})
		var status := "战斗区" if battle.zones[c.side] == id else "准备区"
		if not c.alive:
			status = "等待分裂体" if c.revive < 0 else ("复活 %d" % c.revive if c.revive > 0 else "已阵亡")
		elif c.satiety == 0: status += " · 饥饿"
		if c.alive and c.shield > 0:
			status = ("饥饿" if c.satiety == 0 else status) + " · 护盾%d" % c.shield
		(field.get_node("Tag") as Label).text = status
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(end_button) or battle == null: return
	var active := state == "player_turn"
	player_hud.sync(battle.player_hp, battle.ap, battle.owner == "player" and state != "draft")
	enemy_hud.sync(battle.enemy_hp, battle.enemy_ap, battle.owner == "enemy")
	end_button.disabled = not active
	end_button.text = "结束\n回合" if active else ("敌方\n回合" if state == "enemy_turn" else "请稍候")
	if is_instance_valid(battle_menu): battle_menu.gear.disabled = state == "result" or ending_early
	if not is_instance_valid(lesson_label): return
	if battle.turn == 0:
		step_label.text = "牌手生命：我方30 / 敌方10"
		lesson_label.text = "角色替牌手阻挡攻击。角色生命归零会阵亡；牌手生命归零才决定胜负。先调整起手牌，随后开始教学。"
		return
	var next := Rules.expected(battle)
	var next_text: String = "结束回合" if next == "end" else ("向上拖动铁山" if next == "attack" else Rules.data().get(next, {}).get("title", ""))
	step_label.text = "第%d回合 · %s" % [battle.turn, next_text]
	lesson_label.text = LESSONS[mini(7, battle.turn - 1)]

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
	(card.get_node("Art/TemplateCard") as SproutCard).configure(card_data(hand_cards[index]))
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
	# 展开时完整显示卡面，不放大到覆盖准备区角色的目标区域。
	for i in range(hand_nodes.size()):
		var node: Control = hand_nodes[i]
		if not is_instance_valid(node): continue
		var raised := i == selected if hand_expanded else (i == hovered and not dragging)
		var pose := _hand_pose(i, hand_nodes.size())
		var destination: Vector2 = _expanded_hand_pose(i, hand_nodes.size()) + (Vector2(0, -10) if raised else Vector2.ZERO) if hand_expanded else pose.position + (Vector2(0, -100) if raised else Vector2.ZERO)
		var zoom := (1.05 if raised else 1.0) if hand_expanded else (1.12 if raised else 1.0)
		var previous: Tween = node.get_meta("motion") if node.has_meta("motion") else null
		if previous and previous.is_valid(): previous.kill()
		var tween := _battle_tween().set_parallel(true)
		node.set_meta("motion", tween)
		tween.tween_property(node, "position", destination, 0.13)
		tween.tween_property(node, "rotation", 0.0 if raised or hand_expanded else pose.angle, 0.13)
		tween.tween_property(node, "scale", Vector2.ONE * zoom, 0.13)
		node.z_index = (85 if raised else 70 + i) if hand_expanded else (45 if raised else 10 + i)
		node.visible = not (dragging and i == selected)
		node.modulate = Color.WHITE if _playable(i).is_empty() else Color(0.76, 0.79, 0.78, 1)
		node.get_node("Glow").visible = false

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

func _end_turn() -> void:
	if state != "player_turn": return
	var result := Rules.transact(battle, "end")
	if not result.success:
		_toast(result.reason)
		return
	state = "ending"
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
	await _show_events(last_events)
	if ending_early: return
	Rules.end_turn(battle, "enemy")
	_sync()
	await _start_player_turn()

func _perform(action: String, target: String) -> void:
	if state != "player_turn": return
	var result := Rules.transact(battle, action, target)
	if not result.success:
		_toast(result.reason)
		_cancel_selection()
		return
	state = "resolving"
	last_events = result.events
	_cancel_selection()
	_sync()
	_rebuild_hand()
	if action != "attack":
		var fly := _art(board, action, Rect2(Vector2(820, 450), HAND_SIZE))
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
	_sync()
	await get_tree().create_timer(0.25, false).timeout

func _role_at(point: Vector2) -> String:
	for id in role_nodes:
		if _hit(role_nodes[id], point): return id
	return ""

func _input(event: InputEvent) -> void:
	if not is_instance_valid(board): return
	if state == "result":
		super._input(event)
		return
	if ending_early or (is_instance_valid(battle_menu) and battle_menu.is_open): return
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
	var fresh := (load("res://scenes/battle/yaya_battle_demo.tscn") as PackedScene).instantiate()
	fresh.return_scene_path = return_scene_path
	var owner_scene := get_parent()
	owner_scene.get_parent().add_child(fresh)
	if get_tree().current_scene == owner_scene: get_tree().current_scene = fresh
	owner_scene.process_mode = Node.PROCESS_MODE_DISABLED
	owner_scene.queue_free()
