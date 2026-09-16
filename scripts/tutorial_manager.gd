extends Node
## 新手教学管理器（Autoload: TutorialManager）
## 步骤表驱动：guide 层负责视觉展示，这里负责顺序推进与完成判定

signal tutorial_started
signal tutorial_finished
signal step_changed(index: int, total: int)

var active := false
var guide = null
var steps: Array = []
var idx := 0
var player = null

## 过场镜头驻留状态：停在前台直到后续对话播完
var _camera_parked := false
var _camera_cutscene_active := false
var _parked_guest: Node2D = null
var _base_zoom := Vector2(0.85, 0.85)
var _base_zoom_captured := false
var _camera_tween: Tween = null
var _run_token := 0
var _replay_requested := false
var _player_lock_owned := false
var _player_input_locked_before := false
var _player_physics_before := true

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_replay_requested = _has_replay_argument()

func _has_replay_argument() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--replay-tutorial":
			return true
	for arg in OS.get_cmdline_args():
		if arg == "--replay-tutorial":
			return true
	return false

func is_replay_requested() -> bool:
	return _replay_requested

## 启动教程。custom_steps 为空时使用默认的"第一节：餐厅首单教学"
func start(custom_steps: Array = []) -> void:
	if active:
		return
	guide = get_tree().get_first_node_in_group("tutorial_guide")
	if guide == null or not guide.has_method("setup"):
		push_warning("TutorialManager: 找不到 tutorial_guide 引导层")
		return
	if not guide.dialog_done.is_connected(_on_dialog_done):
		guide.dialog_done.connect(_on_dialog_done)
	_run_token += 1
	if guide.has_method("prepare_for_start"):
		guide.prepare_for_start()
	active = true
	steps = custom_steps if not custom_steps.is_empty() else restaurant_lesson()
	idx = 0
	_player_lock_owned = false
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_signal("interacted") and not player.interacted.is_connected(_on_player_interact):
		player.interacted.connect(_on_player_interact)
		tutorial_started.emit()
	_run_step(_run_token)

## 第一节：餐厅首单教学（脚本化演示，后续接真实经营系统）
## 叙事：片头视频（占位）→ 芽芽唤醒失忆的主角 → 饥肠辘辘的客人(？？？)来临 → 芽芽引导做菜
func restaurant_lesson() -> Array:
	return [
		{
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"……你醒了。",
			],
		},
		{
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"你还记得我吗？",
			],
		},
		{
			"type": "dialog", "speaker": "你",
			"portrait": "res://assets/characters/player_portrait.png",
			"lines": [
				"……？",
			],
		},
		{
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"……果然，你还是什么都想不起来。",
			],
		},
		{
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"没关系。我陪着你，总会想起来的。",
			],
		},
		{
			"type": "cutscene_guest",
			"camera_pos": Vector2(1000, 320),
			"camera_zoom": Vector2(1.35, 1.35),
			"guest_pos": Vector2(1000, 300),
			"delay": 0.9,
		},
		{
			"type": "dialog", "speaker": "？？？",
			"lines": [
				"哪……哪里……有吃的吗？我……快不行了……",
			],
		},
		{
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"先不说了，救人要紧。",
				"你不会连怎么做饭都忘了吧？……没事，跟我来——你以前，也是这么做的。",
			],
		},
		{
			"type": "move_to", "target": "前台", "radius": 120.0,
			"hint": "用 方向键/WASD 走到前台，接下他的订单",
		},
		{
			"type": "interact", "target": "前台",
			"hint": "靠近前台后，按 E 接下订单",
			"toast": "已接单：魔物烤肉 ×1",
		},
		{
			"type": "move_to", "target": "仓库", "radius": 150.0,
			"hint": "去仓库拿肉和盐",
		},
		{
			"type": "interact", "target": "仓库",
			"hint": "靠近仓库，按 E 领取食材",
			"toast": "获得：魔物肉 ×1、岩盐 ×1",
		},
		{
			"type": "move_to", "target": "魔法汤锅", "radius": 140.0,
			"hint": "放上料理台，煮熟它",
		},
		{
			"type": "interact", "target": "魔法汤锅",
			"hint": "靠近料理台，按 E 制作料理",
			"toast": "【魔物烤肉】 做好了！",
		},
		{
			"type": "move_to", "target": "前台", "radius": 120.0,
			"hint": "端过去给他，小心别洒了",
		},
		{
			"type": "interact", "target": "前台",
			"hint": "靠近前台，按 E 交单上菜",
			"toast": "顾客吃得很满足！ 餐厅声望 +20",
		},
		{
			"type": "dialog", "speaker": "？？？",
			"lines": [
				"呜……好吃！这味道，跟我年轻时在边境吃到的一模一样！你这店，我天天光顾！",
			],
		},
		{
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"哼……你做得，跟从前一样好。",
			],
		},
		{
			"type": "notify",
			"toast": "迷宫那头有扇门……刚才透出了光。",
			"delay": 1.8,
		},
		{
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"等你准备好了，我们再一起去看看。",
			],
		},
		{"type": "finish"},
	]

