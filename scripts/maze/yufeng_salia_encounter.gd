extends Node2D
## 御风与萨莉亚路口登场；仅负责本事件生命周期，不接入战斗。
const DialogScene := preload("res://scenes/ui/dialog_box.tscn")
const ShadowTexture := preload("res://assets/characters/tieshan/ground_shadow.png")
const YUFENG_POS := Vector2(340, 694)
const SALIA_POS := Vector2(307, 694)
const TRIGGER_POS := Vector2(392, 694)
# 覆盖路口约19像素的可走半宽，避免沿道路边缘首次经过时漏触发。
const TRIGGER_RADIUS := 28.0
const LINES := [
	{"speaker":"御风", "text":"站住。谁准你靠近的？", "portrait":"yufeng_portrait.png"},
	{"speaker":"你", "text":"我只是从这里经过……", "portrait":"player_portrait.png"},
	{"speaker":"御风", "text":"偏偏在这个时候？你听见了多少？", "portrait":"yufeng_portrait.png"},
	{"speaker":"萨莉亚", "text":"哎呀呀，御风，别这么激动。也许人家真的只是路过呢。", "portrait":"salia_portrait.png"},
	{"speaker":"御风", "text":"是不是路过，我自会判断，接招吧。", "portrait":"yufeng_portrait.png"},
]
signal busy_changed(value: bool)
var phase := "unseen"
var _player: Node2D
var _camera: Camera2D
var _dialog: Control
var _shield: Control
var _generation := 0
var _armed := false
var _tween: Tween
var _locked_before := false
var _physics_before := true
var _yufeng: AnimatedSprite2D
var _salia: AnimatedSprite2D
var _y_shadow: Sprite2D
var _s_shadow: Sprite2D
var _wait_for_exit := false
var _retry_at_msec := 0

func _ready() -> void:
	phase = SaveManager.yufeng_salia_state()

func attach(player: Node2D, camera: Camera2D, root: Control) -> void:
	_player = player
	_camera = camera
	_shield = Control.new()
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.hide()
	root.add_child(_shield)
	_dialog = DialogScene.instantiate()
	_dialog.set_process_input(false)
	_dialog.set_process_unhandled_input(false)
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.finished.connect(_dialog_finished)
	_shield.add_child(_dialog)
	_configure_portrait_frame()
	if phase == "awaiting_battle": _spawn_standing()
	elif phase == "intro_pending": trigger()

func can_trigger() -> bool:
	return phase == "unseen" and not _wait_for_exit and is_instance_valid(_player) and _player.position.distance_to(TRIGGER_POS) <= TRIGGER_RADIUS

func update_proximity() -> void:
	if not is_instance_valid(_player): return
	if _player.position.distance_to(TRIGGER_POS) > TRIGGER_RADIUS:
		_wait_for_exit = false
		return
	# 模态界面关闭后仍在区域内、或首次保存失败后，都能继续检测；取消则须离圈。
	if can_trigger() and Time.get_ticks_msec() >= _retry_at_msec:
		trigger()

func _configure_portrait_frame() -> void:
	# 仅适配本事件，共用对白框和其他角色保持原样。
	var frame: Panel = _dialog.portrait
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_dialog.portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var border := Panel.new()
	border.name = "PortraitBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.draw_center = false
	border.add_theme_stylebox_override("panel", style)
	frame.add_child(border)

func trigger() -> void:
	if phase == "unseen" and not can_trigger(): return
	if phase not in ["unseen", "intro_pending"]: return
	if phase == "unseen":
		var saved := SaveManager.set_yufeng_salia_state("intro_pending")
		if not saved.success:
			phase = "unseen"
			_retry_at_msec = Time.get_ticks_msec() + 1000
			return
	phase = "intro_pending"
	_generation += 1
	_locked_before = _player.input_locked
	_physics_before = _player.is_physics_processing()
	_player.input_locked = true
	_player.set_physics_process(false)
	busy_changed.emit(true)
	_spawn_walking()
	_armed = not Input.is_action_pressed("interact")
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_yufeng, "position", YUFENG_POS, 0.8)
	_tween.tween_property(_salia, "position", SALIA_POS, 0.8)
	_tween.tween_property(_y_shadow, "position", YUFENG_POS + Vector2(0, 1), 0.8)
	_tween.tween_property(_s_shadow, "position", SALIA_POS + Vector2(0, 1), 0.8)
	_tween.tween_property(_yufeng, "modulate:a", 1.0, 0.8)
	_tween.tween_property(_salia, "modulate:a", 1.0, 0.8)
	_tween.tween_property(_y_shadow, "modulate:a", 1.0, 0.8)
	_tween.tween_property(_s_shadow, "modulate:a", 1.0, 0.8)
	var captured := _generation
	await get_tree().create_timer(0.85).timeout
	_begin_dialog(captured)

