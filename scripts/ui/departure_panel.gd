extends Control
## 展示浅层地图和已提交的探索准备状态，不切换场景。

signal map_closed

var _modal: ColorRect
var _map_panel: Control
var _map_image: TextureRect
var _continue_prompt: HBoxContainer
var _map_tween: Tween
var _open := false
var _locked_player: Node
var _input_before := false
var _physics_before := true
var _entrance: Node2D
var _card_viewer: Control
var _map_input_armed := false
var _tracker: Control
var _tracker_alpha := 1.0
var _tracker_disabled := false

func _ready() -> void:
	add_to_group("departure_panel")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 300
	theme = SproutTheme.make_theme()
	_modal = ColorRect.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.visible = false
	add_child(_modal)
	_modal.gui_input.connect(_on_backdrop_input)
	var panel := Control.new()
	_map_panel = panel
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_modal.add_child(panel)
	_map_image = TextureRect.new()
	_map_image.name = "ShallowMap"
	_map_image.texture = load("res://assets/maps/shallow_floor.png")
	_map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_image.stretch_mode = TextureRect.STRETCH_SCALE
	_map_image.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var fog := ShaderMaterial.new()
	fog.shader = load("res://scripts/ui/shallow_map_fog.gdshader")
	var obscured := _map_image.texture.get_image()
	obscured.generate_mipmaps()
	fog.set_shader_parameter("obscured_map", ImageTexture.create_from_image(obscured))
	_map_image.material = fog
	panel.add_child(_map_image)
	_map_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_continue_prompt = preload("res://scripts/ui/components/continue_prompt.gd").new()
	_modal.add_child(_continue_prompt)
	resized.connect(_layout_map)
	_layout_map()
	_install_entrance.call_deferred()

func _layout_map() -> void:
	if not is_instance_valid(_map_panel):
		return
	var width := minf(minf(1200.0, size.x - 64.0), (size.y - 116.0) * 1672.0 / 941.0)
	var height := width * 941.0 / 1672.0
	_map_panel.size = Vector2(width, height)
	_map_panel.position = Vector2((size.x - width) * 0.5, (size.y - 60.0 - height) * 0.5)
	_map_panel.pivot_offset = _map_panel.size * 0.5
	_continue_prompt.position = Vector2(0, size.y - 60)
	_continue_prompt.size = Vector2(size.x, 36)

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
	if SaveManager.is_chapter_1_done():
		return # 章后由 RestaurantHUD 先二次确认。
	if target == _entrance and SaveManager.is_ready_to_depart() and not _open:
		var player := get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) and player.nearest_interactable() == target:
			open_map()

func _cards_open() -> bool:
	return is_instance_valid(_card_viewer) and _card_viewer.visible

func open_task_map() -> void:
	open_map()

func open_task_cards() -> void:
	_open_cards()

func confirm_task_chapter() -> void:
	_complete_chapter()

func _open_cards() -> void:
	if not SaveManager.is_ready_to_depart() and not SaveManager.is_chapter_1_complete():
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

func _complete_chapter() -> void:
	if not SaveManager.is_ready_to_depart() or SaveManager.is_chapter_1_complete():
		return
	var result: Dictionary = TutorialManager.confirm_chapter_1()
	if not result.success:
		return

func _close_cards() -> void:
	if is_instance_valid(_card_viewer):
		_card_viewer.visible = false

func open_map() -> void:
	if _open or SaveManager.departure_state().map.unlocked_floors != [1]:
		return
	_open = true
	_map_input_armed = false
	_tracker = get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(_tracker):
		_tracker.collapse_details()
		_tracker_alpha = _tracker.modulate.a
		_tracker_disabled = _tracker._task_button.disabled
		_tracker.modulate.a = 0.0
		_tracker._task_button.disabled = true
	_modal.visible = true
	_layout_map()
	if is_instance_valid(_map_tween):
		_map_tween.kill()
	_map_panel.scale = Vector2(0.88, 0.06)
	_map_panel.modulate.a = 0.0
	_continue_prompt.modulate.a = 0.0
	_map_tween = create_tween().set_parallel(true)
	_map_tween.tween_property(_map_panel, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_map_tween.tween_property(_map_panel, "modulate:a", 1.0, 0.18)
	_map_tween.tween_property(_continue_prompt, "modulate:a", 1.0, 0.18).set_delay(0.30)
	_map_tween.chain().tween_callback(func():
		_map_input_armed = not Input.is_key_pressed(KEY_E) and not Input.is_physical_key_pressed(KEY_E))
	_locked_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_locked_player):
		_input_before = _locked_player.input_locked
		_physics_before = _locked_player.is_physics_processing()
		_locked_player.input_locked = true
		_locked_player.set_physics_process(false)
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide):
		guide.set_modal_suppressed(true)

func close_map() -> void:
	if not _open:
		return
	_open = false
	if is_instance_valid(_map_tween):
		_map_tween.kill()
	_modal.visible = false
	if is_instance_valid(_tracker):
		_tracker.modulate.a = _tracker_alpha
		_tracker._task_button.disabled = _tracker_disabled
	if is_instance_valid(_locked_player):
		_locked_player.input_locked = _input_before
		_locked_player.set_physics_process(_physics_before)
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	if is_instance_valid(guide):
		guide.set_modal_suppressed(false)
	map_closed.emit()

func _on_backdrop_input(event: InputEvent) -> void:
	if _open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		close_map()

func _input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey:
		return
	if event.keycode == KEY_E or event.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		if not event.pressed:
			_map_input_armed = true
		elif _map_input_armed and not event.echo:
			close_map()
	elif event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_map()
