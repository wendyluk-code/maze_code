extends "res://scripts/maze/fenshui_battle_guide.gd"
## 盐池入口复用分水庭非模态对白与保存机制。

func _init() -> void:
	seen_key="salt_battle_guide_seen"
	dialog_name="SaltGuideDialog"
	lines=preload("res://scripts/maze/salt_guide_script.gd").lines()

func _near_entrance(point: Vector2) -> bool:
	return point.distance_to(Salt.SPAWN)<=ENTRY_RADIUS or point.distance_to(Moss.SALT_SIDE_ARRIVAL)<=ENTRY_RADIUS
