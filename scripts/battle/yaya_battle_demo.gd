extends Control
## 芽芽正式卡牌战斗示意。烹饪只记录为示意资源，不伪造食材/佳肴卡。

const SproutTheme = preload("res://scripts/ui/components/sprout_theme.gd")
const BG: Texture2D = preload("res://assets/ui/battle/yaya_battle_background.png")
const ALLY_BACK: Texture2D = preload("res://assets/ui/battle/card_backs/ally_light.png")
const ENEMY_BACK: Texture2D = preload("res://assets/ui/battle/card_backs/enemy_dark.png")
const FIRST_FACE: Texture2D = preload("res://assets/ui/battle/initiative/first.png")
const SECOND_FACE: Texture2D = preload("res://assets/ui/battle/initiative/second.png")
const ORDER := ["芽芽", "小小掌勺人", "温火照料", "战地小厨", "热锅协作"]
const DATA := {
	"芽芽": {"type":"角色牌", "desc":"每回合一次，芽芽出击时，烹饪。", "stats":"攻击 2 / 生命 4", "level":"-", "tex":preload("res://assets/ui/battle/cards/yaya/yaya.png")},
	"小小掌勺人": {"type":"形态牌", "desc":"当你被攻击时，烹饪。", "stats":"攻击 2 / 生命 5", "level":"等级 1 · 1 张", "tex":preload("res://assets/ui/battle/cards/yaya/small_spoon_person.png")},
	"温火照料": {"type":"法术牌", "desc":"为你或任意一名己方角色恢复 2 生命。", "stats":"恢复 2", "level":"等级 1 · 2 张", "tex":preload("res://assets/ui/battle/cards/yaya/warm_care.png")},
	"战地小厨": {"type":"形态牌", "desc":"己方回合结束时，若芽芽在战斗区，烹饪。", "stats":"攻击 2 / 生命 7", "level":"等级 2 · 1 张", "tex":preload("res://assets/ui/battle/cards/yaya/field_kitchen.png")},
	"热锅协作": {"type":"法术牌", "desc":"选择一张食材，让另一名己方角色使用并出击。", "stats":"协作出击", "level":"等级 3 · 1 张", "tex":preload("res://assets/ui/battle/cards/yaya/hotpot_collab.png")}
}

# 数值和技能来自用户提供的《代号：料理迷宫》卡牌设计说明 (1).xlsx。
# 牌面使用共享 SproutCard 模板，战斗状态由本脚本动态更新。
const TUTORIAL_CARDS := {
 "强力": {"id":"tieshan_strong","faction":"tieshan","character_name":"铁山","role":"守卫","title":"强力","card_type":"战斗牌","effect":"铁山永久增加1攻击力。","value":"攻击+1","cost":"1","number":3},
 "守护": {"id":"tieshan_guard","faction":"tieshan","character_name":"铁山","role":"守卫","title":"守护","card_type":"战斗牌","effect":"若己方战斗区有其他角色，此牌+3攻击力。","value":"攻击+3（满足条件）·护盾+4","cost":"1","number":4},
 "魔力一击": {"id":"yaya_magic_hit","faction":"sprout","character_name":"芽芽","role":"法师","title":"魔力一击","card_type":"法术牌","effect":"对一个敌方角色造成3点伤害。","value":"伤害3","cost":"1","number":3},
 "坚守不移": {"id":"tieshan_hold","faction":"tieshan","character_name":"铁山","role":"守卫","title":"坚守不移","card_type":"赋形牌","effect":"当铁山在战斗区时，己方其他角色免疫伤害。","value":"攻击2·生命8","cost":"1","number":7,"attack":2,"health":8},
 "魔力之风": {"id":"yaya_magic_wind","faction":"sprout","character_name":"芽芽","role":"法师","title":"魔力之风","card_type":"法术牌","effect":"对所有敌方角色造成1点伤害。","value":"群体伤害1","cost":"1","number":4},
 "治愈之风": {"id":"yaya_heal_wind","faction":"sprout","character_name":"芽芽","role":"法师","title":"治愈之风","card_type":"法术牌","effect":"为所有己方角色恢复3点生命，溢出部分转化为护盾。","value":"群体治疗3","cost":"1","number":7},
 "恢复": {"id":"yaya_restore","faction":"sprout","character_name":"芽芽","role":"法师","title":"恢复","card_type":"法术牌","effect":"为一个己方角色恢复2生命。","value":"治疗2","cost":"1","number":1},
 "斧冲": {"id":"tieshan_axe","faction":"tieshan","character_name":"铁山","role":"守卫","title":"斧冲","card_type":"战斗牌","effect":"直接攻击敌方牌手。","value":"攻击+2·护盾+1","cost":"1","number":2}
}

