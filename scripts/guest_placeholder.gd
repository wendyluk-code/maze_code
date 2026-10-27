extends Node2D
## 铁山的纯视觉演出。经营、奖励和教程推进均由原有管理器负责。

signal seating_phase_changed(phase: String)

const START_POSITION := Vector2(910, 198)
const SEAT_GROUND_POSITION := Vector2(471, 271)
const SEAT_FOOT_OFFSET := Vector2(0, 20)
const COLLAPSE_SCALE := Vector2(0.351765, 0.351765)
const COLLAPSE_OFFSET := Vector2(-84.599, -157.591)
const FADE_OUT_SECONDS := 0.30
const FADE_IN_SECONDS := 0.35
const SATISFIED_SCALE := 0.228825
# 按头肩宽度对齐原坐姿；每帧脚底与原脚底同高，根节点不移动。
const SATISFIED_ANCHORS := [Vector2(264.4, 672.2), Vector2(253.9, 673.2), Vector2(249.9, 674.2), Vector2(249.9, 674.2)]

var collapse_completed := false
var collapse_started := false
var fade_initial_alpha := 1.0
var fade_started := false
var fade_completed := false
var seating_started := false
var seating_completed := false
var seating_phase := "prone"
var _motion_token := 0
var _motion_tween: Tween = null
var _breath_tween: Tween = null
var _rise_finished := false
var satisfied_started := false
var satisfied_completed := false
var _order_bubble: Node2D

@onready var portrait: AnimatedSprite2D = $Portrait
@onready var ground_shadow: Sprite2D = $GroundShadow

func _exit_tree() -> void:
	_cancel_motion()

func play_collapse() -> void:
	_cancel_motion()
	satisfied_started = false
	satisfied_completed = false
	portrait.flip_h = false
	seating_started = false
	seating_completed = false
	_set_phase("collapse")
	collapse_started = true
	collapse_completed = false
	portrait.scale = COLLAPSE_SCALE
	portrait.position = COLLAPSE_OFFSET
	ground_shadow.position = Vector2(0,15)
	ground_shadow.show()
	portrait.play("collapse")

func settle_prone() -> void:
	_cancel_motion()
	satisfied_started = false
	satisfied_completed = false
	portrait.flip_h = false
	position = START_POSITION
	portrait.scale = COLLAPSE_SCALE
	portrait.position = COLLAPSE_OFFSET
	ground_shadow.position = Vector2(0,15)
	ground_shadow.show()
	portrait.stop()
	portrait.animation = &"collapse"
	portrait.frame = 7
	collapse_started = true
	collapse_completed = true
	seating_started = false
	seating_completed = false
	_set_phase("prone")

func play_seating() -> void:
	# 一次说明结束只会触发一次；重按 E 或长按不叠加协程/Tween。
	if seating_started or seating_completed or not is_inside_tree():
		return
	if not collapse_completed:
		settle_prone()
	_cancel_motion()
	seating_started = true
	seating_completed = false
	_motion_token += 1
	_run_seating(_motion_token)

func on_order_served() -> void:
	if satisfied_started or satisfied_completed or not is_inside_tree():
		return
	# 极快交付可能抢在落座前：取消未完成动作，直接落到合法椅位。
	if not seating_completed:
		settle_seated()
	_cancel_motion()
	satisfied_started = true
	position = _seat_ground_position()
	ground_shadow.hide()
	_run_satisfied(_motion_token)

func _show_satisfied_frame(index: int) -> void:
	portrait.stop()
	portrait.animation = &"satisfied"
	portrait.frame = index
	portrait.flip_h = true
	portrait.scale = Vector2.ONE * SATISFIED_SCALE
	var anchor: Vector2 = SATISFIED_ANCHORS[index]
	anchor.x = 512.0 - anchor.x
	portrait.position = -anchor * SATISFIED_SCALE

func _run_satisfied(token: int) -> void:
	_set_phase("satisfied_start")
	for index in 4:
		_show_satisfied_frame(index)
		if index == 1: _set_phase("satisfied_raise_head")
		if index == 2: _set_phase("satisfied_sit_upright")
		if index < 3 and not await _pause(0.48, token):
			return
	if not _motion_valid(token):
		return
	satisfied_completed = true
	_set_phase("satisfied_smile")
	# 非循环末帧，不启动疲惫呼吸动作。

