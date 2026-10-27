extends Node2D
## 冒险者之家纯视觉角色循环；不修改队伍、任务、库存或存档。
signal phase_changed(value: String)

const FLOOR := Rect2(500, 470, 590, 50)
const FOOT := Vector2(192, 352)
const FRAME_HEIGHT := 312.0
const DISPLAY_MULTIPLIER := 3.0
const WALK_CLEARANCE := 300.0
var character_id := ""
var phase := "hidden"
var completed_cycles := 0
var body: AnimatedSprite2D
var _rng := RandomNumberGenerator.new()
var _remaining := 0.0
var _duration := 1.0
var _target := Vector2.ZERO
var _speed := 40.0
var _walks_left := 0
var _neighbours: Callable

func configure(id: String, neighbours: Callable) -> void:
	character_id = id
	_neighbours = neighbours

func _ready() -> void:
	add_to_group("home_wanderer")
	_rng.randomize()
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/characters/tieshan/ground_shadow.png")
	shadow.scale = Vector2(0.42, 0.3) if character_id == "yaya" else Vector2(0.55, 0.35)
	shadow.scale *= DISPLAY_MULTIPLIER
	shadow.modulate.a = 0.55
	add_child(shadow)
	body = AnimatedSprite2D.new()
	body.sprite_frames = load("res://assets/characters/home/%s_home_soft.tres" % character_id)
	body.centered = false
	body.offset = -FOOT
	body.scale = Vector2.ONE * (86.0 if character_id == "yaya" else 112.0) * DISPLAY_MULTIPLIER / FRAME_HEIGHT
	add_child(body)
	body.play("idle")
	modulate.a = 0.0
	_set_phase("hidden", _rng.randf_range(1.0, 3.5))

func _process(delta: float) -> void:
	_remaining -= delta
	match phase:
		"hidden":
			if _remaining <= 0:
				var spawn_point := _choose_point(false)
				if not _is_clear(spawn_point, WALK_CLEARANCE):
					_remaining = 1.0
					return
				position = spawn_point
				body.flip_h = _rng.randf() < 0.5
				body.play("idle")
				_set_phase("fade_in", 0.8)
		"fade_in":
			modulate.a = smoothstep(0.0, 1.0, 1.0 - maxf(_remaining, 0.0) / _duration)
			if _remaining <= 0:
				modulate.a = 1.0
				_walks_left = _rng.randi_range(1, 2)
				_start_walk()
		"walk":
			var movement := _target - position
			if absf(movement.x) > 2.0:
				body.flip_h = movement.x < 0.0
			var next := position.move_toward(_target, _speed * delta)
			if _is_clear(next, WALK_CLEARANCE):
				position = next
			else:
				_remaining = 0.0
			if position.distance_to(_target) < 1.0 or _remaining <= 0:
				body.play("idle")
				_set_phase("idle", _rng.randf_range(1.8, 3.0))
		"idle":
			if _remaining <= 0:
				if _walks_left > 0:
					_start_walk()
				else:
					body.play("rest")
					_set_phase("rest", _rng.randf_range(3.5, 5.5))
		"rest":
			if _remaining <= 0:
				_set_phase("fade_out", 0.9)
		"fade_out":
			modulate.a = smoothstep(0.0, 1.0, maxf(_remaining, 0.0) / _duration)
			if _remaining <= 0:
				modulate.a = 0.0
				completed_cycles += 1
				_set_phase("hidden", _rng.randf_range(3.0, 6.0))

func _start_walk() -> void:
	_walks_left -= 1
	_target = _choose_point(true)
	_speed = _rng.randf_range(34.0, 46.0)
	body.play("walk")
	_set_phase("walk", position.distance_to(_target) / _speed + 0.1)

func _choose_point(walking: bool) -> Vector2:
	for attempt in 24:
		var candidate := Vector2(_rng.randf_range(FLOOR.position.x, FLOOR.end.x), _rng.randf_range(FLOOR.position.y, FLOOR.end.y))
		if walking:
			var offset := Vector2(_rng.randf_range(-180, 180), _rng.randf_range(-70, 70))
			candidate = (position + offset).clamp(FLOOR.position, FLOOR.end)
			if position.distance_to(candidate) < 70.0:
				continue
		if _is_clear(candidate, WALK_CLEARANCE + 25.0):
			return candidate
	# 候选耗尽时选较远端点；出现前再次检查间距，拥挤时保持隐藏并稍后重试。
	var fallback := FLOOR.get_center()
	var best_distance := -1.0
	for candidate in [Vector2(FLOOR.position.x, 495), Vector2(FLOOR.end.x, 495)]:
		var nearest := INF
		for other in _neighbours.call():
			if other != self and is_instance_valid(other) and other.phase != "hidden":
				nearest = minf(nearest, candidate.distance_to(other.position))
		if nearest > best_distance:
			best_distance = nearest
			fallback = candidate
	return fallback

func _is_clear(point: Vector2, separation: float) -> bool:
	if not _neighbours.is_valid():
		return true
	for other in _neighbours.call():
		if other != self and is_instance_valid(other) and other.phase != "hidden" and point.distance_to(other.position) < separation:
			return false
	return true

func _set_phase(value: String, seconds: float) -> void:
	phase = value
	_duration = seconds
	_remaining = seconds
	phase_changed.emit(value)