func _spawn_walking() -> void:
	_clear_chars()
	_yufeng = _make_character("yufeng", Vector2(316,694), 0.0)
	_salia = _make_character("salia", Vector2(283,694), 0.0)
	_yufeng.play("walk")
	_salia.play("walk")

func _spawn_standing() -> void:
	_clear_chars()
	_yufeng = _make_character("yufeng", YUFENG_POS, 1.0)
	_salia = _make_character("salia", SALIA_POS, 1.0)
	_yufeng.play("idle")
	_salia.play("idle")

func _make_character(kind: String, at: Vector2, alpha: float) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = kind.capitalize()
	sprite.position = at
	sprite.centered = false
	sprite.scale = Vector2.ONE / maxf(_camera.zoom.y, 0.01)
	sprite.offset = Vector2(-47.5 if kind == "yufeng" else -70.0, -134.0 if kind == "yufeng" else -163.0)
	sprite.modulate.a = alpha
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ["walk", "idle"]:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		var sequence := [0, 1, 2, 3, 2, 1] if anim == "walk" else [0, 1, 0, 2, 0, 3]
		frames.set_animation_speed(anim, 5.0 if anim == "walk" else 1.6)
		for frame_index in sequence:
			frames.add_frame(anim, load("res://assets/characters/%s/%s_%s_%d.png" % [kind, kind, anim, frame_index]))
	sprite.sprite_frames = frames
	add_child(sprite)
	var shadow := Sprite2D.new()
	shadow.texture = ShadowTexture
	shadow.position = at + Vector2(0, 1)
	shadow.scale = Vector2.ONE * (0.64 * 0.85 / maxf(_camera.zoom.y, 0.01))
	shadow.modulate.a = alpha
	add_child(shadow)
	if kind == "yufeng": _y_shadow = shadow
	else: _s_shadow = shadow
	sprite.z_index = 4 if kind == "yufeng" else 3
	shadow.z_index = 1
	return sprite

func _begin_dialog(generation: int) -> void:
	if generation != _generation or phase != "intro_pending": return
	phase = "dialog"
	_yufeng.play("idle")
	_salia.play("idle")
	_show_line(0)

func _show_line(index: int) -> void:
	if index >= LINES.size(): return
	var row: Dictionary = LINES[index]
	var portrait: Texture2D = _portrait_for(row)
	_dialog.start(row.speaker, [row.text], portrait)
	_dialog.set_meta("yf_line", index)
	_shield.show()

func _portrait_for(row: Dictionary) -> Texture2D:
	var path := "res://assets/characters/%s" % row.portrait if row.portrait == "player_portrait.png" else "res://assets/characters/%s/%s" % ["yufeng" if row.speaker == "御风" else "salia", row.portrait]
	var source := load(path) as Texture2D
	if source == null or row.portrait == "player_portrait.png": return source
	return source

func _dialog_finished() -> void:
	if phase != "dialog": return
	var index := int(_dialog.get_meta("yf_line", 0))
	if index + 1 < LINES.size():
		_show_line(index + 1)
	else:
		phase = "awaiting_battle"
		var result := SaveManager.set_yufeng_salia_state("awaiting_battle")
		if not result.success:
			phase = "unseen"
			_dialog.hide_box()
			_clear_chars()
			_restore()
			return
		_dialog.hide_box()
		_restore()

func _input(event: InputEvent) -> void:
	if phase == "intro_pending" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
		return
	if phase != "dialog": return
	get_viewport().set_input_as_handled()
	if event is InputEventKey:
		if event.is_action_released("interact") or event.keycode in [KEY_SPACE, KEY_ENTER] and not event.pressed: _armed = true
		if not event.pressed or event.echo: return
		if event.keycode == KEY_ESCAPE:
			_cancel()
		elif event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER] and _armed:
			_armed = false
			_dialog._advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dialog._advance()

func _cancel() -> void:
	phase = "unseen"
	_wait_for_exit = true
	_generation += 1
	if _tween != null:
		_tween.kill()
		_tween = null
	SaveManager.set_yufeng_salia_state("unseen")
	_dialog.hide_box()
	_clear_chars()
	_restore()

func _restore() -> void:
	if is_instance_valid(_player):
		_player.input_locked = _locked_before
		_player.set_physics_process(_physics_before)
	if is_instance_valid(_shield): _shield.hide()
	busy_changed.emit(false)

func _clear_chars() -> void:
	for child in get_children():
		if child is AnimatedSprite2D or child is Sprite2D: child.queue_free()
	_yufeng = null
	_salia = null
	_y_shadow = null
	_s_shadow = null

func is_busy() -> bool:
	return phase in ["intro_pending", "dialog"]

func _exit_tree() -> void:
	_generation += 1
	if _tween != null: _tween.kill()
	if is_busy(): _restore()

