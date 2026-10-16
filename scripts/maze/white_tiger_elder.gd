extends Node2D
## 老者专属生命周期：聚焦 → 逐句对白 → 确认 → 回复/奖励 → 恢复。
const Config := preload("res://data/maze/elder_firewood.gd")
const WorldPrompt := preload("res://scripts/ui/components/world_interaction_prompt.gd")
const DialogScene := preload("res://scenes/ui/dialog_box.tscn")
const BackpackReward := preload("res://scripts/ui/components/backpack_reward.gd")
const IngredientReward := preload("res://scripts/ui/components/elder_ingredient_reward.gd")
const Confirmation := preload("res://scripts/ui/components/destination_confirmation.gd")
const Portrait := preload("res://assets/characters/white_tiger_elder/elder_portrait.png")
const HeroPortrait := preload("res://assets/characters/player_portrait.png")
const FRAME_DURATIONS := [350,250,180,250,220,250,250,250]
const POSITION := Config.POSITION
signal closed
var prompt: Control
var sprite: AnimatedSprite2D
var dialog: Control
var choice: Control
var backpack_reward: Control
var ingredient_reward: Control
var _reward_step := -1
var backpack_arrived := false
var _shield: Control
var phase := "idle"
var _armed := false
var _generation := 0
var _tween: Tween
var _camera: Camera2D
var _camera_before := Vector2.ZERO
var _camera_zoom_before := Vector2.ONE
var _camera_process_before := true
var _player: Node2D
var _locked_before := false
var _physics_before := true
var _focus_before: Control
var _host: Node

func _ready() -> void:
	_host = get_parent()
	position = POSITION
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("sit")
	frames.set_animation_loop("sit", true)
	frames.set_animation_speed("sit", 1.0)
	for i in 8:
		frames.add_frame("sit", load("res://assets/characters/white_tiger_elder/elder_sitting_%02d.png" % i), FRAME_DURATIONS[i] / 1000.0)
	sprite = AnimatedSprite2D.new()
	sprite.name = "SittingAnimation"
	sprite.sprite_frames = frames
	sprite.position = Vector2(10, -40)
	sprite.scale = Vector2.ONE * 0.18
	add_child(sprite)
	sprite.play("sit")
	prompt = WorldPrompt.new()
	add_child(prompt)
	prompt.configure("与白虎爷爷交谈", global_position + Vector2(0, -65))
	prompt.activated.connect(interact)

func attach_ui(root: Control) -> void:
	prompt.reparent(root, false)
	_shield = Control.new()
	root.add_child(_shield)
	_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_shield.hide()
	dialog = DialogScene.instantiate()
	_shield.add_child(dialog)
	dialog.hide()
	# 只接管这个实例的输入，公共对白框仍负责头像、打字与逐句显示。
	dialog.set_process_input(false)
	dialog.set_process_unhandled_input(false)
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.finished.connect(_dialog_finished)
	choice = Confirmation.new()
	_shield.add_child(choice)
	choice.set_process_input(false)
	choice.set_process_unhandled_input(false)
	choice.confirmed.connect(_confirm)
	choice.cancelled.connect(close_dialog)
	backpack_reward = BackpackReward.new()
	_shield.add_child(backpack_reward)
	backpack_reward.collected.connect(_backpack_collected)
	ingredient_reward = IngredientReward.new()
	_shield.add_child(ingredient_reward)
	ingredient_reward.set_process_input(false)
	ingredient_reward.set_process_unhandled_input(false)
	ingredient_reward.closed.connect(_ingredient_collected)

func _maze() -> Node:
	return _host

func _available() -> bool:
	var maze := _maze()
	return is_instance_valid(maze.player) and maze._entry_ready and not maze._busy \
		and not maze.player.input_locked and not maze.confirmation.visible and not maze.map_ui.expanded \
		and maze.player.position.distance_to(position) <= Config.INTERACT_RADIUS \
		and maze.Roads.is_walkable(maze.player.position)

func set_near(_near: bool) -> void:
	prompt.visible = phase == "idle" and _available()

func interact() -> void:
	if phase != "idle" or not _available(): return
	_generation += 1
	phase = "focus"
	_armed = not Input.is_action_pressed("interact")
	_player = _maze().player
	_camera = _maze().camera
	_locked_before = _player.input_locked
	_physics_before = _player.is_physics_processing()
	_camera_before = _camera.global_position
	_camera_zoom_before = _camera.zoom
	_camera_process_before = _camera.is_processing()
	_focus_before = get_viewport().gui_get_focus_owner()
	_player.input_locked = true
	_player.set_physics_process(false)
	_camera.set_process(false)
	prompt.hide()
	_shield.show()
	_maze().toast_label.dismiss()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target: Vector2 = _camera._clamp_position(global_position)
	_tween.tween_property(_camera, "global_position", target, 0.45)
	_tween.tween_callback(_begin_dialog.bind(_generation))

func _begin_dialog(generation: int) -> void:
	if generation != _generation or phase != "focus": return
	_tween = null
	var state := SaveManager.elder_firewood_state()
	if not state.valid:
		phase = "farewell"
		dialog.start("白虎爷爷", ["记录异常，暂时不能接取或交付，请检查存档。"], Portrait)
	elif state.status == "inactive":
		phase = "intro"
		dialog.start("白虎爷爷", Config.INTRO, Portrait)
	elif state.status == "active":
		phase = "delivery_intro"
		dialog.start("白虎爷爷", ["木材收集好了吗？"], Portrait)
	else:
		phase = "farewell"
		dialog.start("白虎爷爷", ["加油啊，年轻人。"], Portrait)

