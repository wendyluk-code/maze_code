extends "res://scripts/interactable_point.gd"
## 所有章节复用独立前台与原近距离交互。
func _process(_delta: float) -> void:
	if not is_in_group("interactable"):
		add_to_group("interactable")
