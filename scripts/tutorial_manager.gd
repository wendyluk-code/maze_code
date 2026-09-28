extends Node
## 新手教学管理器（Autoload: TutorialManager）
## 步骤表驱动：guide 层负责视觉展示，这里负责顺序推进与完成判定

signal tutorial_started
signal tutorial_finished
signal chapter_1_started
signal chapter_1_finished
signal chapter_1_stage_changed(stage: int, title: String)
signal step_changed(index: int, total: int)

const CHAPTER_1_STAGE_NAMES := {
	1: "苏醒与失忆",
	2: "客人登场",
	3: "前台接单",
	4: "仓库取料",
	5: "料理制作",
	6: "前台交付与结算",
	7: "准备同行",
}

var active := false
var guide = null
var steps: Array = []
var idx := 0
var player = null
var current_stage := 0

## 过场镜头驻留状态：停在前台直到后续对话播完
var _camera_parked := false
var _camera_cutscene_active := false
var _parked_guest: Node2D = null
var _base_zoom := Vector2(0.85, 0.85)
var _base_zoom_captured := false
var _camera_tween: Tween = null
var _guest_fade_tween: Tween = null
var _run_token := 0
var _replay_requested := false
var _player_lock_owned := false
var _player_input_locked_before := false
var _player_physics_before := true
var _chapter_1_run := false
var _order_explanation_pending := false
var _dialog_done_callback: Callable
var _guide_exit_callback: Callable

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

## 启动教程。custom_steps 为空时使用正式的“第一章：醒来与首单教程”。
## 非空 custom_steps 仅作为兼容测试/内部脚本入口，不改变章节完成状态。
func start(custom_steps: Array = []) -> void:
	if custom_steps.is_empty() and not _replay_requested and SaveManager.is_ready_to_depart():
		_cancel_current_run()
		return
	var next_guide = get_tree().get_first_node_in_group("tutorial_guide")
	if active:
		# Autoload 会跨场景保留；旧场景退出后，必须取消旧异步链，
		# 才能让新餐厅场景重新建立一条唯一教程流程。
		if is_instance_valid(guide) and guide == next_guide and is_instance_valid(player):
			return
		_cancel_current_run()
	guide = next_guide
	if not is_instance_valid(guide) or not guide.has_method("setup"):
		push_warning("TutorialManager: 找不到 tutorial_guide 引导层")
		return
	_run_token += 1
	_dialog_done_callback = _on_dialog_done.bind(_run_token)
	guide.dialog_done.connect(_dialog_done_callback)
	# 场景离树立即使等待中的结果流程失效；无需等待下一场景启动教程。
	_guide_exit_callback = _on_guide_tree_exiting.bind(_run_token)
	guide.tree_exiting.connect(_guide_exit_callback, CONNECT_ONE_SHOT)
	if guide.has_method("prepare_for_start"):
		guide.prepare_for_start()
	active = true
	_chapter_1_run = custom_steps.is_empty()
	if _replay_requested:
		SaveManager.begin_replay()
	steps = custom_steps if not custom_steps.is_empty() else chapter_1_lesson()
	idx = 0
	current_stage = 0
	_player_lock_owned = false
	_order_explanation_pending = false
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player and player.has_signal("interacted") and not player.interacted.is_connected(_on_player_interact):
		player.interacted.connect(_on_player_interact)
	tutorial_started.emit()
	if _chapter_1_run:
		chapter_1_started.emit()
		_resume_saved_cooking()
	_run_step(_run_token)

## 领取材料后从真实经营进度恢复，避免退出重进重复制作。
func _resume_saved_cooking() -> void:
	if _replay_requested:
		return
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	sm.recover_interrupted_cooking()
	var stage: String = sm.lifecycle_stage()
	if stage == "not_started":
		return
	var next_stage: int = {"awakened": 2, "guest_arrived": 2, "order_accepted": 4,
		"ingredients_collected": 5, "dish_ready": 6, "order_served": 7}.get(stage, 1)
	for i in steps.size():
		if stage == "guest_arrived" and steps[i].get("type") == "cutscene_guest":
			idx = i + 1
			break
		if int(steps[i].get("stage", 0)) == next_stage and (next_stage != 7 or steps[i].get("wrapup_id", "") == sm.departure_state().step):
			idx = i
			break
	# 正式入口可能仍在 _ready 中，等场景完成入树后恢复客人。
	if stage != "awakened":
		_restore_cooking_guest.call_deferred(_run_token)

