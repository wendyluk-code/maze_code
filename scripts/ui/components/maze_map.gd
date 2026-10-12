extends Control
## 迷宫地图入口与模态查看器，展示现有进度，不写存档、不改变解锁规则。
const MapView := preload("res://scripts/ui/components/maze_map_view.gd")
const MapProjection := preload("res://data/maze/entry_map_projection.gd")
const Chests := preload("res://data/maze/entry_chests.gd")
const MapButton := preload("res://scripts/ui/components/maze_map_button.gd")
const Toast := preload("res://scripts/ui/components/feedback_toast.gd")
var maze: Node
var mini_button: Button
var mini_view: Control
var full_view: Control
var overlay: ColorRect
var panel: Control
var shallow_button: Button
var deep_button: Button
var close_button: Button
var locked_toast: Label
var expanded := false
var visible_resources: Array[Dictionary] = []
var _projection := MapProjection.new()
var _locked_before := false
var _physics_before := true
var _focus_before: Control
var _refresh_time := 0.0
var _unlocked := false
var _map_space: Control
var _header: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SproutTheme.make_theme()
	_build_mini()
	_build_overlay()
	resized.connect(_layout)
	_layout()
	refresh_resources()

func _build_mini() -> void:
	mini_button = MapButton.new()
	mini_button.size = Vector2(100,100)
	mini_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		mini_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mini_button.pressed.connect(open_map)
	add_child(mini_button)
	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.size = mini_button.size
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color.TRANSPARENT
	shadow_style.set_corner_radius_all(50)
	shadow_style.shadow_color = Color(0.20,0.16,0.10,0.18)
	shadow_style.shadow_size = 8
	shadow_style.shadow_offset = Vector2(0,2)
	shadow.add_theme_stylebox_override("panel",shadow_style)
	mini_button.add_child(shadow)
	mini_view = MapView.new()
	mini_view.compact = true
	mini_view.size = mini_button.size
	mini_button.add_child(mini_view)

func _button(text: String) -> SproutButton:
	var button := SproutButton.new()
	button.configure(text).set_icon_visible(false).set_focus_visual(false)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, SproutTheme.CREAM if state == "font_color" else Color("ffd56a"))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_outline_color", Color(0.025,0.035,0.03,0.8))
	button.add_theme_constant_override("outline_size", 3)
	return button

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.025,0.045,0.035,0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panel)
	_map_space = Control.new()
	_map_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_map_space)
	full_view = MapView.new()
	_map_space.add_child(full_view)
	_map_space.resized.connect(_layout_full_map)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 28)
	panel.add_child(_header)
	shallow_button = _button("迷宫浅层")
	_header.add_child(shallow_button)
	shallow_button.custom_minimum_size = Vector2(128,44)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color.TRANSPARENT
	selected.border_width_bottom = 2
	selected.border_color = Color("e4bf73")
	for state in ["normal", "hover", "pressed"]:
		shallow_button.add_theme_stylebox_override(state, selected)
	shallow_button.add_theme_color_override("font_color", Color("ffd56a"))
	shallow_button.pressed.connect(func(): shallow_button.grab_focus())
	deep_button = _button("迷宫深层")
	_header.add_child(deep_button)
	deep_button.custom_minimum_size = Vector2(128,44)
	deep_button.pressed.connect(func(): locked_toast.show_message("深层暂未解锁"))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(space)
	close_button = _button("×")
	close_button.tooltip_text = "关闭地图"
	_header.add_child(close_button)
	close_button.custom_minimum_size = Vector2(44,44)
	close_button.add_theme_font_size_override("font_size", 34)
	close_button.pressed.connect(close_map)
	locked_toast = Toast.attach_to(overlay)
	# 将焦点环限制在地图内，遮罩阻止鼠标穿透。
	var buttons := [shallow_button, deep_button, close_button]
	for i in buttons.size():
		buttons[i].focus_next = buttons[i].get_path_to(buttons[(i+1)%buttons.size()])
		buttons[i].focus_previous = buttons[i].get_path_to(buttons[(i+buttons.size()-1)%buttons.size()])
	overlay.hide()

func _layout() -> void:
	mini_button.position = Vector2(size.x - mini_button.size.x - 20,20)
	if not is_instance_valid(panel):
		return
	panel.position = Vector2.ZERO
	panel.size = size
	_map_space.position = Vector2(24,84)
	_map_space.size = Vector2(maxf(1,size.x-48), maxf(1,size.y-108))
	_layout_full_map()
	_header.position = Vector2(_map_space.position.x + full_view.position.x,24)
	_header.size = Vector2(full_view.size.x,44)

func _layout_full_map() -> void:
	var available := _map_space.size
	var factor := minf(available.x / MapProjection.SIZE.x, available.y / MapProjection.SIZE.y)
	full_view.size = MapProjection.SIZE * factor
	full_view.position = (available - full_view.size) * 0.5

func refresh_resources() -> void:
	var progress: Dictionary = SaveManager.departure_state().map
	_unlocked = not progress.unlocked_floors.is_empty() and progress.visible_regions.has("old_salt_pool")
	visible_resources.clear()
	for config in Chests.all():
		_add_resource(config, "chest", SaveManager.is_chest_claimed(config.id))

func _add_resource(config: Dictionary, kind: String, claimed: bool) -> void:
	var point := _projection.project(config.position)
	if not claimed and MapProjection.is_revealed(point, _unlocked):
		visible_resources.append({"id": config.id, "kind": kind, "position": point})

func _process(delta: float) -> void:
	if not is_instance_valid(maze) or not is_instance_valid(maze.player):
		return
	_refresh_time -= delta
	if _refresh_time <= 0:
		refresh_resources()
		_refresh_time = 0.15
	var point := _projection.project(maze.player.position)
	mini_view.sync(point, maze.player.facing, visible_resources, _unlocked)
	if expanded:
		full_view.sync(point, maze.player.facing, visible_resources, _unlocked)
	mini_button.disabled = expanded or not maze._entry_ready or maze._busy or maze.player.input_locked or maze.confirmation.visible

func open_map() -> void:
	if expanded or not maze._entry_ready or maze._busy or maze.player.input_locked or maze.confirmation.visible:
		return
	_locked_before = maze.player.input_locked
	_physics_before = maze.player.is_physics_processing()
	_focus_before = get_viewport().gui_get_focus_owner()
	expanded = true
	mini_button.hide()
	maze.player.input_locked = true
	maze.player.set_physics_process(false)
	maze.toast_label.dismiss()
	maze._update_prompts()
	maze._update_chest_target()
	mini_button.disabled = true
	refresh_resources()
	full_view.sync(_projection.project(maze.player.position), maze.player.facing, visible_resources, _unlocked)
	locked_toast.dismiss()
	overlay.show()
	_layout()
	close_button.grab_focus()

func close_map() -> void:
	if not expanded:
		return
	expanded = false
	mini_button.show()
	overlay.hide()
	locked_toast.dismiss()
	maze.player.input_locked = _locked_before or not maze._entry_ready
	maze.player.set_physics_process(_physics_before)
	maze._interact_armed = not Input.is_action_pressed("interact")
	maze._update_prompts()
	maze._update_chest_target()
	mini_button.disabled = false
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	else:
		get_viewport().gui_release_focus()

func _input(event: InputEvent) -> void:
	if not expanded or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_map()
	elif event.is_action("interact") or event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		get_viewport().set_input_as_handled()