func _dialog_finished() -> void:
	if phase in ["intro", "delivery_intro"]:
		var accepting := phase == "intro"
		phase = "accept_choice" if accepting else "delivery_choice"
		choice.open_confirmation("是否帮助白虎爷爷收集12个木材？" if accepting else "是否交付12个木材？", "好的" if accepting else "交付", "暂时不了" if accepting else "稍后再来")
	elif phase == "reward":
		_next_reward_step()
	elif phase in ["reply", "farewell"]:
		close_dialog()

func _confirm() -> void:
	if phase not in ["accept_choice", "delivery_choice"]: return
	var accepting := phase == "accept_choice"
	var result := SaveManager.accept_elder_firewood(_player.position) if accepting else SaveManager.deliver_elder_firewood(_player.position)
	if not result.success:
		choice.question.text = "木材不足，需要12个木材。" if result.reason == "insufficient_wood" else "保存失败或记录异常，未改变任务和物品，请重试。"
		return
	choice.hide()
	get_viewport().gui_release_focus()
	if accepting:
		close_dialog()
	else:
		_reward_step = -1
		_next_reward_step()

func _next_reward_step() -> void:
	dialog.hide_box()
	ingredient_reward.hide()
	_reward_step += 1
	if _reward_step >= Config.REWARD_STEPS.size():
		_show_backpack_reward()
		return
	var step: Dictionary = Config.REWARD_STEPS[_reward_step]
	if step.get("food_reward", false):
		phase = "ingredient_reward"
		ingredient_reward.present()
		_armed = not Input.is_action_pressed("interact")
	else:
		phase = "reward"
		dialog.start(step.speaker, step.lines, HeroPortrait if step.speaker == "主角" else Portrait)

func _input(event: InputEvent) -> void:
	if phase == "idle": return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.is_action_released("interact"): _armed = true
		if not event.pressed or event.echo: return
		if phase == "ingredient_reward":
			if (event.keycode == KEY_E and _armed) or event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				if event.keycode == KEY_E: _armed = false
				ingredient_reward.close_modal()
			elif event.keycode == KEY_TAB:
				ingredient_reward._confirm_button.grab_focus()
			return
		if phase == "backpack_reward":
			if event.keycode == KEY_E and _armed:
				_armed = false
				phase = "backpack_collect"
				backpack_reward.collect_into(_maze().backpack_entry)
			return
		if phase == "backpack_collect": return
		if event.keycode == KEY_ESCAPE:
			close_dialog()
		elif event.keycode == KEY_E:
			if _armed:
				_armed = false
				_advance()
		elif event.keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT] and choice.visible:
			if choice.cancel_button.has_focus(): choice.confirm_button.grab_focus()
			else: choice.cancel_button.grab_focus()
		elif event.keycode in [KEY_ENTER, KEY_SPACE]:
			if choice.visible and choice.cancel_button.has_focus(): close_dialog()
			else: _advance()
	elif event is InputEventMouseButton:
		if phase == "ingredient_reward": return # 原生收下按钮接收鼠标，公共蒙层拦截空白。
		if phase in ["backpack_reward", "backpack_collect"]:
			get_viewport().set_input_as_handled()
			return
		if choice.visible: return # 当前确认框的原生按钮接收，蒙层吸收其余点击。
		get_viewport().set_input_as_handled()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _advance()

func _advance() -> void:
	if phase in ["accept_choice", "delivery_choice"]: _confirm()
	elif dialog.visible: dialog._advance()

func _show_backpack_reward() -> void:
	dialog.hide_box()
	phase = "backpack_reward"
	backpack_reward.show()
	_armed = not Input.is_action_pressed("interact")

func _ingredient_collected() -> void:
	if phase == "ingredient_reward":
		get_viewport().gui_release_focus()
		_next_reward_step()

func _backpack_collected() -> void:
	if phase == "backpack_collect":
		backpack_arrived = true
		close_dialog()

func close_dialog() -> void:
	if phase == "reward":
		_next_reward_step()
		return
	if phase in ["idle", "restoring", "ingredient_reward", "backpack_reward"]: return
	_generation += 1
	if _tween != null: _tween.kill()
	dialog.hide_box()
	choice.hide()
	backpack_reward.hide()
	ingredient_reward.hide()
	phase = "restoring"
	get_viewport().gui_release_focus()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "global_position", _camera_before, 0.45)
	_tween.tween_callback(_finish_restore.bind(_generation))

func _finish_restore(generation: int) -> void:
	if generation != _generation: return
	_tween = null
	_restore()
	phase = "idle"
	_shield.hide()
	_maze()._interact_armed = not Input.is_action_pressed("interact")
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree(): _focus_before.grab_focus()
	closed.emit()

func _restore() -> void:
	if is_instance_valid(_camera):
		_camera.global_position = _camera_before
		_camera.zoom = _camera_zoom_before
		_camera.set_process(_camera_process_before)
	if is_instance_valid(_player):
		_player.input_locked = _locked_before
		_player.set_physics_process(_physics_before)
	if is_instance_valid(_host):
		_host._interact_armed = not Input.is_action_pressed("interact")

func _exit_tree() -> void:
	_generation += 1
	if _tween != null: _tween.kill()
	if phase != "idle": _restore()
	if is_instance_valid(_shield): _shield.queue_free()
	if is_instance_valid(prompt): prompt.queue_free()

func is_busy() -> bool:
	return phase != "idle"
