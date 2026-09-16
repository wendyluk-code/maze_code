extends CharacterBody3D
## 3D 村庄主角：相机相对方向移动 + 按朝向切换三视图贴图 + 行走弹跳

const SPEED := 6.0
const GRAVITY := 18.0
const WALK_RADIUS := 12.8
const BODY_H := 2.3

const TEX_FRONT := preload("res://assets/characters/hero/hero_front.png")
const TEX_BACK := preload("res://assets/characters/hero/hero_back.png")
const TEX_SIDE := preload("res://assets/characters/hero/hero_side.png")

var facing := Vector2.DOWN
var anim_t := 0.0

@onready var body: Sprite3D = $Body

func _ready() -> void:
	add_to_group("player")
	_apply_facing()

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cam := get_viewport().get_camera_3d()
	var forward := -cam.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := right * input_dir.x + forward * (-input_dir.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# 限制在村庄圆盘内
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > WALK_RADIUS:
		flat = flat.normalized() * WALK_RADIUS
		global_position.x = flat.x
		global_position.z = flat.y

	# 朝向（屏幕空间）
	if input_dir.x > 0.1:
		facing = Vector2.RIGHT
	elif input_dir.x < -0.1:
		facing = Vector2.LEFT
	elif input_dir.y > 0.1:
		facing = Vector2.DOWN
	elif input_dir.y < -0.1:
		facing = Vector2.UP
	_apply_facing()

	# 行走弹跳
	if dir.length() > 0.1:
		anim_t += delta
		body.position.y = absf(sin(anim_t * 10.0)) * 0.07
	else:
		anim_t = 0.0
		body.position.y = 0.0

func _apply_facing() -> void:
	var flip := false
	var tex: Texture2D
	match facing:
		Vector2.UP:
			tex = TEX_BACK
		Vector2.LEFT:
			tex = TEX_SIDE
		Vector2.RIGHT:
			tex = TEX_SIDE
			flip = true
		_:
			tex = TEX_FRONT
	body.texture = tex
	body.flip_h = flip
	body.pixel_size = BODY_H / float(tex.get_height())
	# 3D 的 Y 轴向上：正 offset 让贴图底边（脚）落在节点原点
	body.offset = Vector2(0, tex.get_height() * 0.5)