## 根据名称/display_name/Node2D 解析目标节点
func resolve_target(target) -> Node2D:
	if target is Node2D:
		return target
	if target is String:
		for n in get_tree().get_nodes_in_group("interactable"):
			var node := n as Node2D
			if node == null:
				continue
			if node.name == target:
				return node
			if node.has_method("get") and node.get("display_name") == target:
				return node
		return get_tree().get_first_node_in_group(target) as Node2D
	return null

func skip_all() -> void:
	_finish(true)

func _run_is_valid(token: int) -> bool:
	return active and token == _run_token

func _run_step(token: int) -> void:
	if not _run_is_valid(token):
		return
	if idx >= steps.size():
		_finish()
		return
	var step: Dictionary = steps[idx]
	var st_type := str(step.get("type", ""))
	# 过场镜头驻留：一旦进入非对话步骤（该回到主角行动），回收镜头
	if _camera_parked and st_type != "dialog" and st_type != "cutscene_guest":
		await _unpark_camera(token)
		if not _run_is_valid(token):
			return
	step_changed.emit(idx, steps.size())
	guide.setup(step)
	match st_type:
		"dialog":
			_set_player_locked(true)
			var act: Texture2D = null
			var p_tex = step.get("portrait")
			if p_tex is String and not (p_tex as String).is_empty():
				act = load(p_tex) as Texture2D
			guide.play_dialog(str(step.get("speaker", "")), step.get("lines", []), act)
		"notify":
			guide.show_toast(str(step.get("toast", "")))
			await get_tree().create_timer(float(step.get("delay", 1.4))).timeout
			if _run_is_valid(token):
				_complete_step(token)
		"cutscene_guest":
			_set_player_locked(true)
			await _play_guest_cutscene(step, token)
			if not _run_is_valid(token):
				return
			_set_player_locked(false)
			_complete_step(token)
		"finish":
			_finish()
		_:
			pass

func _get_camera() -> Camera2D:
	if player:
		var c := player.get_node_or_null("../Camera") as Camera2D
		if c:
			return c
	return get_viewport().get_camera_2d()

