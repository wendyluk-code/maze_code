extends Node2D
## 复用餐厅左侧门的位置，仅显示准备态亮光；正式出发由后续票据接入。

var display_name := "迷宫入口"
var ui_offset := Vector2(0, -110)
var lit := false

func _ready() -> void:
	z_index = 2
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var next_lit: bool = SaveManager.departure_state().entrance_lit
	if next_lit != lit:
		lit = next_lit
		queue_redraw()
	if lit and not is_in_group("interactable"):
		add_to_group("interactable")
		var ui := get_tree().get_first_node_in_group("ui_layer")
		if is_instance_valid(ui):
			ui._rebuild_buttons.call_deferred()
	elif not lit and is_in_group("interactable"):
		remove_from_group("interactable")

func _draw() -> void:
	if not lit:
		return
	draw_circle(Vector2(0, -30), 80, Color(1.0, 0.83, 0.30, 0.16))
	draw_arc(Vector2(0, -30), 62, PI, TAU, 32, Color(1.0, 0.90, 0.50, 0.85), 5.0, true)
	draw_line(Vector2(-62, -30), Vector2(-62, 48), Color(1.0, 0.90, 0.50, 0.85), 5.0, true)
	draw_line(Vector2(62, -30), Vector2(62, 48), Color(1.0, 0.90, 0.50, 0.85), 5.0, true)