func _restore_cooking_guest(token: int) -> void:
	if not _run_is_valid(token):
		return
	# 恢复已登场的客人；不重播镜头或锁定玩家。
	_parked_guest = (load("res://scenes/guest_placeholder.tscn") as PackedScene).instantiate()
	_parked_guest.position = Vector2(910, 198)
	get_tree().current_scene.add_child(_parked_guest)
	_parked_guest.settle_prone()

## 第一章：醒来与首单教程（脚本化演示，后续接真实经营系统）
## 叙事：片头视频（占位）→ 芽芽唤醒失忆的主角 → 饥肠辘辘的客人(？？？)来临 → 芽芽引导做菜
func chapter_1_lesson() -> Array:
	return [
		{
			"stage": 1,
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"……你终于醒了。",
			],
		},
		{
			"stage": 1,
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"你还记得我吗？",
			],
		},
		{
			"stage": 1,
			"type": "dialog", "speaker": "你",
			"portrait": "res://assets/characters/player_portrait.png",
			"lines": [
				"……？",
			],
		},
		{
			"stage": 1,
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"……果然，你又想不起来了。",
			],
		},
		{
			"stage": 1,
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"没关系。我陪着你，总会想起来的。",
			],
		},
		{
			"stage": 2,
			"type": "cutscene_guest",
			# 地图顶边限制镜头上移，向右构图让站立铁山避开顶栏。
			"camera_pos": Vector2(1080, 200),
			"camera_zoom": Vector2(1.6, 1.6),
			"guest_pos": Vector2(910, 198),
			"fade_duration": 0.45,
			"delay": 0.2,
		},
		{
			"stage": 2,
			"type": "dialog", "speaker": "？？？",
			"portrait": "res://assets/characters/tieshan/tieshan_portrait.png",
			"lines": [
				"哪……哪里……有吃的吗？我……快不行了……",
			],
		},
		{
			"stage": 2,
			"type": "dialog", "speaker": "芽芽",
			"portrait": "res://assets/characters/yaya_portrait.png",
			"lines": [
				"先不说了，救人要紧。",
				"你不会连怎么做饭都忘了吧？……没事，跟我来——你以前，也是这么做的。",
			],
		},
		{
			"stage": 3,
			"type": "move_to", "target": "前台", "radius": 120.0,
			"hint": "用 方向键/WASD 走到前台，接下他的订单",
		},
		{
			"stage": 3,
			"type": "interact", "target": "前台",
			"hint": "靠近前台后，按 E 接下订单",
		},
		{
			"stage": 4,
			"type": "move_to", "target": "仓库", "radius": 150.0,
			"hint": "去仓库拿肉和盐",
		},
		{
			"stage": 4,
			"type": "interact", "target": "仓库",
			"hint": "靠近仓库，按 E 领取食材",
			"toast": "获得：岩鬃肉 ×1、岩盐 ×1",
		},
		{
			"stage": 5,
			"type": "move_to", "target": "魔法汤锅", "radius": 140.0,
			"hint": "放上料理台，煮熟它",
		},
		{
			"stage": 5,
			"type": "interact", "target": "魔法汤锅",
			"hint": "靠近料理台，按 E 制作料理",
			"toast": "【盐烤岩鬃肉】做好了！",
		},
		{
			"stage": 6,
			"type": "move_to", "target": "前台", "radius": 120.0,
			"hint": "端过去给他，小心别洒了",
		},
		{
			"stage": 6,
			"type": "interact", "target": "前台",
			"hint": "靠近前台，按 E 交单上菜",
			"toast": "顾客评价将根据料理品质结算",
		},
	] + departure_lesson()

