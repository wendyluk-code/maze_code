extends CharacterBody2D
## 等距餐厅主角：屏幕方向直接驱动移动；靠近设施显示交互提示

const SPEED := 230.0
const INTERACT_RANGE := 70.0

const TEX_FRONT := preload("res://assets/characters/hero/hero_front.png")
const TEX_BACK := preload("res://assets/characters/hero/hero_back.png")
const TEX_SIDE := preload("res://assets/characters/hero/hero_side.png")
const BODY_TARGET_H := 68.0

var facing := Vector2.DOWN
var anim_t := 0.0

@onready var label: Label = %HintLabel
@onready var body: Sprite2D = $Body

func _ready() -> void:
	add_to_group("player")
	_apply_facing()

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * SPEED
	if input_dir.x > 0.1:
		facing = Vector2.RIGHT
	elif input_dir.x < -0.1:
		facing = Vector2.LEFT
	elif input_dir.y > 0.1:
		facing = Vector2.DOWN
	elif input_dir.y < -0.1:
		facing = Vector2.UP
	move_and_slide()
	# 深度排序（与等距方块一致：屏幕 y 越大越靠前）
	z_index = int(position.y)
	# 行走弹跳
	if velocity.length() > 1.0:
		anim_t += delta
		body.position.y = -absf(sin(anim_t * 12.0)) * 5.0
	else:
		anim_t = 0.0
		body.position.y = 0.0
	_apply_facing()
	queue_redraw()

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
	var s := BODY_TARGET_H / float(tex.get_height())
	body.scale = Vector2(s, s)
	body.offset = Vector2(0, -tex.get_height() * 0.5)

func _process(_delta: float) -> void:
	_update_hint()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var t := nearest_interactable()
		if t:
			interact(t)

func nearest_interactable() -> Node2D:
	var best: Node2D = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node2D
		if not node:
			continue
		var d := global_position.distance_to(interact_pos(node))
		if d < best_d:
			best_d = d
			best = node
	return best

func interact_pos(node: Node2D) -> Vector2:
	if node.has_method("screen_center"):
		return node.screen_center()
	return node.global_position

func interact(target: Node2D) -> void:
	print("[interact] ", target.name)
	if label:
		label.text = "与「%s」交互（开发中）" % target.name

func _update_hint() -> void:
	if not label:
		return
	var best := nearest_interactable()
	label.text = "【E】与「%s」交互" % best.name if best else ""

func _draw() -> void:
	draw_ellipse(Vector2(0, 4), 14.0, 7.0, Color(0, 0, 0, 0.2), true)