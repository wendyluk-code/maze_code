extends Camera2D
const Roads := preload("res://data/maze/entry_roads.gd")
var target: Node2D

func _ready() -> void:
	zoom = Vector2.ONE * 1.65
	make_current()
	snap_to_target()

func _process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = _clamp_position(global_position.lerp(target.global_position, 1.0 - exp(-7.0 * delta)))

func _clamp_position(point: Vector2) -> Vector2:
	# 窗口变大时也确保可见画面不超出原图。
	var viewport_size := get_viewport_rect().size
	var factor := maxf(1.65, maxf(viewport_size.x / Roads.SIZE.x, viewport_size.y / Roads.SIZE.y))
	zoom = Vector2.ONE * factor
	var half := viewport_size / zoom * 0.5
	return Vector2(clampf(point.x, half.x, Roads.SIZE.x - half.x), clampf(point.y, half.y, Roads.SIZE.y - half.y))

func snap_to_target() -> void:
	if is_instance_valid(target):
		global_position = _clamp_position(target.global_position)
		reset_smoothing()
