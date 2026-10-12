extends Control
## 复用餐厅道具按钮；屏幕像素固定，锚定目标世界坐标，距离由调用方判断。
signal activated
const BUTTON_SCENE := preload("res://scenes/ui/interact_button.tscn")
var button: Control
var world_anchor := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = BUTTON_SCENE.instantiate()
	add_child(button)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for child in button.find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.gui_input.connect(_on_button_input)
	# 等本帧相机更新完成后再投影，避免缓动时按钮落后地图一帧。
	RenderingServer.frame_pre_draw.connect(_update_position)
	hide()

func configure(action: String, anchor: Vector2) -> void:
	world_anchor = anchor
	button.get_node("Content/ActionLabel").text = action
	var width: float = button.get_node("Content").get_combined_minimum_size().x
	button.size = Vector2(maxf(140, width + 24), 48)
	_place()

func _update_position() -> void:
	if visible:
		_place()

func _place() -> void:
	var screen := get_viewport().get_canvas_transform() * world_anchor
	var viewport := get_viewport_rect().size
	position = screen - Vector2(button.size.x * 0.5, button.size.y + 8)
	position.x = clampf(position.x, 8, maxf(8, viewport.x - button.size.x - 8))
	position.y = clampf(position.y, 8, maxf(8, viewport.y - button.size.y - 8))

func _on_button_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		activated.emit()
