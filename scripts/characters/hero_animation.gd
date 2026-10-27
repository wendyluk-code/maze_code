extends RefCounted
## 正式主角的共用显示组件；移动、碰撞与输入锁由各场景控制器负责。
const ANIMATIONS: SpriteFrames = preload("res://assets/characters/hero/animation/hero_animations.tres")
const FRAME_BODY_HEIGHT := 300.0
const FRAME_FOOT := Vector2(192, 332)
## 统一沿用餐厅的人物高度、日常镜头比例和柔和脚底阴影。
const BODY_HEIGHT := 130.0
const REFERENCE_CAMERA_ZOOM := 0.85
const SHADOW := preload("res://assets/characters/tieshan/ground_shadow.png")
const SHADOW_SCALE := Vector2(0.64, 0.64)
const SHADOW_OFFSET := Vector2(0, 1)

var body: Sprite2D
var ground_shadow: Sprite2D
## 探索地图只适配镜头倍率；人物本体配置仍来自餐厅同一份。
var match_reference_view := false

var animation_name: StringName = &"front_idle"
var animation_frame := 0
var _elapsed := 0.0

func install(actor: Node2D) -> void:
	ground_shadow = Sprite2D.new()
	ground_shadow.name = "GroundShadow"
	ground_shadow.texture = SHADOW
	ground_shadow.scale = SHADOW_SCALE
	ground_shadow.position = SHADOW_OFFSET
	actor.add_child(ground_shadow)
	body = Sprite2D.new()
	body.name = "Body"
	actor.add_child(body)
	update(Vector2.DOWN, false)

func update(facing: Vector2, walking: bool, delta: float = 0.0, running: bool = false) -> void:
	var direction := "front"
	if facing.x > 0.1:
		direction = "right"
	elif facing.x < -0.1:
		direction = "left"
	elif facing.y < -0.1:
		direction = "back"
	var next := StringName(direction + ("_walk" if walking else "_idle"))
	if next != animation_name:
		animation_name = next
		animation_frame = 0
		_elapsed = 0.0
	_elapsed += delta * (1.5 if walking and running else 1.0)
	var duration := _frame_duration()
	while _elapsed >= duration:
		_elapsed -= duration
		animation_frame = (animation_frame + 1) % ANIMATIONS.get_frame_count(animation_name)
		duration = _frame_duration()
	body.texture = ANIMATIONS.get_frame_texture(animation_name, animation_frame)
	body.flip_h = false
	var view_scale := 1.0
	var camera := body.get_viewport().get_camera_2d()
	if match_reference_view and is_instance_valid(camera):
		view_scale = REFERENCE_CAMERA_ZOOM / camera.zoom.y
	body.scale = Vector2.ONE * BODY_HEIGHT / FRAME_BODY_HEIGHT * view_scale
	body.centered = false
	body.offset = -FRAME_FOOT
	body.position = Vector2.ZERO
	body.rotation = 0.08 * signf(facing.x) if walking and running else 0.0
	ground_shadow.scale = SHADOW_SCALE * view_scale
	ground_shadow.position = SHADOW_OFFSET * view_scale

func _frame_duration() -> float:
	return ANIMATIONS.get_frame_duration(animation_name, animation_frame) / ANIMATIONS.get_animation_speed(animation_name)