const Effects = preload("res://scripts/battle/battle_effects.gd")
const SideHud = preload("res://scripts/battle/battle_side_hud.gd")
const Toast = preload("res://scripts/ui/components/feedback_toast.gd")
const SproutAction = preload("res://scripts/ui/components/sprout_button.gd")
const BattleMenu = preload("res://scripts/battle/battle_menu.gd")
const ContinuePrompt = preload("res://scripts/ui/components/continue_prompt.gd")
const CardView = preload("res://scripts/ui/components/sprout_card.gd")
const CardData = preload("res://scripts/ui/components/sprout_card_data.gd")
const VICTORY_RESULT: Texture2D = preload("res://assets/ui/battle/results/victory_wordmark_v1.png")
const DEFEAT_RESULT: Texture2D = preload("res://assets/ui/battle/results/defeat_wordmark_v1.png")
const CREAM := Color("#fff5df")
const GOLD := Color("#d5ad5e")
const INK := Color("#345356")
const GREEN := Color("#7dccac")
const RED := Color("#d97a72")
const CANVAS := Vector2(1280, 720)
const HAND_SIZE := Vector2(126, 210)
const DRAFT_CARD_SIZE := Vector2(190, 316)
const ROLE_SIZE := Vector2(116, 194)
# 当前底图荷叶的视觉中心，换底图时重新校准；双方区域围绕此点镜像。
const LEAF_CENTER := Vector2(638, 342)
const PREPARE_CENTER := LEAF_CENTER + Vector2(-148, 150)
const COMBAT_CENTER := LEAF_CENTER + Vector2(0, 91)
const DECK_SIZE := Vector2(72, 88)
const ATTACK_DRAG_DISTANCE := 24.0
const SPELLS := ["强力", "守护", "恢复", "恢复", "魔力之风"]
@export var tutorial_battle := true
# 0按对局类型取默认生命；教学/剧情场景可分别覆盖双方初始生命。
@export_range(0, 30, 1) var player_starting_health := 0
@export_range(0, 30, 1) var enemy_starting_health := 0
@export_file("*.tscn") var return_scene_path := "res://scenes/start_screen.tscn"
@export var tutorial_fixed := false
@export_enum("随机", "我方", "敌方") var initiative_override := 0
var state := "opening"
var board: Control
var battlefield: Control
var fx: Node2D
var dim: ColorRect
var draft: Control
var draft_cards: Array[Control] = []
var replace_buttons: Array[Button] = []
var replace_count := 0
var confirm_button: Button
var draft_selected := -1
var draft_hint: Label
var end_button: Button
var battle_menu: Control
var ending_early := false
var result_ready := false
var result_armed := false
var result_e_held := false
var result_exiting := false
var battle_tweens: Array[Tween] = []
var phase_label: Label
var hint: Label
var deck_label: Label
var player_hud: Control
var enemy_hud: Control
var toast: Label
var preview: Control
var preview_art: Control
var preview_text: Label
var target_highlight: Panel
var player_field: Control
var enemy_field: Control
var player_in_battle := false
var enemy_in_battle := false
var combat_slots: Array[Control] = []
var attack_origin := Vector2.ZERO
var enemy_backs: Control
var hand_nodes: Array[Control] = []
var hand_cards: Array[String] = []
var deck: Array[String] = []
var discard: Array[String] = []
var enemy_cards: Array[String] = []
var selected := -1
var hand_expanded := false
var hovered := -1
var press_origin := Vector2.ZERO
var pointer := Vector2.ZERO
var held := false
var dragging := false
var attack_selected := false
var drag_card: Control
var initiative_player_first := true
var player_hp := 30
var player_max_hp := 30
var enemy_hp := 30
var enemy_max_hp := 30
var player_form := "芽芽"
var enemy_form := "芽芽"
var action_point := 2
var enemy_action_point := 0
var player_attacked := false
var cooked_this_turn := false
var cook_count := 0
var enemy_cook_count := 0
var round_number := 0
var enemy_step := 0
var turn_owner_player := true
var audio: AudioStreamPlayer

func _ready() -> void:
	if tutorial_battle:
		# 教学使用独立规则控制器；旧非教学演示继续保留。
		var tutorial := Control.new()
		tutorial.set_script(load("res://scripts/battle/card_tutorial_battle.gd"))
		tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tutorial.return_scene_path = return_scene_path
		add_child(tutorial)
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player_max_hp = player_starting_health if player_starting_health > 0 else (10 if tutorial_battle else 30)
	enemy_max_hp = enemy_starting_health if enemy_starting_health > 0 else (5 if tutorial_battle else 30)
	player_hp = player_max_hp
	enemy_hp = enemy_max_hp
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
	# 演示使用两份能力牌，以便展示起手替换及回合抽牌；不改正式卡牌目录。
	hand_cards.assign(SPELLS)
	deck.assign(SPELLS)
	enemy_cards.assign(SPELLS)
	deck.shuffle()
	_update_hud()
	_opening()

func _fit() -> void:
	if not is_instance_valid(board): return
	var factor := minf(size.x / CANVAS.x, size.y / CANVAS.y)
	board.scale = Vector2.ONE * factor
	board.position = (size - CANVAS * factor) * 0.5

func _text(parent: Node, value: String, rect: Rect2, font_size := 20, color := INK, centered := false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label

func _style(fill: Color, edge: Color, width := 1, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.04, 0.1, 0.09, 0.16)
	style.shadow_size = 8
	return style

func _panel(parent: Node, rect: Rect2, fill: Color, edge: Color, width := 1, radius := 8) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, edge, width, radius))
	parent.add_child(panel)
	return panel

func _button(parent: Node, value: String, rect: Rect2, callback: Callable) -> Button:
	var button := SproutAction.new()
	button.set_icon_visible(false)
	button.text = value
	parent.add_child(button)
	button.custom_minimum_size = Vector2.ZERO
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(callback)
	return button

func _texture(id: String) -> Texture2D:
	# 角色图仍用于战场；手牌与起手牌由 SproutCard 模板渲染。
	if DATA.has(id): return DATA[id].tex
	return preload("res://assets/characters/tieshan/tieshan_portrait.png") if TUTORIAL_CARDS.get(id, {}).get("faction", "") == "tieshan" else preload("res://assets/characters/yaya_portrait.png")

func _card_data(id: String) -> CardData:
	var raw: Dictionary = TUTORIAL_CARDS.get(id, {})
	if raw.is_empty():
		return CardData.new({"id": id, "character_name": id, "title": id, "card_type": "角色牌", "effect": "", "portrait_path": "res://assets/characters/yaya_portrait.png"})
	var values := raw.duplicate(true)
	values["is_role_card"] = values.get("card_type", "") == "角色牌"
	values["portrait_path"] = "res://assets/characters/tieshan/tieshan_portrait.png" if values.get("faction", "") == "tieshan" else "res://assets/characters/yaya_portrait.png"
	values["portrait"] = load(values["portrait_path"]) as Texture2D
	values["satiety_cost"] = 1
	values["mana_cost"] = 0
	return CardData.new(values)

func _art(parent: Node, id: String, rect: Rect2) -> Control:
	var art := TextureRect.new()
	art.texture = _texture(id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = rect.position
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _card(parent: Node, id: String, rect: Rect2) -> Control:
	var card := Control.new()
	card.position = rect.position
	card.size = rect.size
	card.pivot_offset = rect.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)
	var view := CardView.new()
	view.name = "TemplateCard"
	view.configure(_card_data(id))
	view.set_battle_context(true)
	view.position = Vector2.ZERO
	view.size = rect.size
	view.scale = rect.size / CardView.CARD_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(view)
	var glow := _panel(card, Rect2(Vector2(-3, -3), rect.size + Vector2(6, 6)), Color(0.5, 0.85, 0.72, 0.13), GOLD, 2, 9)
	glow.name = "Glow"
	glow.hide()
	# 旧交互代码依赖 Art 节点作为拖拽占位；真实牌面由 TemplateCard 提供。
	var art := TextureRect.new()
	art.name = "Art"
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate.a = 0.0
	card.add_child(art)
	return card

