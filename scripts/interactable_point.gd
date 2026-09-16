extends Node2D
## interactive point: registers to interactable group and shows a display name
@export var display_name := "interaction"
## 按钮显示位置相对交互点的偏移（世界坐标，像素），不影响交互触发点
@export var ui_offset := Vector2.ZERO

func _ready() -> void:
	add_to_group("interactable")
