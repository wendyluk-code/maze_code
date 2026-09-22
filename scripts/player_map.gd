extends CharacterBody2D
## 手绘地图餐厅主角：屏幕方向移动 + 朝向切图 + 靠近交互点提示

signal interacted(target: Node2D)

const SPEED := 260.0
const INTERACT_RANGE := 95.0
const BODY_VIS_H := 130.0
const SPAWN_INIT_PENDING := 0
const SPAWN_INIT_READY := 1
const SPAWN_INIT_FAILED := 2
const SPAWN_INIT_MAX_ATTEMPTS := 2

const TEX_FRONT := preload("res://assets/characters/hero/hero_front.png")
const TEX_BACK := preload("res://assets/characters/hero/hero_back.png")
const TEX_SIDE := preload("res://assets/characters/hero/hero_side.png")

var facing := Vector2.DOWN
var anim_t := 0.0

@onready var label: Label = %HintLabel
@onready var body: Sprite2D = $Body
@onready var collision: CollisionShape2D = $Collision

var walk_zone: Node = null
var last_valid := Vector2.ZERO
var spawn_ready := false
var spawn_init_state := SPAWN_INIT_PENDING
var spawn_init_attempts := 0
var spawn_resolved_in_ready := false
var _ready_in_progress := false
## 教程/剧情锁定时禁止移动与交互
var input_locked := false

func _ready() -> void:
	add_to_group("player")
	# TutorialGuide 打开首句对白时会禁用玩家物理帧；出生定位必须在这里完成，
	# 不能等待首个物理帧，否则开场画面会渲染场景中的占位位置。
	_ready_in_progress = true
	_try_resolve_spawn()
	_ready_in_progress = false
	last_valid = global_position
	_apply_facing()
	# 若以后调整场景树就绪顺序，最多延迟重试一次；明确失败后不逐帧重建。
	if spawn_init_state == SPAWN_INIT_PENDING:
		call_deferred("_try_resolve_spawn")

func _physics_process(delta: float) -> void:
	if spawn_init_state == SPAWN_INIT_PENDING:
		_try_resolve_spawn()

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_dir * SPEED
	move_and_slide()

	if walk_zone and walk_zone.polygons.size() > 0:
		if is_walkable_footprint(global_position):
			last_valid = global_position
		else:
			var ok_x: bool = is_walkable_footprint(Vector2(global_position.x, last_valid.y))
			var ok_y: bool = is_walkable_footprint(Vector2(last_valid.x, global_position.y))
			if ok_x:
				position = Vector2(global_position.x, last_valid.y)
				last_valid = position
			elif ok_y:
				position = Vector2(last_valid.x, global_position.y)
				last_valid = position
			else:
				position = last_valid

	if input_dir.x > 0.1:
		facing = Vector2.RIGHT
	elif input_dir.x < -0.1:
		facing = Vector2.LEFT
	elif input_dir.y > 0.1:
		facing = Vector2.DOWN
	elif input_dir.y < -0.1:
		facing = Vector2.UP
	_apply_facing()

	if input_dir.length() > 0.1:
		anim_t += delta
		body.position.y = -absf(sin(anim_t * 10.0)) * 5.0
	else:
		anim_t = 0.0
		body.position.y = 0.0

func _try_resolve_spawn() -> bool:
	if spawn_ready:
		spawn_init_state = SPAWN_INIT_READY
		return true
	if spawn_init_state == SPAWN_INIT_FAILED:
		return false
	spawn_init_attempts += 1
	if walk_zone == null:
		walk_zone = get_tree().get_first_node_in_group("walk_zone")
	if not is_instance_valid(walk_zone):
		if spawn_init_attempts >= SPAWN_INIT_MAX_ATTEMPTS:
			spawn_init_state = SPAWN_INIT_FAILED
		return false
	# WalkZone 自己负责一次性构建多边形。玩家不重复调用其私有构建方法；
	# 掩码缺失或无有效多边形时进入终止失败态，避免逐帧重建和刷屏。
	if walk_zone.polygons.is_empty() or not walk_zone.has_method("get_spawn_point"):
		spawn_init_state = SPAWN_INIT_FAILED
		return false
	var sp: Vector2 = walk_zone.get_spawn_point(collision_radius_world())
	if sp == Vector2.ZERO or not is_walkable_footprint(sp):
		spawn_init_state = SPAWN_INIT_FAILED
		return false
	global_position = sp
	last_valid = sp
	spawn_ready = true
	spawn_init_state = SPAWN_INIT_READY
	spawn_resolved_in_ready = _ready_in_progress
	return true

func is_walkable_footprint(point: Vector2) -> bool:
	if not is_instance_valid(walk_zone):
		return true
	if walk_zone.has_method("is_circle_inside"):
		return walk_zone.is_circle_inside(point, collision_radius_world())
	return walk_zone.is_point_inside(point)

func _process(_delta: float) -> void:
	_update_hint()

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event.is_action_pressed("interact"):
		var t := nearest_interactable()
		if t:
			print("[interact] ", display_name_of(t))
			interacted.emit(t)

func nearest_interactable() -> Node2D:
	var best: Node2D = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		var node := n as Node2D
		if not node:
			continue
		var d := interaction_distance_to(node)
		if d <= best_d and (best == null or d < best_d or str(node.get_path()) < str(best.get_path())):
			best_d = d
			best = node
	return best

func interaction_distance_to(target: Node2D) -> float:
	var center := collision.global_position if is_instance_valid(collision) else global_position
	var center_distance := center.distance_to(target.global_position)
	if target.has_method("interaction_distance_from"):
		center_distance = target.interaction_distance_from(center)
	return maxf(0.0, center_distance - collision_radius_world())

func collision_radius_world() -> float:
	if not is_instance_valid(collision) or not collision.shape is CircleShape2D:
		return 0.0
	var circle := collision.shape as CircleShape2D
	var transform := collision.global_transform
	return circle.radius * minf(transform.x.length(), transform.y.length())

func _update_hint() -> void:
	if not label:
		return
	var best := nearest_interactable()
	if best:
		label.text = "【E】与「%s」交互" % display_name_of(best)
	else:
		label.text = ""

func display_name_of(p: Node) -> String:
	if p.has_method(&"get") and "display_name" in p:
		var v = p.get("display_name")
		if v is String and not v.is_empty():
			return v
	return p.name

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
	var s := BODY_VIS_H / float(tex.get_height())
	body.scale = Vector2(s, s)
	body.offset = Vector2(0, -tex.get_height() * 0.5)
