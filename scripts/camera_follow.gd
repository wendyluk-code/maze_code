extends Camera3D
## 平滑跟随目标相机

@export var target_path: NodePath
@export var offset := Vector3(10.5, 12.5, 12.5)
@export var smooth := 5.0
@export var look_height := 1.2

func _ready() -> void:
	var t := get_node_or_null(target_path) as Node3D
	if t:
		global_position = t.global_position + offset
		look_at(t.global_position + Vector3(0, look_height, 0))

func _process(delta: float) -> void:
	var t := get_node_or_null(target_path) as Node3D
	if t == null:
		return
	var goal := t.global_position + offset
	global_position = global_position.lerp(goal, 1.0 - exp(-smooth * delta))
	look_at(t.global_position + Vector3(0, look_height, 0))