## 过场：放大+推镜到前台 → 铁山占位角色进场（头顶"…"气泡）→ 短暂停留
## 结束后镜头保持驻留（camera_parked），直到后续对话播完才回收
func _play_guest_cutscene(step: Dictionary, token: int) -> void:
	var cam := _get_camera()
	if cam:
		_kill_camera_tween()
		cam.paused = true
		_base_zoom = cam.zoom
		_base_zoom_captured = true
		_camera_cutscene_active = true
		_camera_tween = create_tween()
		_camera_tween.set_parallel(true)
		_camera_tween.tween_property(cam, "global_position", step.get("camera_pos", Vector2(1000, 320)), 1.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_camera_tween.tween_property(cam, "zoom", step.get("camera_zoom", Vector2(1.35, 1.35)), 1.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _camera_tween.finished
		_camera_tween = null
		if not _run_is_valid(token):
			return
		cam.paused = true
		_camera_parked = true
	if guide and guide.has_method("set_dim"):
		guide.set_dim(0.12)
	var guest_scene := "res://scenes/guest_placeholder.tscn"
	if ResourceLoader.exists(guest_scene):
		_parked_guest = (load(guest_scene) as PackedScene).instantiate()
		var root := get_tree().current_scene
		if root:
			root.add_child(_parked_guest)
			_parked_guest.position = step.get("guest_pos", Vector2(1000, 300))
	if guide and guide.has_method("set_dim"):
		guide.set_dim(0.5)
	# 短暂展示气泡后进入"？？？"对话；角色与镜头继续驻留
	await get_tree().create_timer(float(step.get("delay", 0.9))).timeout

## 过场结束：镜头回到主角、恢复原倍率；铁山角色继续留在前台（教程结束时统一回收）
func _unpark_camera(token: int) -> void:
	if not _camera_parked and not _camera_cutscene_active:
		return
	var cam := _get_camera()
	if cam:
		_kill_camera_tween()
		_camera_tween = create_tween()
		_camera_tween.set_parallel(true)
		if player:
			_camera_tween.tween_property(cam, "global_position", player.global_position, 0.8)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_camera_tween.tween_property(cam, "zoom", _base_zoom, 0.8)
		await _camera_tween.finished
		_camera_tween = null
		if not _run_is_valid(token):
			return
		cam.paused = false
	_camera_parked = false
	_camera_cutscene_active = false

func _complete_step(token: int) -> void:
	if not _run_is_valid(token):
		return
	idx += 1
	_run_step(token)

func _on_dialog_done() -> void:
	if not active:
		return
	_set_player_locked(false)
	_complete_step(_run_token)

func _on_player_interact(node: Node2D) -> void:
	if not active or idx < 0 or idx >= steps.size():
		return
	var step: Dictionary = steps[idx]
	if step.get("type", "") != "interact":
		return
	var target := resolve_target(step.get("target"))
	if target == null or node != target:
		return
	var toast := str(step.get("toast", ""))
	if not toast.is_empty():
		guide.show_toast(toast)
	_complete_step(_run_token)

func _process(_delta: float) -> void:
	if not active or player == null or idx < 0 or idx >= steps.size():
		return
	var step: Dictionary = steps[idx]
	if step.get("type", "") != "move_to":
		return
	var target := resolve_target(step.get("target"))
	if target == null:
		return
	if player.global_position.distance_to(target.global_position) <= float(step.get("radius", 120.0)):
		_complete_step(_run_token)

func _set_player_locked(locked: bool) -> void:
	if player == null:
		return
	if locked:
		if not _player_lock_owned:
			_player_lock_owned = true
			_player_input_locked_before = bool(player.get("input_locked")) if "input_locked" in player else false
			_player_physics_before = player.is_physics_processing()
		if "input_locked" in player:
			player.input_locked = true
		player.set_physics_process(false)
		return
	if _player_lock_owned:
		if "input_locked" in player:
			player.input_locked = _player_input_locked_before
		player.set_physics_process(_player_physics_before)
		_player_lock_owned = false
	else:
		if "input_locked" in player:
			player.input_locked = false
		player.set_physics_process(true)

func _kill_camera_tween() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null

func _finish(remove_guest := false) -> void:
	if not active:
		return
	active = false
	_run_token += 1
	_set_player_locked(false)
	_cleanup_cutscene(remove_guest)
	if guide and guide.has_method("finish_all"):
		guide.finish_all()
	var sm := get_node_or_null("/root/SaveManager")
	if sm and not sm.is_tutorial_done():
		sm.mark_tutorial_done()
		sm.save()
	tutorial_finished.emit()

## 无论正常结束还是跳过：解除镜头驻留；跳过时同时移除未完成的占位演出
func _cleanup_cutscene(remove_guest := false) -> void:
	_kill_camera_tween()
	var cam := _get_camera()
	if cam:
		cam.paused = false
		if _base_zoom_captured:
			cam.zoom = _base_zoom
		if player and (_camera_cutscene_active or _camera_parked):
			cam.global_position = player.global_position
	_camera_parked = false
	_camera_cutscene_active = false
	_base_zoom_captured = false
	if remove_guest and is_instance_valid(_parked_guest):
		_parked_guest.queue_free()
	_parked_guest = null