## 阶段7逐句检查点：自报姓名确认后，后续说话人改为铁山。
func departure_lesson() -> Array:
	var rows := [
		["relief", "？？？", "……缓过来了。"],
		["meat", "？？？", "这是岩鬃兽的肉？那东西又硬又腥，你居然能做成这样。"],
		["yaya_past", "芽芽", "他以前做得更好。"],
		["hero_past", "主角", "以前？"],
		["yaya_yes", "芽芽", "……嗯。"],
		["second_serving", "？？？", "还能再来一份吗？"],
		["check_store", "芽芽", "再去仓库看看吧。"],
		["warehouse_move", "move_to", "仓库"],
		["warehouse_inspect", "interact", "仓库"],
		["salt_pool", "？？？", "迷宫浅层，旧盐池附近，我就是从那边回来的。"],
		["map_review", "departure_map", ""],
		["introduction", "？？？", "我叫铁山，是个冒险者。"],
		["offer", "铁山", "你如果要去，我可以带路。"],
		["no", "芽芽", "……不行。"],
		["memory", "芽芽", "你才刚醒，连自己是谁都不记得。"],
		["cooking", "主角", "可我还记得怎么做饭，我想继续做下去。"],
		["ingredients", "主角", "没有食材，就做不了下一顿。"],
		["yaya_join", "芽芽", "……那我也去。"],
		["stay_shallow", "芽芽", "谁都不许往深处走。"],
		["agreement", "铁山", "说定了。拿够食材就回来。"],
		["ready_to_depart", "ready_to_depart", ""],
	]
	var result: Array = []
	for row in rows:
		var step := {"stage": 7, "wrapup_id": row[0]}
		if row[1] in ["move_to", "interact"]:
			step.merge({"type": row[1], "target": row[2], "radius": 95.0,
				"hint": "去仓库查看剩余食物" if row[1] == "move_to" else "靠近仓库，按 E 查看剩余食物"})
		elif row[1] in ["departure_map", "ready_to_depart"]:
			step["type"] = row[1]
		else:
			step.merge({"type": "dialog", "speaker": row[1], "lines": [row[2]]})
			if row[1] in ["？？？", "铁山"]:
				step["portrait"] = "res://assets/characters/tieshan/tieshan_portrait.png"
			elif row[1] == "芽芽":
				step["portrait"] = "res://assets/characters/yaya_portrait.png"
			if row[0] == "relief":
				step["hint"] = "他放下了盘子。"
		result.append(step)
	return result

## 旧调用方兼容别名；默认入口已改为 chapter_1_lesson()。
func restaurant_lesson() -> Array:
	return chapter_1_lesson()

func chapter_1_stage_names() -> Dictionary:
	return CHAPTER_1_STAGE_NAMES.duplicate()

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
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.has_method("hide_tracking"):
		tracker.hide_tracking()

## 准备面板的显式最终确认。教程已在 ready_to_depart 步骤结束，
## 因此这里只提交原子完成事务并发出章节完成信号，不切换场景。
func confirm_chapter_1() -> Dictionary:
	var result: Dictionary = SaveManager.complete_chapter_1()
	if result.success and result.created and not SaveManager._replaying:
		chapter_1_finished.emit()
	return result

func _run_is_valid(token: int) -> bool:
	return active and token == _run_token and is_instance_valid(guide)

func _run_step(token: int) -> void:
	if not _run_is_valid(token):
		return
	if idx >= steps.size():
		_finish()
		return
	var step: Dictionary = steps[idx]
	var st_type := str(step.get("type", ""))
	_set_order_explanation_highlight(bool(step.get("order_explanation", false)))
	var stage := int(step.get("stage", 0))
	if _chapter_1_run and stage > 0 and stage != current_stage:
		current_stage = stage
		chapter_1_stage_changed.emit(stage, str(CHAPTER_1_STAGE_NAMES.get(stage, "")))
	# 过场镜头驻留：一旦进入非对话步骤（该回到主角行动），回收镜头
	if _camera_parked and st_type != "dialog" and st_type != "cutscene_guest":
		await _unpark_camera(token)
		if not _run_is_valid(token):
			return
	step_changed.emit(idx, steps.size())
	guide.setup(step)
	if _chapter_1_run and guide.has_method("set_chapter_stage"):
		guide.set_chapter_stage(current_stage, str(CHAPTER_1_STAGE_NAMES.get(current_stage, "")))
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
		"departure_map":
			_set_player_locked(true)
			_open_departure_map.call_deferred(token)
		"ready_to_depart":
			# 阶段7只建立稳定的 ready_to_depart 准备态；最终完成必须由
			# 准备面板的显式确认触发，避免进入餐厅后自动写入 done。
			_cancel_current_run()
		_:
			pass

func _open_departure_map(token: int) -> void:
	if not _run_is_valid(token):
		return
	var panel := get_tree().get_first_node_in_group("departure_panel")
	if is_instance_valid(panel):
		if not panel.map_closed.is_connected(_on_departure_map_closed):
			panel.map_closed.connect(_on_departure_map_closed)
		panel.open_map()

