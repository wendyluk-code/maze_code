extends Control
## 只呈现已提交的探索准备状态；面板不是正式迷宫地图，也不切换场景。

signal map_closed

var _summary: PanelContainer
var _objective: Label
var _modal: ColorRect
var _map_text: Label
var _open := false
var _locked_player: Node
var _input_before := false
var _physics_before := true
var _entrance: Node2D
var _cards_button: SproutButton
var _card_viewer: Control

func _ready() -> void:
	add_to_group("departure_panel")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SproutTheme.make_theme()
	_summary = PanelContainer.new()
	_summary.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	_summary.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_summary.position = Vector2(-410, -200)
	_summary.size = Vector2(390, 180)
	add_child(_summary)
	var summary_rows := VBoxContainer.new()
	_summary.add_child(summary_rows)
	_objective = _label("", 18)
	_objective.custom_minimum_size.x = 350
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_rows.add_child(_objective)
	var view := SproutButton.new()
	view.configure("查看浅层地图与队伍")
	view.set_icon_visible(false)
	view.pressed.connect(open_map)
	summary_rows.add_child(view)
	_cards_button = SproutButton.new()
	_cards_button.configure("查看芽芽与铁山卡组")
	_cards_button.set_icon_visible(false)
	_cards_button.pressed.connect(_open_cards)
	summary_rows.add_child(_cards_button)
	_modal = ColorRect.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.color = Color(0.04, 0.07, 0.05, 0.78)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-370, -250)
	panel.size = Vector2(740, 500)
	_modal.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	rows.add_child(_label("迷宫浅层 · 出发准备", 28))
	_map_text = _label("", 20)
	_map_text.custom_minimum_size = Vector2(680, 300)
	_map_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_map_text)
	var close := SproutButton.new()
	close.configure("确认")
	close.set_icon_visible(false)
	close.pressed.connect(close_map)
	rows.add_child(close)
	_refresh()
	_install_entrance.call_deferred()

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", SproutTheme.INK)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _install_entrance() -> void:
	var root := get_parent().get_parent()
	if root.name != "RestaurantMap":
		return
	_entrance = Node2D.new()
	_entrance.name = "DepartureEntrance"
	_entrance.set_script(load("res://scripts/departure_entrance.gd"))
	_entrance.position = Vector2(140, 820)
	root.add_child(_entrance)
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		player.interacted.connect(_on_interacted)
	get_parent()._rebuild_buttons()

func _on_interacted(target: Node2D) -> void:
	if target == _entrance and SaveManager.is_ready_to_depart() and not _open:
		var player := get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.nearest_interactable() == target:
			open_map()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var state := SaveManager.departure_state()
	_summary.visible = SaveManager.is_ready_to_depart() and not _open
	_objective.text = "准备同行\n" + str(state.objective) + ("\n初始卡组：16 张已保存" if SaveManager.cards_unlocked() else "\n初始卡组：查看后解锁并保存")
	_cards_button.visible = SaveManager.is_ready_to_depart() and not _open and not _cards_open()
	if SaveManager.cards_unlocked():
		_cards_button.text = "查看芽芽与铁山卡组（已保存）"
	var map: Dictionary = state.map
	var floor_text := "第一层：已解锁" if map.unlocked_floors == [1] else "第一层：未解锁"
	var region_text := "旧盐池：可见" if map.visible_regions == ["old_salt_pool"] else "旧盐池：迷雾"
	var party_text := "芽芽、铁山" if state.party == ["yaya", "tieshan"] else "尚未决定同行"
	_map_text.text = "%s\n%s\n其余区域：迷雾 · 更深层：未解锁\n\n探索队伍：%s\n%s\n\n%s\n区域状态示意，正式迷宫地图尚未开放。" % [floor_text, region_text, party_text, state.objective, ("初始卡组：16 张已保存" if SaveManager.cards_unlocked() else "初始卡组：查看准备同行面板中的卡组按钮")]

func _cards_open() -> bool:
	return is_instance_valid(_card_viewer) and _card_viewer.visible

func _open_cards() -> void:
	if not SaveManager.is_ready_to_depart():
		return
	var result := SaveManager.unlock_ch1_cards()
	if not result.success:
		return
	if not is_instance_valid(_card_viewer):
		_card_viewer = Control.new()
		_card_viewer.name = "CardViewer"
		_card_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_card_viewer.set_script(load("res://scripts/ui/components/card_preview.gd"))
		add_child(_card_viewer)
		_card_viewer.close_requested.connect(_close_cards)
	_card_viewer.visible = true
	_cards_button.visible = false

func _close_cards() -> void:
	if is_instance_valid(_card_viewer):
		_card_viewer.visible = false
	_refresh()

func open_map() -> void:
	if _open or SaveManager.departure_state().map.unlocked_floors != [1]:
		return
	_open = true
	_modal.visible = true
	_locked_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_locked_player):
		_input_before = _locked_player.input_locked
		_physics_before = _locked_player.is_physics_processing()
		_locked_player.input_locked = true
		_locked_player.set_physics_process(false)
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide):
		guide.set_modal_suppressed(true)
	_refresh()

func close_map() -> void:
	if not _open:
		return
	_open = false
	_modal.visible = false
	if is_instance_valid(_locked_player):
		_locked_player.input_locked = _input_before
		_locked_player.set_physics_process(_physics_before)
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide):
		guide.set_modal_suppressed(false)
	map_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_map()
