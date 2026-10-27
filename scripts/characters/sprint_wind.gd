extends Node2D
## 餐厅加速的轻薄风线；仅观察实际位移，不参与移动或数值计算。
var strength := 0.0
var direction := Vector2.RIGHT
var _previous := Vector2.ZERO
var _phase := 0.0
var _moving := false

func _ready() -> void:
	get_parent().move_child(self, 0)
	_previous = get_parent().global_position

func _physics_process(_delta: float) -> void:
	var actor = get_parent()
	var displacement: Vector2 = actor.global_position - _previous
	_previous = actor.global_position
	_moving = displacement.length() > 0.05 and displacement.length() < 40.0
	if _moving:
		direction = displacement.normalized()

func _process(delta: float) -> void:
	var actor = get_parent()
	var active: bool = _moving and Input.is_physical_key_pressed(KEY_SHIFT) and not actor.input_locked and actor.is_physics_processing()
	strength = move_toward(strength, 1.0 if active else 0.0, delta * (12.0 if active else 7.0))
	_phase += delta * 5.0
	queue_redraw()

func _draw() -> void:
	if strength <= 0.001: return
	for line in 4:
		var length := 40.0 + 8.0 * sin(_phase + float(line) * 1.7)
		var head := Vector2(0, -18.0 - float(line) * 17.0) - direction * 18.0
		var side := Vector2(-direction.y, direction.x)
		var previous := head
		for segment in range(1, 13):
			var t := float(segment) / 12.0
			var point := head - direction * length * t + side * sin(t * PI) * 2.5
			var taper := sin(t * PI)
			draw_line(previous, point, Color(1.0, 0.99, 0.94, strength * 0.75 * taper), 0.65 + taper * 0.8, true)
			previous = point
