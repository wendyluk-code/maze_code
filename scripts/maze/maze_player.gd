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

func _ready() -> void:
	add_to_group("maze_player")
	_appearance.match_reference_view = true
	_appearance.install(self)
	body = _appearance.body
	_update_animation()

func _physics_process(delta: float) -> void:
	if input_locked:
		_walking = false
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var before := position
	position = Roads.move_on_road(position, direction * SPEED * delta)
	if not direction.is_zero_approx():
		facing = direction
	_walking = position.distance_to(before) > 0.01

func _process(delta: float) -> void:
	_update_animation(delta)

func _update_animation(delta: float = 0.0) -> void:
	_appearance.update(facing, _walking and not input_locked and is_physics_processing(), delta)
	animation_name = _appearance.animation_name
	animation_frame = _appearance.animation_frame