func _get_camera() -> Camera2D:
	if is_instance_valid(player):
		var c := player.get_node_or_null("../Camera") as Camera2D
		if is_instance_valid(c):
			return c
	return get_viewport().get_camera_2d()

## 过场：放大+推镜到前台 → 铁山占位角色进场（头顶"…"气泡）→ 短暂停留
## 结束后镜头保持驻留（camera_parked），直到后续对话播完才回收
func _play_guest_cutscene(step: Dictionary, token: int) -> void:
	var cam := _get_camera()
	if is_instance_valid(cam):
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
		if not _run_is_valid(token) or not is_instance_valid(cam):
			return
		cam.paused = true
		_camera_parked = true
	if is_instance_valid(guide) and guide.has_method("set_dim"):
		guide.set_dim(0.12)
	var guest_scene := "res://scenes/guest_placeholder.tscn"
	if ResourceLoader.exists(guest_scene):
		_parked_guest = (load(guest_scene) as PackedScene).instantiate()
		var root := get_tree().current_scene
		if root:
			# 根节点保持地面锚点；站立、跪倒、趴下共用同一位置。
			_parked_guest.position = step.get("guest_pos", Vector2(1000, 300))
			if _parked_guest.has_method("prepare_fade_in"):
				_parked_guest.prepare_fade_in()
			else:
				_parked_guest.modulate.a = 0.0
			root.add_child(_parked_guest)
			if _parked_guest.has_method("mark_fade_started"):
				_parked_guest.mark_fade_started()
			var fade_duration := float(step.get("fade_duration", 0.45))
			_guest_fade_tween = create_tween()
			_guest_fade_tween.tween_property(_parked_guest, "modulate:a", 1.0, fade_duration)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			while _run_is_valid(token) and is_instance_valid(_parked_guest) \
					and _parked_guest.modulate.a < 0.999:
				await get_tree().process_frame
			if not _run_is_valid(token) or not is_instance_valid(_parked_guest):
				return
			_guest_fade_tween = null
			if _parked_guest.has_method("mark_fade_completed"):
				_parked_guest.mark_fade_completed()
			else:
				_parked_guest.modulate.a = 1.0
			_parked_guest.play_collapse()
			# 帧动画随客人节点销毁；跳过/退出使 token 失效，不遗留异步回调。
			while _run_is_valid(token) and is_instance_valid(_parked_guest) \
					and not _parked_guest.collapse_completed:
				await get_tree().process_frame
			if not _run_is_valid(token) or not is_instance_valid(_parked_guest):
				return
	if is_instance_valid(guide) and guide.has_method("set_dim"):
		guide.set_dim(0.5)
	# 淡入完成后才允许短暂停留并进入“？？？”对白；角色与镜头继续驻留。
	await get_tree().create_timer(float(step.get("delay", 0.2))).timeout

## 过场结束：镜头回到主角、恢复原倍率；铁山角色继续留在前台（教程结束时统一回收）
func _unpark_camera(token: int) -> void:
	if not _camera_parked and not _camera_cutscene_active:
		return
	var cam := _get_camera()
	if is_instance_valid(cam):
		_kill_camera_tween()
		_camera_tween = create_tween()
		_camera_tween.set_parallel(true)
		if is_instance_valid(player):
			_camera_tween.tween_property(cam, "global_position", player.global_position, 0.8)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_camera_tween.tween_property(cam, "zoom", _base_zoom, 0.8)
		await _camera_tween.finished
		_camera_tween = null
		if not _run_is_valid(token) or not is_instance_valid(cam):
			return
		cam.paused = false
	_camera_parked = false
	_camera_cutscene_active = false

func _complete_step(token: int) -> void:
	if not _run_is_valid(token):
		return
	if _chapter_1_run and idx < steps.size():
		var checkpoint := ""
		if steps[idx].get("type") == "cutscene_guest":
			checkpoint = "guest_arrived"
		elif int(steps[idx].get("stage", 0)) == 1 and idx + 1 < steps.size() and int(steps[idx + 1].get("stage", 0)) == 2:
			checkpoint = "awakened"
		if not checkpoint.is_empty() and not SaveManager.record_intro(checkpoint):
			guide.show_toast("开场进度未保存，请重试。")
			if checkpoint == "guest_arrived":
				_cleanup_cutscene(true)
			_run_step(token)
			return
	if _chapter_1_run and idx < steps.size() and steps[idx].has("wrapup_id"):
		var result := SaveManager.advance_departure(str(steps[idx].wrapup_id))
		if not result.success:
			guide.show_toast("准备进度未保存，请重试。")
			_run_step(token)
			return
	idx += 1
	_run_step(token)

