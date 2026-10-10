extends Node2D
## 餐厅左侧迷宫入口；介绍时的高亮由章节收尾控制器管理。

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
	if lit and not is_in_group("interactable"):
		add_to_group("interactable")
		var ui := get_tree().get_first_node_in_group("ui_layer")
		if is_instance_valid(ui):
			ui._rebuild_buttons.call_deferred()
	elif not lit and is_in_group("interactable"):
		remove_from_group("interactable")