func settle_satisfied() -> void:
	settle_seated()
	_cancel_motion()
	satisfied_started = true
	satisfied_completed = true
	_show_satisfied_frame(3)
	_set_phase("satisfied_smile")

func _pause(seconds: float, token: int) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while _motion_valid(token) and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	return _motion_valid(token)

func _motion_valid(token: int) -> bool:
	return token == _motion_token and is_inside_tree()

func _seat_ground_position() -> Vector2:
	var root := get_tree().current_scene
	if is_instance_valid(root):
		var anchor := root.get_node_or_null("TieshanSeatAnchor") as Marker2D
		if is_instance_valid(anchor):
			return anchor.global_position + SEAT_FOOT_OFFSET
	return SEAT_GROUND_POSITION

func _set_phase(value: String) -> void:
	seating_phase = value
	_update_order_bubble()
	seating_phase_changed.emit(value)

func _update_order_bubble() -> void:
	if not is_instance_valid(_order_bubble): return
	_order_bubble.visible = seating_phase == "waiting" and SaveManager.has_active_order() and not SaveManager.has_first_order_settlement()
	if _order_bubble.visible:
		var texture := portrait.sprite_frames.get_frame_texture(portrait.animation, portrait.frame)
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		_order_bubble.position = Vector2(0, portrait.position.y + pixels.get_used_rect().position.y * portrait.scale.y - 6.0)

func _process(_delta: float) -> void:
	# 事务成功即撤下提示；读档落座走同一显示入口。
	if is_instance_valid(_order_bubble) and _order_bubble.visible and SaveManager.has_first_order_settlement():
		_order_bubble.hide()

func _on_animation_finished() -> void:
	if portrait.animation == &"collapse":
		collapse_completed = true
		_set_phase("prone")
	elif portrait.animation == &"rise":
		_rise_finished = true

func prepare_fade_in() -> void:
	fade_initial_alpha = 0.0
	fade_started = false
	fade_completed = false
	modulate.a = 0.0

func mark_fade_started() -> void:
	fade_started = true

func mark_fade_completed() -> void:
	modulate.a = 1.0
	fade_completed = true

func _cancel_tweens() -> void:
	_motion_token += 1
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null


## 起身后省略中途行走，淡出换位并在椅边淡入落座。

var gait_frames: Array = []
var gait_scale := 1.0
var gait_frame := 0
var _gait_ready := false
var _gait_wait_offset := Vector2.ZERO
var walk_count := 1

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	add_to_group("guest")
	portrait.animation_finished.connect(_on_animation_finished)
	_load_gait()
	_order_bubble = preload("res://scripts/ui/components/customer_order_bubble.gd").new()
	_order_bubble.name = "OrderBubble"
	add_child(_order_bubble)
	_order_bubble.setup(SaveManager.FIRST_ORDER_ITEM_ID)
	_order_bubble.hide()

func _load_gait() -> void:
	gait_scale = 0.427142857
	gait_frames = [{"rect":[0,0,300,380],"anchor":[129,372]},{"rect":[0,0,300,380],"anchor":[129,372]},{"rect":[300,0,300,380],"anchor":[131,371]},{"rect":[600,0,300,380],"anchor":[145,363]},{"rect":[900,0,300,380],"anchor":[147,352]}]
	walk_count = 1
	var atlas_source: Texture2D = preload("res://assets/characters/tieshan/tieshan_seated_atlas.png")
	var frames := portrait.sprite_frames.duplicate() as SpriteFrames
	for animation in [&"walk", &"pause", &"sit_down", &"sit_wait"]:
		if frames.has_animation(animation):
			frames.remove_animation(animation)
		frames.add_animation(animation)
		frames.set_animation_loop(animation, false)
	for i in range(gait_frames.size()):
		var rect: Array = gait_frames[i].rect
		var texture := AtlasTexture.new()
		texture.atlas = atlas_source
		texture.region = Rect2(rect[0],rect[1],rect[2],rect[3])
		texture.filter_clip = true
		if i == 0:
			frames.add_frame(&"walk",texture)
			frames.add_frame(&"pause",texture)
		else:
			frames.add_frame(&"sit_down",texture)
			if i == gait_frames.size() - 1:
				frames.add_frame(&"sit_wait",texture)
	portrait.sprite_frames = frames
	var satisfied_atlas: Texture2D = load("res://assets/characters/tieshan/tieshan_satisfied_atlas.png")
	if frames.has_animation(&"satisfied"):
		frames.remove_animation(&"satisfied")
	frames.add_animation(&"satisfied")
	frames.set_animation_loop(&"satisfied", false)
	for index in 4:
		var texture := AtlasTexture.new()
		texture.atlas = satisfied_atlas
		texture.region = Rect2(index * 512, 0, 512, 768)
		texture.filter_clip = true
		frames.add_frame(&"satisfied", texture)
	_gait_ready = true