func _cancel_current_run() -> void:
	if not active:
		return
	active = false
	_run_token += 1
	_order_explanation_pending = false
	_set_order_explanation_highlight(false)
	SaveManager.recover_interrupted_cooking()
	_close_departure_modals()
	_set_player_locked(false)
	_cleanup_cutscene(true)
	if is_instance_valid(guide) and guide.dialog_done.is_connected(_dialog_done_callback):
		guide.dialog_done.disconnect(_dialog_done_callback)
	if is_instance_valid(guide) and guide.tree_exiting.is_connected(_guide_exit_callback):
		guide.tree_exiting.disconnect(_guide_exit_callback)
	if is_instance_valid(guide) and guide.has_method("finish_all"):
		guide.finish_all()
	guide = null
	player = null
	steps = []
	idx = 0
	current_stage = 0
	_chapter_1_run = false
	var was_replaying: bool = SaveManager._replaying
	SaveManager.end_replay()
	if was_replaying:
		var tracker := get_tree().get_first_node_in_group("order_tracking")
		if is_instance_valid(tracker) and tracker.has_method("refresh_saved_state"):
			tracker.refresh_saved_state()

func _on_guide_tree_exiting(token: int) -> void:
	if active and token == _run_token:
		_cancel_current_run()

func _on_dialog_done(token: int) -> void:
	if not _run_is_valid(token) or idx < 0 or idx >= steps.size() or steps[idx].get("type", "") != "dialog":
		return
	if bool(steps[idx].get("order_explanation", false)):
		if not _order_explanation_pending:
			return
		_order_explanation_pending = false
		_set_order_explanation_highlight(false)
		_set_player_locked(false)
		_complete_step(_run_token)
		return
	_set_player_locked(false)
	_complete_step(_run_token)

func _set_order_explanation_highlight(enabled: bool) -> void:
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.has_method("set_explanation_highlight"):
		tracker.set_explanation_highlight(enabled)