func _back(parent: Node, rect: Rect2, for_player: bool) -> Panel:
	var card := Panel.new()
	card.position = rect.position
	card.size = rect.size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	parent.add_child(card)
	var art := TextureRect.new()
	art.name = "BackArt"
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 只按敌我关系取图，不依赖牌名、角色或形态。
	art.texture = ALLY_BACK if for_player else ENEMY_BACK
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = rect.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art)
	card.pivot_offset = card.size * 0.5
	return card

func _build_board() -> void:
	var bg := TextureRect.new()
	bg.texture = BG
	bg.size = CANVAS
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(bg)
	battlefield = Control.new()
	battlefield.size = CANVAS
	battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(battlefield)
	enemy_hud = SideHud.new()
	enemy_hud.position = Vector2(28, 20)
	battlefield.add_child(enemy_hud)
	player_hud = SideHud.new()
	player_hud.position = Vector2(28, 580)
	battlefield.add_child(player_hud)
	# 右侧战场只保留操作控件，不展示回合标题或操作说明文字。
	phase_label = _text(battlefield, "", Rect2(1048, 311, 152, 32), 17, INK, true)
	phase_label.visible = false
	for for_player in [false, true]:
		var combat := _role_position(for_player, true)
		var slot := _panel(battlefield, Rect2(combat + Vector2(5, 7), ROLE_SIZE - Vector2(10, 14)), Color(0.3,0.5,0.4,0.025), Color(0.24,0.4,0.35,0.16), 1, 9)
		(slot.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 0
		combat_slots.append(slot)
	enemy_backs = Control.new()
	enemy_backs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.add_child(enemy_backs)
	for i in range(5):
		var pose := _hand_pose(i, 5)
		var at: Vector2 = pose.position
		at.y = CANVAS.y - at.y - HAND_SIZE.y
		_back(enemy_backs, Rect2(at, HAND_SIZE), false).rotation = -pose.angle
	for for_player in [false, true]:
		var at := _deck_position(for_player)
		var direction := 1.0 if for_player else -1.0
		for layer in range(3):
			var stack_card := _back(battlefield, Rect2(at + Vector2((2 - layer) * 4, (2 - layer) * 3 * direction), DECK_SIZE), for_player)
			stack_card.name = ("AllyDeck" if for_player else "EnemyDeck") + str(layer)
			stack_card.rotation = PI * 0.5
	# 牌库通过横放卡背本身表达，不再叠加“牌库”文字标签。
	deck_label = _text(battlefield, "", Rect2(1208, 488, 70, 26), 14, INK, true)
	deck_label.visible = false
	player_field = _make_field(false, _role_position(true, false))
	enemy_field = _make_field(true, _role_position(false, false))
	end_button = _button(battlefield, "等待\n开局", Rect2(1210, LEAF_CENTER.y - 49, 98, 98), _end_turn)
	end_button.add_theme_font_size_override("font_size", 22)
	for key in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("#e4ecd3") if key != "disabled" else Color("#c4cebf")
		var style := _style(fill, GOLD, 2, 49)
		# 按钮外缘藏到画布外，文字留在可见的70像素区域内。
		style.content_margin_left = 0
		style.content_margin_right = 28
		end_button.add_theme_stylebox_override(key, style)
	end_button.disabled = true
	hint = _text(battlefield, "", Rect2(1020, 352, 178, 70), 15, INK, true)
	hint.visible = false
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.z_index = 65
	preview = Control.new()
	preview.position = Vector2(30, 155)
	preview.size = Vector2(420, 405)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 60
	board.add_child(preview)
	preview_art = _art(preview, "芽芽", Rect2(0, 0, 206, 344))
	var details := _panel(preview, Rect2(218, 28, 183, 285), Color(0.08,0.17,0.17,0.94), GOLD)
	preview_text = _text(details, "", Rect2(14, 12, 155, 260), 17, CREAM)
	preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	preview.hide()
	dim = ColorRect.new()
	dim.size = CANVAS
	dim.color = Color(0.025, 0.08, 0.10, 0.68)
	dim.z_index = 90
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	board.add_child(dim)
	target_highlight = _panel(board, Rect2(Vector2.ZERO, ROLE_SIZE + Vector2(12,12)), Color(0.35,0.92,0.70,0.08), GREEN, 2, 12)
	target_highlight.z_index = 55
	target_highlight.hide()
	fx = Effects.new()
	fx.z_index = 180
	board.add_child(fx)
	toast = Toast.attach_to(board)
	toast.get_parent().z_index = 350
	audio = AudioStreamPlayer.new()
	audio.volume_db = -20
	add_child(audio)
	battle_menu = BattleMenu.new()
	battle_menu.z_index = 400
	board.add_child(battle_menu)
	battle_menu.opened.connect(_cancel_selection)
	battle_menu.action_confirmed.connect(_menu_action)
	_update_hud()

func _make_field(enemy: bool, at: Vector2) -> Control:
	var field := Control.new()
	field.position = at
	field.size = ROLE_SIZE
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.add_child(field)
	field.pivot_offset = field.size * 0.5
	var art := _art(field, "芽芽", Rect2(Vector2.ZERO, ROLE_SIZE))
	art.name = "Portrait"
	# 原卡完整显示；单角色演示的实时生命统一显示在左侧头像徽章。
	var tag := _text(field, "", Rect2(-100, 120 if not enemy else 44, 94, 30), 14, INK, true)
	tag.name = "Tag"
	var stats := _text(field, "", Rect2(-86, -36 if enemy else 196, 210, 30), 13, CREAM, true)
	stats.name = "Stats"
	stats.add_theme_color_override("font_outline_color", INK)
	stats.add_theme_constant_override("outline_size", 3)
	_set_field_art(field, "芽芽")
	return field

func _role_position(for_player: bool, in_battle: bool) -> Vector2:
	var center := COMBAT_CENTER if in_battle else PREPARE_CENTER
	if not for_player: center.y = LEAF_CENTER.y * 2.0 - center.y
	return center - ROLE_SIZE * 0.5

func _deck_position(for_player: bool) -> Vector2:
	return Vector2(1228, LEAF_CENTER.y + (80 if for_player else -80) - DECK_SIZE.y * 0.5)

func _attack_drop_valid(point: Vector2) -> bool:
	var delta := point - press_origin
	# 看松手位置，不看曾经经过的位置；拖上去再拖回能够取消。
	return delta.y <= -ATTACK_DRAG_DISTANCE and absf(delta.x) <= 120 and Rect2(Vector2.ZERO, CANVAS).has_point(point)

func _restore_role() -> void:
	player_field.position = _role_position(true, player_in_battle)
	player_field.scale = Vector2.ONE
	player_field.z_index = 0

func _opening() -> void:
	initiative_player_first = true if tutorial_battle else (randf() < 0.5 if initiative_override == 0 else initiative_override == 1)
	var seals: Array[Control] = []
	for i in range(2):
		var seal := _back(board, Rect2(LEAF_CENTER.x - 72, LEAF_CENTER.y - 264 + i * 288, 144, 240), i == 1)
		seal.name = "InitiativePlayer" if i == 1 else "InitiativeEnemy"
		seal.z_index = 110
		seals.append(seal)
		seal.position.x += -280 if i == 0 else 280
		seal.modulate.a = 0
		var enter := _battle_tween().set_parallel(true)
		enter.tween_property(seal, "position:x", LEAF_CENTER.x - 72, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		enter.tween_property(seal, "modulate:a", 1.0, 0.25)
	await get_tree().create_timer(0.65, false).timeout
	if ending_early: return
	for i in range(2):
		var seal := seals[i]
		var flip := _battle_tween()
		flip.tween_property(seal, "scale:x", 0.02, 0.13)
		await flip.finished
		if ending_early: return
		for child in seal.get_children(): child.queue_free()
		var first := initiative_player_first if i == 1 else not initiative_player_first
		var face := TextureRect.new()
		face.name = "Face"
		face.texture = FIRST_FACE if first else SECOND_FACE
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face.size = seal.size
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal.add_child(face)
		_text(seal, "我方" if i == 1 else "敌方", Rect2(0, 244, 144, 28), 17, CREAM, true)
		var reveal := _battle_tween()
		reveal.tween_property(seal, "scale:x", 1.0, 0.18)
		_sound(610 if first else 440)
		fx.burst(seal.position + seal.size * 0.5, GOLD if first else GREEN)
		await reveal.finished
		if ending_early: return
	await get_tree().create_timer(0.95, false).timeout
	if ending_early: return
	for i in range(2):
		var seal := seals[i]
		var leave := _battle_tween().set_parallel(true)
		leave.tween_property(seal, "position", Vector2(60, 584 if i == 1 else 50), 0.35)
		leave.tween_property(seal, "scale", Vector2.ONE * 0.25, 0.35)
		leave.tween_property(seal, "modulate:a", 0.0, 0.35)
		leave.finished.connect(seal.queue_free)
	await get_tree().create_timer(0.4, false).timeout
	if ending_early: return
	_show_draft()

func _show_draft() -> void:
	state = "draft"
	draft = Control.new()
	draft.size = CANVAS
	draft.z_index = 100
	draft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(draft)
	_text(draft, "调整起手牌", Rect2(75, 95, 440, 46), 32, CREAM)
	draft_hint = _text(draft, "", Rect2(78, 143, 920, 38), 19, CREAM)
	_text(draft, "我方先手" if initiative_player_first else "我方后手", Rect2(75, 53, 320, 30), 18, GOLD)
	draft_selected = -1
	for i in range(hand_cards.size()):
		var card := _card(draft, hand_cards[i], Rect2(95 + i * 215, 196, DRAFT_CARD_SIZE.x, DRAFT_CARD_SIZE.y))
		draft_cards.append(card)
		card.modulate.a = 0
		var enter := _battle_tween()
		enter.tween_interval(i * 0.06)
		enter.tween_property(card, "modulate:a", 1.0, 0.18)
		var replace := _button(draft, "调整", Rect2(132 + i * 215, 530, 116, 42), _replace_card.bind(i))
		replace.focus_mode = Control.FOCUS_NONE
		replace_buttons.append(replace)
	confirm_button = _button(draft, "保留手牌", Rect2(520, 610, 240, 56), _confirm_draft)
	_update_draft()

func _update_draft() -> void:
	draft_hint.text = "确认手牌，开始战斗" if tutorial_fixed else ("调整次数已用完" if replace_count >= 3 else "选择手牌调整 · 剩余 %d 次" % (3 - replace_count))
	for i in range(replace_buttons.size()):
		var current := i == draft_selected
		draft_cards[i].get_node("Glow").visible = false
		draft_cards[i].scale = Vector2.ONE * (1.08 if current and state == "draft" else 1.0)
		draft_cards[i].position.y = 178 if current and state == "draft" else 196
		replace_buttons[i].visible = current and not tutorial_fixed and state == "draft" and replace_count < 3
		replace_buttons[i].disabled = tutorial_fixed or replace_count >= 3 or state != "draft"
	confirm_button.text = "开始战斗"
	confirm_button.disabled = state != "draft"

func _replace_card(index: int) -> void:
	if state != "draft" or tutorial_fixed or replace_count >= 3 or index != draft_selected: return
	state = "replacing"
	_update_draft()
	var card := draft_cards[index]
	var old := hand_cards[index]
	var new_index := 0
	for i in range(deck.size()):
		if deck[i] != old:
			new_index = i
			break
	var replacement := deck[new_index]
	deck.remove_at(new_index)
	deck.append(old)
	deck.shuffle()
	var out := _battle_tween()
	out.tween_property(card, "scale:x", 0.02, 0.16)
	await out.finished
	if ending_early: return
	hand_cards[index] = replacement
	(card.get_node("Art") as TextureRect).texture = _texture(replacement)
	_sound(760)
	var intro := _battle_tween()
	intro.tween_property(card, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	await intro.finished
	if ending_early: return
	fx.burst(card.position + card.size * 0.5, GOLD)
	replace_count += 1
	state = "draft"
	_update_draft()

func _confirm_draft() -> void:
	if state != "draft": return
	state = "dealing"
	_update_draft()
	for button in replace_buttons: button.hide()
	confirm_button.hide()
	for child in draft.get_children():
		if child is Label: child.hide()
	var fade := _battle_tween()
	fade.tween_property(dim, "modulate:a", 0.0, 0.35)
	# 手牌直接收到底部，先后手不在此处再次播放。
	for i in range(draft_cards.size()):
		var card := draft_cards[i]
		var landing := _hand_pose(i, hand_cards.size())
		var move := _battle_tween().set_parallel(true)
		move.tween_property(card, "position", landing.position, 0.48).set_delay((4 - i) * 0.065).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		move.tween_property(card, "size", HAND_SIZE, 0.48).set_delay((4 - i) * 0.065)
		move.tween_property(card.get_node("Art"), "size", HAND_SIZE, 0.48).set_delay((4 - i) * 0.065)
		move.tween_property(card, "rotation", landing.angle, 0.48).set_delay((4 - i) * 0.065)
		card.get_node("Glow").hide()
	_sound(520)
	await get_tree().create_timer(0.82, false).timeout
	if ending_early: return
	draft.queue_free()
	dim.hide()
	_rebuild_hand()
	fx.burst(player_field.position + player_field.size * 0.5, GOLD)
	fx.burst(enemy_field.position + enemy_field.size * 0.5, GOLD)
	if initiative_player_first: await _start_player_turn(true)
	else: await _enemy_turn()

func _hand_pose(index: int, count: int) -> Dictionary:
	var middle := (count - 1) * 0.5
	var spread := minf(52, 300.0 / maxf(count - 1, 1))
	var offset := index - middle
	var fan := offset / maxf(middle, 1)
	return {"position": Vector2(1050 + offset * spread - HAND_SIZE.x * 0.5, 614 + fan * fan * 8.0), "angle": fan * 0.07}

func _expanded_hand_pose(index: int, count: int) -> Vector2:
	# 最多七张一排；牌多时增加上排，保证完整卡面不互相盖住。
	var rows := ceili(count / 7.0)
	var row := index / 7
	var row_count := mini(7, count - row * 7)
	var column := index % 7
	return Vector2(1190 - (row_count - 1 - column) * 168 - HAND_SIZE.x * 0.5, 472 - (rows - 1 - row) * 280)

func _rebuild_hand() -> void:
	for node in hand_nodes:
		if is_instance_valid(node): node.queue_free()
	hand_nodes.clear()
	hovered = -1
	for i in range(hand_cards.size()):
		var pose := _hand_pose(i, hand_cards.size())
		var card := _card(battlefield, hand_cards[i], Rect2(pose.position, HAND_SIZE))
		card.rotation = pose.angle
		card.z_index = 10 + i
		hand_nodes.append(card)
	_layout_hand()
	_update_hud()

func _layout_hand() -> void:
	for i in range(hand_nodes.size()):
		var node := hand_nodes[i]
		if not is_instance_valid(node): continue
		var raised := i == selected if hand_expanded else (i == hovered and not dragging)
		var pose := _hand_pose(i, hand_nodes.size())
		var destination: Vector2 = _expanded_hand_pose(i, hand_nodes.size()) + (Vector2(0, -20) if raised else Vector2.ZERO) if hand_expanded else pose.position + (Vector2(0, -100) if raised else Vector2.ZERO)
		var zoom := (1.28 if raised else 1.12) if hand_expanded else (1.12 if raised else 1.0)
		var existing: Tween = node.get_meta("motion") if node.has_meta("motion") else null
		if existing and existing.is_valid(): existing.kill()
		var tween := _battle_tween().set_parallel(true)
		node.set_meta("motion", tween)
		tween.tween_property(node, "position", destination, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "rotation", 0.0 if raised or hand_expanded else pose.angle, 0.13)
		tween.tween_property(node, "scale", Vector2.ONE * zoom, 0.13)
		node.z_index = (85 if raised else 70 + i) if hand_expanded else (45 if raised else 10 + i)
		node.visible = not (dragging and i == selected)
		node.modulate = Color.WHITE if _playable(i).is_empty() else Color(0.76,0.79,0.78,1)
		var glow: Panel = node.get_node("Glow")
		glow.visible = false
		glow.modulate.a = 1.0

func _playable(index: int) -> String:
	if index < 0 or index >= hand_cards.size(): return "请选择手牌"
	if state != "player_turn": return "等待我方回合"
	if action_point <= 0: return "行动点已用完"
	if hand_cards[index] == "热锅协作": return "需要食材和另一名己方角色"
	return ""

func _show_preview(id: String, reason := "") -> void:
	if hand_expanded:
		preview.hide()
		return
	preview_art.texture = _texture(id)
	if TUTORIAL_CARDS.has(id):
		var d: Dictionary = TUTORIAL_CARDS[id]
		preview_text.text = "%s\n%s\n\n%s" % [id, d.card_type, d.effect]
	else:
		preview_text.text = "%s\n%s · %s\n\n%s" % [id, DATA[id].type, DATA[id].level, DATA[id].desc]
	if not reason.is_empty(): preview_text.text += "\n\n" + reason
	preview.show()

func _select_card(index: int) -> void:
	if state not in ["player_turn", "enemy_turn"]: return
	var reason := _playable(index)
	_restore_role()
	selected = index
	hand_expanded = true
	attack_selected = false
	preview.hide()
	hint.text = ""
	if not reason.is_empty(): _toast(reason)
	target_highlight.hide()
	fx.aim_visible = false
	_layout_hand()

func _select_attack() -> void:
	if state != "player_turn": return
	if action_point <= 0 or player_attacked:
		_toast("本回合已出击" if player_attacked else "行动点已用完")
		return
	selected = -1
	hand_expanded = false
	attack_selected = true
	attack_origin = _role_position(true, player_in_battle)
	press_origin = pointer
	held = true
	preview.hide()
	target_highlight.position = _role_position(true, true) - Vector2(6, 6)
	target_highlight.show()
	hint.text = ""
	player_field.z_index = 48
	_layout_hand()
	_update_aim()

func _cancel_selection() -> void:
	if attack_selected: _restore_role()
	selected = -1
	hand_expanded = false
	attack_selected = false
	held = false
	dragging = false
	if is_instance_valid(drag_card): drag_card.queue_free()
	drag_card = null
	target_highlight.hide()
	fx.aim_visible = false
	preview.hide()
	hovered = -1
	_layout_hand()
	_update_hud()

func _hit(control: Control, point: Vector2) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return false
	var global_point := board.get_global_transform() * point
	var local := control.get_global_transform().affine_inverse() * global_point
	return Rect2(Vector2.ZERO, control.size).has_point(local)

func _hand_at(point: Vector2) -> int:
	if hovered >= 0 and hovered < hand_nodes.size() and _hit(hand_nodes[hovered], point): return hovered
	if selected >= 0 and selected < hand_nodes.size() and _hit(hand_nodes[selected], point): return selected
	for i in range(hand_nodes.size() - 1, -1, -1):
		if _hit(hand_nodes[i], point): return i
	return -1

func _input(event: InputEvent) -> void:
	if not is_instance_valid(board): return
	if state == "result":
		# 演出及等待期间消费全部输入，关闭的 E 也不能传到返回场景。
		get_viewport().set_input_as_handled()
		if not event is InputEventKey or (event.keycode != KEY_E and event.physical_keycode != KEY_E): return
		if event.echo: return
		if not event.pressed:
			result_e_held = false
			result_armed = result_ready
			return
		var was_held := result_e_held
		result_e_held = true
		if result_ready and result_armed and not was_held and not result_exiting:
			result_armed = false
			result_exiting = true
			_return_menu.call_deferred()
		return
	if event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E) and not event.echo:
		result_e_held = event.pressed
	if ending_early or (is_instance_valid(battle_menu) and battle_menu.is_open): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if state in ["player_turn", "enemy_turn"]: _cancel_selection()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		pointer = board.get_global_transform_with_canvas().affine_inverse() * event.position
		if state in ["player_turn", "enemy_turn"]:
			if held and state == "player_turn" and pointer.distance_to(press_origin) > 12:
				if selected >= 0 or attack_selected:
					dragging = true
					if selected >= 0 and not is_instance_valid(drag_card):
						hand_expanded = false
						hovered = -1
						drag_card = _art(board, hand_cards[selected], Rect2(pointer - HAND_SIZE * 0.5, HAND_SIZE))
						drag_card.z_index = 160
						_layout_hand()
						if _playable(selected).is_empty():
							target_highlight.position = player_field.position - Vector2(6, 6)
							target_highlight.show()
					preview.hide()
			if dragging:
				if is_instance_valid(drag_card): drag_card.position = pointer - HAND_SIZE * 0.5
				elif attack_selected:
					# 角色轻跟手，实际目的地由战斗区决定，不要求拖到敌方。
					var delta := pointer - press_origin
					player_field.position = attack_origin + Vector2(clampf(delta.x, -35, 35), clampf(delta.y, -55, 28)) * 0.4
			else:
				var index := _hand_at(pointer)
				if index != hovered:
					hovered = index
					_layout_hand()
					if index >= 0: _show_preview(hand_cards[index], _playable(index))
					elif selected < 0: preview.hide()
				if index < 0 and selected < 0 and not attack_selected:
					if _hit(player_field, pointer): _show_preview(player_form)
					elif _hit(enemy_field, pointer): _show_preview(enemy_form)
					else: preview.hide()
			_update_aim()
		return
	if not event is InputEventMouseButton: return
	pointer = board.get_global_transform_with_canvas().affine_inverse() * event.position
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if state in ["player_turn", "enemy_turn"]: _cancel_selection()
		return
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if state == "draft":
		if event.pressed and not tutorial_fixed:
			for i in range(draft_cards.size()):
				if _hit(draft_cards[i], pointer):
					draft_selected = i
					_update_draft()
					get_viewport().set_input_as_handled()
					break
		return
	if state == "enemy_turn":
		if event.pressed and not _hit(battle_menu.gear, pointer):
			var index := _hand_at(pointer)
			if index >= 0: _select_card(index)
			else: _cancel_selection()
		return
	if state != "player_turn": return
	if event.pressed:
		if _hit(end_button, pointer) or _hit(battle_menu.gear, pointer): return
		var index := _hand_at(pointer)
		if index >= 0:
			_select_card(index)
			held = selected == index
			press_origin = pointer
		elif selected >= 0 and _hit(player_field, pointer): _play_selected()
		elif _hit(player_field, pointer):
			_select_attack()
			held = attack_selected
			press_origin = pointer
		elif _hit(enemy_field, pointer):
			_cancel_selection()
			_show_preview(enemy_form)
		else: _cancel_selection()
		get_viewport().set_input_as_handled()
	else:
		if attack_selected and held:
			var deploy := _attack_drop_valid(pointer)
			held = false
			dragging = false
			if deploy: _attack(true)
			else: _cancel_selection()
			get_viewport().set_input_as_handled()
			return
		if dragging:
			var valid := _hit(player_field, pointer)
			held = false
			dragging = false
			if valid:
				if selected >= 0: _play_selected()
			else:
				if is_instance_valid(drag_card):
					var returning := drag_card
					drag_card = null
					var tween := _battle_tween().set_parallel(true)
					tween.tween_property(returning, "position", _hand_pose(selected, hand_nodes.size()).position, 0.18)
					tween.tween_property(returning, "modulate:a", 0.0, 0.18)
					tween.finished.connect(returning.queue_free)
				_cancel_selection()
		else: held = false

func _update_aim() -> void:
	fx.aim_visible = state == "player_turn" and (attack_selected or (dragging and selected >= 0 and _playable(selected).is_empty()))
	if not fx.aim_visible: return
	fx.aim_from = player_field.position + player_field.size * 0.5 if attack_selected else hand_nodes[selected].position + Vector2(63, 25)
	fx.aim_to = _role_position(true, true) + ROLE_SIZE * 0.5 if attack_selected else pointer
	if attack_selected and player_in_battle: fx.aim_to = LEAF_CENTER + Vector2(0, -24)
	fx.aim_valid = _attack_drop_valid(pointer) if attack_selected else _hit(player_field, pointer)
	# 出击由箭头和目标高亮表达，战场不叠加文字提示。
	hint.text = ""

func _play_selected() -> void:
	var reason := _playable(selected)
	if not reason.is_empty():
		_toast(reason)
		_cancel_selection()
		return
	var index := selected
	var id := hand_cards[index]
	var start: Vector2 = drag_card.position if is_instance_valid(drag_card) else hand_nodes[index].position
	state = "resolving"
	_cancel_selection()
	action_point -= 1
	hand_cards.remove_at(index)
	discard.append(id)
	_rebuild_hand()
	_update_hud()
	await _animate_card(id, start, player_field, true)
	if ending_early: return
	state = "player_turn"
	_update_hud()
	_layout_hand()

func _animate_card(id: String, start: Vector2, target: Control, for_player: bool) -> void:
	var fly := _art(board, id, Rect2(start, HAND_SIZE))
	fly.z_index = 160
	fly.pivot_offset = HAND_SIZE * 0.5
	var present := _battle_tween().set_parallel(true)
	present.tween_property(fly, "position", Vector2(800, 290), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	present.tween_property(fly, "scale", Vector2.ONE * 1.25, 0.25)
	_sound(630)
	await present.finished
	if ending_early: return
	await get_tree().create_timer(0.22, false).timeout
	if ending_early: return
	var settle := _battle_tween().set_parallel(true)
	settle.tween_property(fly, "position", target.position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	settle.tween_property(fly, "scale", Vector2.ONE * 0.7, 0.24)
	settle.tween_property(fly, "modulate:a", 0.0, 0.24)
	await settle.finished
	if ending_early: return
	fly.queue_free()
	_apply_effect(id, for_player)
	fx.burst(target.position + target.size * 0.5, GREEN if id == "温火照料" else GOLD, true)
	await get_tree().create_timer(0.28, false).timeout
	if ending_early: return

func _apply_effect(id: String, for_player: bool) -> void:
	var field := player_field if for_player else enemy_field
	if id == "温火照料":
		var old := player_hp if for_player else enemy_hp
		if for_player: player_hp = mini(player_max_hp, player_hp + 2)
		else: enemy_hp = mini(enemy_max_hp, enemy_hp + 2)
		var healed := (player_hp if for_player else enemy_hp) - old
		_float(field, "+%d" % healed, GREEN)
	elif id in ["小小掌勺人", "战地小厨"]:
		# 角色形态不覆盖牌手生命；对局生命由场景配置，治疗仍受其上限约束。
		if for_player:
			player_form = id
		else:
			enemy_form = id
		_set_field_art(field, id)
		_float(field, id, GOLD)
	_update_hud()

func _set_field_art(field: Control, id: String) -> void:
	(field.get_node("Portrait") as TextureRect).texture = DATA[id].tex

func _attack(for_player: bool) -> void:
	if for_player and (state != "player_turn" or action_point <= 0 or player_attacked): return
	state = "resolving"
	_cancel_selection()
	if for_player:
		action_point -= 1
		player_attacked = true
	else: enemy_action_point = maxi(0, enemy_action_point - 1)
	_update_hud()
	var source := player_field if for_player else enemy_field
	var target := enemy_field if for_player else player_field
	var destination := _role_position(for_player, true)
	source.z_index = 48
	if for_player: player_in_battle = true
	else: enemy_in_battle = true
	var deploy := _battle_tween()
	deploy.tween_property(source, "position", destination, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await deploy.finished
	if ending_early: return
	# 入战斗区后只做短促撞击，再落回战斗区，不能回准备区。
	var direction := Vector2.UP if for_player else Vector2.DOWN
	var strike := _battle_tween()
	strike.tween_property(source, "position", destination - direction * 9, 0.09)
	strike.tween_property(source, "position", destination + direction * 10, 0.11)
	await strike.finished
	if ending_early: return
	_sound(150, 0.12)
	fx.burst(target.position + target.size * 0.5, RED, true)
	if for_player: enemy_hp -= 2
	else: player_hp -= 2
	_float(target, "−2", RED)
	if for_player and not cooked_this_turn:
		cooked_this_turn = true
		_cook(true)
	elif not for_player: _cook(false)
	if (enemy_form if for_player else player_form) == "小小掌勺人": _cook(not for_player)
	_update_hud()
	var target_origin := target.position
	var shake := _battle_tween()
	shake.tween_property(target, "position:x", target_origin.x + 8, 0.05)
	shake.tween_property(target, "position:x", target_origin.x - 5, 0.05)
	shake.tween_property(target, "position:x", target_origin.x, 0.06)
	var back := _battle_tween()
	back.tween_property(source, "position", destination, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await back.finished
	if ending_early: return
	source.z_index = 0
	if enemy_hp <= 0 or player_hp <= 0:
		await _result(enemy_hp <= 0)
		if ending_early: return
		return
	state = "player_turn" if for_player else "enemy_turn"
	_update_hud()
	_layout_hand()

func _cook(for_player: bool) -> void:
	if for_player: cook_count += 1
	else: enemy_cook_count += 1
	var field := player_field if for_player else enemy_field
	_float(field, "烹饪 +1", GOLD, Vector2(0, 35))

func _end_turn() -> void:
	if state != "player_turn": return
	state = "ending"
	_cancel_selection()
	_update_hud()
	if player_form == "战地小厨" and player_in_battle:
		_cook(true)
		await get_tree().create_timer(0.4, false).timeout
		if ending_early: return
	await _enemy_turn()
	if ending_early: return

func _enemy_turn() -> void:
	state = "enemy_turn"
	turn_owner_player = false
	enemy_action_point = 2
	_cancel_selection()
	_update_hud()
	await _banner("敌 方 回 合", RED)
	if ending_early: return
	enemy_step += 1
	await get_tree().create_timer(0.32, false).timeout
	if ending_early: return
	if enemy_step == 1:
		_consume_enemy_card("小小掌勺人")
		await _animate_card("小小掌勺人", Vector2(950, 0), enemy_field, false)
		if ending_early: return
	elif enemy_step % 3 == 0 and enemy_hp < enemy_max_hp and enemy_cards.has("温火照料"):
		_consume_enemy_card("温火照料")
		await _animate_card("温火照料", Vector2(950, 0), enemy_field, false)
		if ending_early: return
		await _attack(false)
		if ending_early: return
	else: await _attack(false)
	if state == "result" or ending_early: return
	if enemy_form == "战地小厨" and enemy_in_battle: _cook(false)
	await get_tree().create_timer(0.28, false).timeout
	if ending_early: return
	await _start_player_turn(round_number == 0)
	if ending_early: return

func _consume_enemy_card(id: String) -> void:
	enemy_cards.erase(id)
	enemy_action_point = maxi(0, enemy_action_point - 1)
	_update_hud()
	if enemy_backs.get_child_count() > 0: enemy_backs.get_child(0).queue_free()

func _start_player_turn(first := false) -> void:
	state = "turn_intro"
	turn_owner_player = true
	_cancel_selection()
	round_number += 1
	action_point = 2
	player_attacked = false
	cooked_this_turn = false
	_update_hud()
	await _banner("我 方 回 合", GREEN)
	if ending_early: return
	if not first and not deck.is_empty():
		var id := deck.pop_back() as String
		var fly := _art(board, id, Rect2(_deck_position(true), DECK_SIZE))
		fly.z_index = 160
		var target := _hand_pose(hand_cards.size(), hand_cards.size() + 1)
		var draw := _battle_tween().set_parallel(true)
		draw.tween_property(fly, "position", target.position, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		draw.tween_property(fly, "size", HAND_SIZE, 0.36)
		await draw.finished
		if ending_early: return
		fly.queue_free()
		hand_cards.append(id)
		_rebuild_hand()
	state = "player_turn"
	_update_hud()
	_layout_hand()

func _banner(value: String, color: Color) -> void:
	var banner := _panel(board, Rect2(415, 295, 450, 94), Color(0.09,0.19,0.19,0.93), color, 2, 3)
	banner.z_index = 170
	_text(banner, value, Rect2(0, 0, 450, 94), 34, CREAM, true)
	banner.modulate.a = 0
	banner.position.x = 365
	var enter := _battle_tween().set_parallel(true)
	enter.tween_property(banner, "position:x", 415.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.tween_property(banner, "modulate:a", 1.0, 0.18)
	_sound(520)
	await enter.finished
	if ending_early: return
	await get_tree().create_timer(0.38, false).timeout
	if ending_early: return
	var leave := _battle_tween().set_parallel(true)
	leave.tween_property(banner, "position:x", 445.0, 0.22)
	leave.tween_property(banner, "modulate:a", 0.0, 0.22)
	await leave.finished
	if ending_early: return
	banner.queue_free()

func _update_hud() -> void:
	if not is_instance_valid(end_button): return
	var taking_turn := state in ["turn_intro", "player_turn", "enemy_turn", "resolving", "ending"]
	player_hud.sync(player_hp, action_point, taking_turn and turn_owner_player)
	enemy_hud.sync(enemy_hp, enemy_action_point, taking_turn and not turn_owner_player)
	deck_label.text = ""
	var active := state == "player_turn"
	end_button.disabled = not active
	end_button.text = "结束\n回合" if active else ("敌方\n回合" if state == "enemy_turn" else "请稍候")
	phase_label.text = ""
	if is_instance_valid(battle_menu): battle_menu.gear.disabled = state == "result" or ending_early
	hint.text = ""
	(player_field.get_node("Tag") as Label).text = "" if not player_attacked else "已出击"
	if player_field.has_node("Stats"):
		var pstats := player_field.get_node("Stats") as Label
		pstats.text = "攻击 %d  生命 %d  饱腹 %d  护盾 %d" % [2, 5, 6, 0]
	if enemy_field.has_node("Stats"):
		var estats := enemy_field.get_node("Stats") as Label
		estats.text = "攻击 2  生命 5"

func _float(target: Control, value: String, color: Color, offset := Vector2.ZERO) -> void:
	var label := _text(board, value, Rect2(target.position + Vector2(-50, 28) + offset, Vector2(232, 50)), 30 if value == "−2" else 22, color, true)
	label.z_index = 190
	label.add_theme_color_override("font_outline_color", Color("#253c3b"))
	label.add_theme_constant_override("outline_size", 5)
	var tween := _battle_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 54, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.45)
	tween.finished.connect(label.queue_free)

func _result(victory: bool) -> void:
	if state == "result": return
	state = "result"
	ending_early = true
	for tween in battle_tweens:
		if tween.is_valid(): tween.kill()
	battle_tweens.clear()
	_cancel_selection()
	_update_hud()
	for child in board.get_children():
		if child.z_index >= 100: child.hide()
	get_viewport().gui_release_focus()
	result_ready = false
	result_armed = false
	result_e_held = result_e_held or Input.is_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_E)
	var overlay := Control.new()
	overlay.name = "Result"
	overlay.size = CANVAS
	overlay.z_index = 500
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	board.add_child(overlay)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.size = CANVAS
	veil.color = Color(0.025, 0.035, 0.03, 0.78)
	veil.modulate.a = 0
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(veil)
	var wordmark := TextureRect.new()
	wordmark.name = "Wordmark"
	wordmark.texture = VICTORY_RESULT if victory else DEFEAT_RESULT
	wordmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wordmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wordmark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	wordmark.position = Vector2(312, 145)
	wordmark.size = Vector2(656, 400)
	wordmark.pivot_offset = wordmark.size * 0.5
	wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wordmark.modulate.a = 0
	wordmark.scale = Vector2.ONE * 0.9
	overlay.add_child(wordmark)
	var prompt := ContinuePrompt.new()
	prompt.name = "ContinuePrompt"
	overlay.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -84
	prompt.offset_bottom = -40
	prompt.modulate.a = 0
	var loser := enemy_field if victory else player_field
	var fall := _battle_tween().set_parallel(true)
	fall.tween_property(loser, "rotation", 0.2, 0.45)
	fall.tween_property(loser, "position:y", loser.position.y + 30, 0.45)
	fall.tween_property(loser, "modulate:a", 0.0, 0.45)
	await fall.finished
	dim.hide()
	var fade := _battle_tween()
	fade.tween_property(veil, "modulate:a", 1.0, 0.4)
	await fade.finished
	var intro := _battle_tween().set_parallel(true)
	intro.tween_property(wordmark, "modulate:a", 1.0, 0.3)
	intro.tween_property(wordmark, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sound(780 if victory else 260, 0.25)
	await intro.finished
	var reveal := _battle_tween()
	reveal.tween_property(prompt, "modulate:a", 1.0, 0.2)
	await reveal.finished
	result_ready = true
	result_armed = not result_e_held

func _battle_tween() -> Tween:
	battle_tweens = battle_tweens.filter(func(t: Tween): return t.is_valid())
	var tween := create_tween()
	battle_tweens.append(tween)
	return tween

func _menu_action(action: String) -> void:
	if ending_early or state == "result": return
	if action == "restart":
		_restart_battle()
		return
	player_hp = 0
	await _result(false)

func _restart_battle() -> void:
	if is_queued_for_deletion(): return
	var fresh := (load("res://scenes/battle/yaya_battle_demo.tscn") as PackedScene).instantiate()
	fresh.tutorial_battle = tutorial_battle
	fresh.tutorial_fixed = tutorial_fixed
	fresh.player_starting_health = player_starting_health
	fresh.enemy_starting_health = enemy_starting_health
	fresh.initiative_override = initiative_override
	fresh.return_scene_path = return_scene_path
	get_parent().add_child(fresh)
	if get_tree().current_scene == self: get_tree().current_scene = fresh
	process_mode = Node.PROCESS_MODE_DISABLED
	queue_free()

func _toast(value: String) -> void:
	toast.show_message(value, 1.6)

func _sound(frequency: float, seconds := 0.08) -> void:
	# 原生短音提示，不使用参考录像音轨。
	var samples := int(22050 * seconds)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var envelope := sin(PI * i / samples) * (1.0 - float(i) / samples)
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * i / 22050.0) * envelope * 13000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	audio.stream = stream
	audio.play()

func _return_menu() -> void:
	get_tree().change_scene_to_file(return_scene_path)
