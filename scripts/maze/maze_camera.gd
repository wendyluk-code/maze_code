extends Camera2D
const Roads := preload("res://data/maze/entry_roads.gd")
var target: Node2D
var map_size := Roads.SIZE
var roar_shake := 0.0
var shake_clock := 0.0
var mining_shake := 0.0

func shake_mining() -> void:
	mining_shake = 0.18

func set_roar_shake(remaining: float) -> void:
	roar_shake=remaining
	if remaining<=0 and mining_shake<=0: offset=Vector2.ZERO

func _ready() -> void:
	zoom = Vector2.ONE * 1.65
	make_current()
	snap_to_target()

func _process(delta: float) -> void:
	shake_clock+=delta
	offset=Vector2(sin(shake_clock*83),cos(shake_clock*97))*4.0*minf(1.0,roar_shake/0.15) if roar_shake>0 else Vector2.ZERO
	mining_shake = maxf(0.0, mining_shake - delta)
	offset += Vector2(sin(shake_clock*109.0), cos(shake_clock*89.0))*2.5*(mining_shake/0.18)
	if is_instance_valid(target):
		global_position = _clamp_position(global_position.lerp(target.global_position, 1.0 - exp(-7.0 * delta)))

func _clamp_position(point: Vector2) -> Vector2:
	# 窗口变大时也确保可见画面不超出原图。
	var viewport_size := get_viewport_rect().size
	var factor := maxf(1.65, maxf(viewport_size.x / map_size.x, viewport_size.y / map_size.y))
	zoom = Vector2.ONE * factor
	var half := viewport_size / zoom * 0.5
	return Vector2(clampf(point.x, half.x, map_size.x - half.x), clampf(point.y, half.y, map_size.y - half.y))

func snap_to_target() -> void:
	mining_shake = 0.0
	if is_instance_valid(target):
		global_position = _clamp_position(target.global_position)
		reset_smoothing()