func _on_player_interact(node: Node2D) -> void:
	if not active or not is_instance_valid(guide) or idx < 0 or idx >= steps.size():
		return
	var step: Dictionary = steps[idx]
	if step.get("type", "") != "interact":
		return
	var target := resolve_target(step.get("target"))
	if target == null or node != target:
		return
	# 交互信号通常只由 Player 在范围内发出；这里再做一次同一选择器校验，
	# 防止测试/其他调用方直接投递错误目标或超距目标时改变教程和订单状态。
	if is_instance_valid(player) and player.has_method("nearest_interactable"):
		if player.nearest_interactable() != node:
			return
	var is_first_order_step := _chapter_1_run \
			and int(step.get("stage", 0)) == 3 \
			and str(step.get("target", "")) == "前台"
	if is_first_order_step:
		var sm := get_node_or_null("/root/SaveManager")
		if sm == null or not sm.has_method("accept_first_order"):
			return
		var result: Dictionary = sm.accept_first_order()
		if not bool(result.get("success", false)):
			return
		var tracker := get_tree().get_first_node_in_group("order_tracking")
		if is_instance_valid(tracker) and tracker.has_method("show_order_receipt"):
			tracker.show_order_receipt(result.get("order", {}))
		if bool(result.get("created", false)):
			# 仅替换本轮已成功的接单步骤，后续编号和存档恢复入口保持不变。
			# 已接单重进按真实订单恢复到阶段4，不重播这段瞬时说明。
			steps[idx] = {
				"stage": 3, "type": "dialog", "order_explanation": true,
				"speaker": "芽芽", "portrait": "res://assets/characters/yaya_portrait.png",
				"lines": ["订单制作会分成【领取食材】和【制作料理】两部分，先去仓库领取食材吧。"],
			}
			_order_explanation_pending = true
			_run_step(_run_token)
			return
		_complete_step(_run_token)
		return
	if _chapter_1_run and step.get("wrapup_id", "") == "warehouse_inspect":
		var modal := get_tree().get_first_node_in_group("warehouse_modal")
		if not is_instance_valid(modal) or modal._open or not SaveManager.can_start_departure():
			return
		if not modal.inspected.is_connected(_on_empty_warehouse_inspected):
			modal.inspected.connect(_on_empty_warehouse_inspected)
		_set_player_locked(true)
		modal.open_empty_stock()
		return
	var is_warehouse_step := _chapter_1_run \
			and int(step.get("stage", 0)) == 4 \
			and str(step.get("target", "")) == "仓库"
	if is_warehouse_step:
		var warehouse_modal := get_tree().current_scene.get_node_or_null("UIOverlay/WarehouseModal")
		if not is_instance_valid(warehouse_modal) or not warehouse_modal.has_method("open_for_order"):
			return
		if warehouse_modal.get("_open"):
			return
		if not warehouse_modal.is_connected("claimed", _on_warehouse_claimed):
			warehouse_modal.connect("claimed", _on_warehouse_claimed)
		if not warehouse_modal.is_connected("cancelled", _on_warehouse_cancelled):
			warehouse_modal.connect("cancelled", _on_warehouse_cancelled)
		_set_player_locked(true)
		warehouse_modal.open_for_order()
		return
	if _chapter_1_run and int(step.get("stage", 0)) == 5 and str(step.get("target", "")) == "魔法汤锅":
		var modal := get_tree().get_first_node_in_group("cooking_modal")
		if not is_instance_valid(modal) or modal.get("_open"):
			return
		if not modal.cooking_finished.is_connected(_on_cooking_finished):
			modal.cooking_finished.connect(_on_cooking_finished)
		if not modal.cancelled.is_connected(_on_cooking_cancelled):
			modal.cancelled.connect(_on_cooking_cancelled)
		_set_player_locked(true)
		modal.open_for_order(SaveManager.FIRST_ORDER_ITEM_ID)
		return
	if _chapter_1_run and int(step.get("stage", 0)) == 6 and str(step.get("target", "")) == "前台":
		if not is_instance_valid(player) or player.interaction_distance_to(target) > 120.0:
			return
		var sm := get_node_or_null("/root/SaveManager")
		if sm == null:
			return
		var result: Dictionary = sm.deliver_first_order()
		if not bool(result.get("success", false)):
			var messages := {
				"no_canonical_order": "请先到前台接下首单。",
				"not_ready_to_deliver": "请先领取食材并完成料理。",
				"missing_dish": "缺少盐烤岩鬃肉，暂时无法交单。",
				"already_completed": "首单已完成，声望已经结算。",
				"save_failed": "保存失败，本次未交单，请重试。",
			}
			guide.show_toast(str(messages.get(result.get("reason", ""), "暂时无法交单。")))
			return
		var tracker := get_tree().get_first_node_in_group("order_tracking")
		if is_instance_valid(tracker):
			tracker.refresh_saved_state()
		guide.show_toast(_quality_feedback(int(result.get("quality", 1)), int(result.get("reputation_awarded", 10))))
		_complete_step(_run_token)
		return
	var toast := str(step.get("toast", ""))
	if not toast.is_empty():
		guide.show_toast(toast)
	_complete_step(_run_token)

func _on_empty_warehouse_inspected() -> void:
	if not active or idx >= steps.size() or steps[idx].get("wrapup_id", "") != "warehouse_inspect":
		return
	_set_player_locked(false)
	_complete_step(_run_token)

func _on_departure_map_closed() -> void:
	if not active or idx >= steps.size() or steps[idx].get("type", "") != "departure_map":
		return
	_set_player_locked(false)
	_complete_step(_run_token)

func _on_warehouse_claimed(result: Dictionary) -> void:
	if not active or idx < 0 or idx >= steps.size():
		return
	var step: Dictionary = steps[idx]
	if step.get("type", "") != "interact" or int(step.get("stage", 0)) != 4:
		return
	if not bool(result.get("success", false)):
		return
	_set_player_locked(false)
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.has_method("refresh_saved_state"):
		tracker.refresh_saved_state()
	if is_instance_valid(guide):
		guide.show_toast(str(step.get("toast", "")))
	_complete_step(_run_token)

func _on_warehouse_cancelled() -> void:
	if active:
		_set_player_locked(false)