func _frame_anchor(index: int) -> Vector2:
	var v: Array = gait_frames[index].anchor
	return Vector2(float(v[0]), float(v[1]))

func _frame_scale(index: int) -> float:
	# Normalization uses head/shoulder width, never the shorter seated full height.
	return gait_scale * float(gait_frames[index].get("normalization", 1.0))

func _show_gait_frame(index: int) -> void:
	gait_frame = index
	portrait.stop()
	portrait.scale = Vector2.ONE * _frame_scale(index)
	portrait.flip_h = index >= walk_count
	portrait.animation = &"walk" if index < walk_count else &"sit_down"
	portrait.frame = index if index < walk_count else index - walk_count
	var anchor := _frame_anchor(index)
	if portrait.flip_h:
		# 镜像时同步翻转锚点，保持身体与第一张椅子的对齐。
		anchor.x = float(gait_frames[index].rect[2]) - anchor.x
	portrait.position = -anchor * _frame_scale(index)

func _run_seating(token: int) -> void:
	if not _gait_ready:
		push_error("Cannot run seating without coherent gait atlas")
		return
	_set_phase("rising")
	_rise_finished = false
	# 八张起身帧的接地边界均为纹理y=448，现有偏移已将其对齐本节点。
	# 起身只改变姿态，不移动根节点，否则人物与阴影会一起向上漂浮。
	ground_shadow.position = Vector2.ZERO
	portrait.play(&"rise")
	while _motion_valid(token) and not _rise_finished:
		await get_tree().process_frame
	if not _motion_valid(token):
		return
	_motion_tween = null
	_set_phase("fade_out")
	_motion_tween = create_tween().set_parallel(true)
	_motion_tween.tween_property(portrait,"modulate:a",0.0,FADE_OUT_SECONDS)
	_motion_tween.tween_property(ground_shadow,"modulate:a",0.0,FADE_OUT_SECONDS)
	while _motion_valid(token) and _motion_tween.is_running():
		await get_tree().process_frame
	if not _motion_valid(token):
		return
	# 只在完全透明时换位，不再生成或播放任何中途行走。
	_motion_tween = null
	portrait.modulate.a = 0.0
	position = _seat_ground_position()
	ground_shadow.hide()
	_show_gait_frame(walk_count)
	_set_phase("fade_in")
	_motion_tween = create_tween()
	_motion_tween.tween_property(portrait,"modulate:a",1.0,FADE_IN_SECONDS)
	for index in range(walk_count, gait_frames.size()):
		_show_gait_frame(index)
		if not await _pause(0.3 if index != walk_count + 2 else 0.42, token):
			return
		if index == walk_count + 1:
			_set_phase("sitting")
	_motion_tween = null
	portrait.modulate.a = 1.0
	seating_completed = true
	ground_shadow.hide()
	_set_phase("waiting")
	_start_breathing()

func settle_seated() -> void:
	_cancel_motion()
	satisfied_started = false
	satisfied_completed = false
	portrait.show()
	position = _seat_ground_position()
	seating_started = true
	seating_completed = true
	collapse_completed = true
	if _gait_ready:
		_show_gait_frame(gait_frames.size() - 1)
	ground_shadow.hide()
	_set_phase("waiting")
	_start_breathing()

func _start_breathing() -> void:
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_gait_wait_offset = portrait.position
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(portrait, "position:y", _gait_wait_offset.y - 0.5, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(portrait, "position:y", _gait_wait_offset.y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _cancel_motion() -> void:
	_cancel_tweens()
	if is_instance_valid(portrait):
		portrait.modulate.a = 1.0
		portrait.show()
	if is_instance_valid(ground_shadow):
		ground_shadow.modulate.a = 1.0

## 铁山退场时保留当前站位，先整体渐隐再释放占位节点。
func play_exit_fade() -> void:
	if not is_inside_tree():
		return
	_cancel_motion()
	modulate.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	tween.finished.connect(queue_free)
