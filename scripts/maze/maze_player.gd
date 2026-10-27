extends Node2D
## 迷宫沿用正式主角共用动画；小脚底与分步移动适配窄路。
const Roads := preload("res://data/maze/entry_roads.gd")
const HeroAnimation := preload("res://scripts/characters/hero_animation.gd")
const ANIMATIONS: SpriteFrames = HeroAnimation.ANIMATIONS
const FRAME_FOOT := HeroAnimation.FRAME_FOOT
const SPEED := 130.0
var input_locked := false
var body: Sprite2D
var facing := Vector2.DOWN
var animation_name: StringName = &"front_idle"
var animation_frame := 0
var _appearance := HeroAnimation.new()
var _walking := false
var capture_flow: Node
var sprint_held := false
var sprinting := false
var sprint_exhausted := false
var terrain: RefCounted = Roads.new()
var water_ripples: Node2D
var portal_obstacles: Array[Node2D] = []

func clear_combat_input() -> void:
	sprint_held=false
	sprinting=false
	sprint_exhausted=false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode==KEY_SHIFT:
		if not event.pressed:
			clear_combat_input()
		elif not event.echo and is_instance_valid(capture_flow) and not capture_flow.combat_paused():
			sprint_held=true

func _ready() -> void:
	add_to_group("maze_player")
	_appearance.match_reference_view = true
	_appearance.install(self)
	body = _appearance.body
	if terrain.has_method("terrain_multiplier") and terrain.get_script() != preload("res://data/maze/salt_pool_roads.gd"):
		water_ripples = preload("res://scripts/maze/shallow_water_ripples.gd").new()
		water_ripples.name = "ShallowWaterRipples"
		add_child(water_ripples)
		move_child(water_ripples,0)
	_update_animation()

func _physics_process(delta: float) -> void:
	if input_locked or (is_instance_valid(capture_flow) and capture_flow.combat_paused()):
		clear_combat_input()
		_walking = false
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var before := position
	var charge := 1.0
	if is_instance_valid(capture_flow): charge=capture_flow.sprint_charge()
	if sprint_held and charge<=0.00001: sprint_exhausted=true
	sprinting=sprint_held and not sprint_exhausted and charge>0.0 and not direction.is_zero_approx()
	var terrain_speed: float = terrain.terrain_multiplier(position) if terrain.has_method("terrain_multiplier") else 1.0
	var next := _move_with_portals(position, direction * SPEED * terrain_speed * (1.5 if sprinting else 1.0) * delta)
	if not is_instance_valid(capture_flow) or capture_flow.movement_allowed(position,next):
		position = next
	if not direction.is_zero_approx():
		facing = direction
	_walking = position.distance_to(before) > 0.01
	sprinting=sprinting and _walking

func _move_with_portals(origin: Vector2, displacement: Vector2) -> Vector2:
	if not displacement.is_finite(): return origin
	var count := maxi(1, ceili(displacement.length() / 2.0))
	var step := displacement / float(count)
	var current := origin
	for i in count:
		var next: Vector2 = terrain.move_on_road(current, step)
		if _portal_step_allowed(current, next):
			current = next
		else:
			for axis in [Vector2(step.x, 0), Vector2(0, step.y)]:
				next = terrain.move_on_road(current, axis)
				if _portal_step_allowed(current, next): current = next
	return current

func _portal_step_allowed(origin: Vector2, target: Vector2) -> bool:
	for portal in portal_obstacles:
		if is_instance_valid(portal) and portal.blocks_step(origin, target): return false
	return true

func _process(delta: float) -> void:
	_update_animation(delta)

func _update_animation(delta: float = 0.0) -> void:
	_appearance.update(facing, _walking and not input_locked and is_physics_processing(), delta, sprinting)
	animation_name = _appearance.animation_name
	animation_frame = _appearance.animation_frame