func _on_cooking_finished(result: Dictionary) -> void:
	if not active or idx < 0 or idx >= steps.size():
		return
	var token := _run_token
	var step: Dictionary = steps[idx]
	if step.get("type", "") != "interact" or int(step.get("stage", 0)) != 5:
		return
	if not bool(result.get("success", false)):
		return
	# 结果短暂留在弹窗中，随后关闭并恢复教程输入，避免遮罩下推进到移动步骤。
	await get_tree().create_timer(1.0).timeout
	if not active or token != _run_token or idx < 0 or idx >= steps.size():
		return
	if steps[idx].get("type", "") != "interact" or int(steps[idx].get("stage", 0)) != 5:
		return
	var modal := get_tree().get_first_node_in_group("cooking_modal")
	if not is_instance_valid(modal) or not modal.get("_open"):
		return
	modal.close_modal()
	_set_player_locked(false)
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker) and tracker.has_method("refresh_saved_state"):
		tracker.refresh_saved_state()
	if is_instance_valid(guide):
		guide.show_toast("【盐烤岩鬃肉】完成：%d 星" % int(result.get("quality", 1)))
	_complete_step(_run_token)

func _on_cooking_cancelled() -> void:
	if active:
		_set_player_locked(false)

func _quality_feedback(quality: int, reward: int) -> String:
	match quality:
		3:
			return "顾客惊叹不已！完美料理！ 餐厅声望 +%d" % reward
		2:
			return "顾客吃得很满足！美味料理！ 餐厅声望 +%d" % reward
		_:
			return "顾客吃得很满足。普通料理。 餐厅声望 +%d" % reward

func _process(_delta: float) -> void:
	if not active or not is_instance_valid(player) or idx < 0 or idx >= steps.size():
		return
	var step: Dictionary = steps[idx]
	if step.get("type", "") != "move_to":
		return
	var target := resolve_target(step.get("target"))
	if target == null:
		return
	if player.interaction_distance_to(target) <= float(step.get("radius", 120.0)):
		_complete_step(_run_token)

func _set_player_locked(locked: bool) -> void:
	if not is_instance_valid(player):
		_player_lock_owned = false
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

func _kill_guest_fade_tween() -> void:
	if _guest_fade_tween != null and _guest_fade_tween.is_valid():
		_guest_fade_tween.kill()
	_guest_fade_tween = null

func _finish(remove_guest := false, finalize_chapter := false) -> void:
	if not active:
		return
	var completed := false
	var was_replaying := SaveManager._replaying
	if finalize_chapter and _chapter_1_run:
		var result: Dictionary = SaveManager.complete_chapter_1()
		if not result.success:
			# 保存失败时保留当前流程与 ready_to_depart 检查点，允许玩家重试；
			# 重复触发不会额外写盘或奖励。
			if is_instance_valid(guide):
				guide.show_toast("第一章完成状态未保存，请重试。")
			return
		completed = result.created or result.reason == "already_done"
	_cancel_current_run()
	tutorial_finished.emit()
	if completed and not was_replaying:
		chapter_1_finished.emit()

## 仅回收本票据新增模态状态；先恢复模态快照，再释放教程拥有的玩家锁。
func _close_departure_modals() -> void:
	var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
	if is_instance_valid(warehouse) and warehouse._open:
		warehouse.close_modal()
	var panel := get_tree().get_first_node_in_group("departure_panel")
	if is_instance_valid(panel) and panel._open:
		panel.close_map()
	var cooking := get_tree().get_first_node_in_group("cooking_modal")
	if is_instance_valid(cooking) and cooking.get("_open"):
		cooking.close_modal()

## 无论正常结束还是跳过：解除镜头驻留；跳过时同时移除未完成的占位演出
func _cleanup_cutscene(remove_guest := false) -> void:
	_kill_camera_tween()
	_kill_guest_fade_tween()
	var cam := _get_camera()
	if is_instance_valid(cam):
		cam.paused = false
		if _base_zoom_captured:
			cam.zoom = _base_zoom
		if is_instance_valid(player) and (_camera_cutscene_active or _camera_parked):
			cam.global_position = player.global_position
	_camera_parked = false
	_camera_cutscene_active = false
	_base_zoom_captured = false
	if is_instance_valid(_parked_guest):
		_parked_guest.queue_free()
	_parked_guest = null
