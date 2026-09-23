extends Node
## 隔离进程中的实际入口观察器；按键/鼠标经 Input 投递，完整视频不快进。

var checks: Array = []
var failures := 0
var mode := ""
var sm: Node
var tm: Node
var prologue: Control
var transitions := 0
var restaurant_entries := 0
var black_seen := false
var finished_signals := 0
var max_position := 0.0
var positions: Array = []
var captures: Array = []
var protected_memory := ""
var protected_disk := ""
var replay_clean := true
var watch_replay := false

func _ready() -> void:
	_run.call_deferred()

func _arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""

func _check(ok: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"passed": ok, "label": label, "details": details})
	if not ok:
		failures += 1
		print("PRO_01 FAIL: ", label, " ", details)

func _disk() -> String:
	return FileAccess.get_file_as_string("user://save.json") if FileAccess.file_exists("user://save.json") else "absent"

func _write(value: Dictionary) -> void:
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	sm.load_data()

func _process(_delta: float) -> void:
	if mode == "race" and get_tree().has_group("prologue_transition"):
		# 整个淡入/淡出阶段持续重复输入，覆盖餐厅已入树但黑幕尚未释放的窗口。
		_key(KEY_SPACE)
		_key(KEY_ENTER)
		_key(KEY_ESCAPE)
	if is_instance_valid(prologue) and is_instance_valid(prologue.video):
		max_position = maxf(max_position, prologue.video.stream_position)
	if watch_replay and (JSON.stringify(sm.data).sha256_text() != protected_memory or _disk().sha256_text() != protected_disk):
		replay_clean = false

func _run() -> void:
	var isolation := _arg("--isolation-root=").replace("\\", "/").to_lower()
	var actual := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if OS.get_environment("MAZE_PRO_01_ISOLATED") != "1" or isolation.is_empty() or not actual.begins_with(isolation + "/"):
		push_error("PRO-01 拒绝运行：存档目录未隔离")
		get_tree().quit(2)
		return
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	mode = _arg("--mode=")
	DisplayServer.window_set_title("PRO-01 " + mode)
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/prologue.tscn", "主场景为序章入口")
	if mode == "migration":
		_migrations()
	elif mode == "atomic":
		_atomic()
	else:
		await _entry()
	var report := {"ticket": "PRO-01", "mode": mode, "checks": checks, "failures": failures,
		"user_dir": actual, "renderer": DisplayServer.get_name(), "transitions": transitions,
		"restaurant_entries": restaurant_entries, "finished_signals": finished_signals,
		"max_video_position": max_position, "sample_positions": positions, "captures": captures,
		"data": sm.data, "replay_memory_before": protected_memory, "replay_memory_after": JSON.stringify(sm.data).sha256_text(),
		"replay_disk_before": protected_disk, "replay_disk_after": _disk().sha256_text()}
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PRO_01 ", mode, " checks=", checks.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _migrations() -> void:
	var cases: Array = []
	for stage in ["not_started", "awakened", "guest_arrived"]:
		sm.data = sm._defaults()
		sm.data.chapter_1_intro = stage
		cases.append([stage, sm.data.duplicate(true), stage != "not_started"])
	sm.data = sm._defaults()
	for operation in ["accept_first_order", "claim_first_order_ingredients", "cook_first_order", "deliver_first_order"]:
		_check(sm.call(operation).success, "迁移夹具通过真实事务 " + operation)
		cases.append([operation, sm.data.duplicate(true), true])
	for step in sm.WRAPUP_STEPS.slice(0, -1):
		_check(sm.advance_departure(step).success, "迁移夹具推进 " + step)
	cases.append(["ready_to_depart", sm.data.duplicate(true), true])
	sm.data = sm._defaults()
	sm.data.chapter_1_done = true
	cases.append(["chapter_1_done", sm.data.duplicate(true), true])
	sm.data = sm._defaults()
	sm.data.tutorial_done = true
	cases.append(["legacy_tutorial_only", sm.data.duplicate(true), false])
	for item in cases:
		var legacy: Dictionary = item[1]
		legacy.erase("prologue_done")
		legacy["custom_preserved"] = {"value": 42}
		_write(legacy)
		var disk := JSON.stringify(legacy, "\t")
		_check(sm.is_prologue_done() == item[2], "旧档序章判定 " + item[0])
		var after: Dictionary = sm.data.duplicate(true)
		after.erase("prologue_done")
		# JSON 数字读回为 float；统一经 JSON 解析比较值，避免把 42 与 42.0 当状态变化。
		_check(JSON.parse_string(JSON.stringify(after)) == JSON.parse_string(JSON.stringify(legacy)) and _disk() == disk, "只补序章标记，不改经营/未知字段且读档不落盘 " + item[0], {"before": legacy, "after": after})
		_check(sm.save(), "原子保存迁移 " + item[0])
		sm.load_data()
		_check(sm.is_prologue_done() == item[2], "迁移保存后重进 " + item[0])
	var invalid: Dictionary = sm._defaults()
	invalid.prologue_done = "true"
	_write(invalid)
	_check(not sm.is_prologue_done(), "错误类型不伪造已看")
	invalid.chapter_1_intro = "awakened"
	_write(invalid)
	_check(sm.is_prologue_done(), "错误类型从稳定第一章进度恢复")

func _atomic() -> void:
	sm.data = sm._defaults()
	_check(sm.save(), "保存隔离初始状态")
	var before := _disk()
	var memory: Dictionary = sm.data.duplicate(true)
	var temporary := ProjectSettings.globalize_path("user://save.json.tmp")
	_check(DirAccess.make_dir_absolute(temporary) == OK, "制造临时文件不可写")
	_check(not sm.complete_prologue() and sm.data == memory and _disk() == before, "写盘失败完整回滚正式状态")
	_check(DirAccess.remove_absolute(temporary) == OK, "移除隔离失败夹具")
	_check(sm.complete_prologue() and sm.is_prologue_done(), "原子提交序章完成")
	var completed := _disk()
	_check(sm.complete_prologue() and _disk() == completed, "重复完成幂等")
	_check(not sm.is_chapter_1_done() and not sm.is_tutorial_done() and sm.lifecycle_stage() == "not_started", "序章完成不补发第一章状态")

func _entry() -> void:
	if mode == "old":
		sm.data = sm._defaults()
		_check(sm.accept_first_order().success and sm.claim_first_order_ingredients().success, "旧档夹具通过真实接单取料")
		var old: Dictionary = sm.data.duplicate(true)
		old.erase("prologue_done")
		_write(old)
	protected_memory = JSON.stringify(sm.data).sha256_text()
	protected_disk = _disk().sha256_text()
	watch_replay = mode == "replay"
	if watch_replay:
		_check(sm.is_prologue_preview() and sm._replaying, "实际命令行启用整次进程隔离预览")
	# 观察器在根节点存活，生产场景按正式 current_scene 身份启动。
	get_tree().current_scene = null
	get_tree().scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_node_added)
	prologue = (load("res://scenes/prologue.tscn") as PackedScene).instantiate()
	if mode == "missing":
		prologue.video_path = "res://assets/video/prologue/does_not_exist.ogv"
	get_tree().root.add_child(prologue)
	get_tree().current_scene = prologue
	prologue.video.finished.connect(func(): finished_signals += 1)
	if mode not in ["old", "missing"]:
		await get_tree().create_timer(2.0).timeout
		_check(is_instance_valid(prologue) and prologue.video.is_playing() and max_position > 0.5, "新档实际读取并播放视频", {"position": max_position})
		_check(not sm.is_prologue_done(), "离开前不记录序章完成")
		_check(prologue.skip_button.get_script().resource_path == "res://scripts/ui/components/sprout_button.gd", "跳过使用既有 SproutButton")
		positions.append(max_position)
		await _capture("playing")
		await get_tree().create_timer(1.2).timeout
		positions.append(max_position)
		_check(positions[1] > positions[0] + 0.5, "视频播放进度持续增长")
		if mode in ["natural", "manual"]:
			print("PRO_01 等待完整自然播放或人工输入，最长 330 秒；不快进。")
		elif mode == "race":
			prologue.video.finished.emit()
			_key(KEY_ESCAPE)
			prologue.skip_button.pressed.emit()
			prologue.request_exit("repeated_callback")
		elif mode == "stalled":
			prologue.video.paused = true
		elif mode in ["mouse", "replay", "save-failure"]:
			if mode == "save-failure":
				_check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://save.json.tmp")) == OK, "转场保存失败夹具")
			_mouse(prologue.skip_button.get_global_rect().get_center())
		else:
			_key({"esc": KEY_ESCAPE, "space": KEY_SPACE, "enter": KEY_ENTER}.get(mode, KEY_ESCAPE))
	var deadline := Time.get_ticks_msec() + (330000 if mode in ["natural", "manual"] else 15000)
	while Time.get_ticks_msec() < deadline and (restaurant_entries == 0 or get_tree().has_group("prologue_transition")):
		await get_tree().process_frame
	_check(restaurant_entries == 1 and transitions == 1, "唯一转场成功进入餐厅", {"entries": restaurant_entries, "transitions": transitions})
	_check(black_seen, "黑幕达到全黑并实际渲染")
	_check(not is_instance_valid(prologue) and not get_tree().has_group("prologue_transition") and not get_tree().has_group("prologue"), "视频/转场遮罩全部销毁")
	if restaurant_entries != 1:
		return
	var scene := get_tree().current_scene
	var player := scene.get_node("Player")
	var guide := get_tree().get_first_node_in_group("tutorial_guide")
	_check(tm.active and tm.current_stage == (5 if mode == "old" else 1), "正式 TutorialGuide/TutorialManager 启动正确阶段", {"stage": tm.current_stage, "idx": tm.idx})
	_check(not get_tree().paused and not scene.get_node("Camera").paused, "餐厅未残留暂停或相机锁")
	_check(player.input_locked == tm._player_lock_owned and player.is_physics_processing() == not tm._player_lock_owned, "玩家锁仅由现有第一章对白持有")
	if mode != "old":
		_check(guide.dialog.visible and tm.idx == 0 and tm.steps[0].lines == ["……你终于醒了。"], "首句保持可见，跳过输入不泄漏到第一章")
		_check(not sm.is_chapter_1_done() and not sm.is_tutorial_done(), "没有补发章节完成")
	if mode == "save-failure":
		_check(not sm.is_prologue_done() and _disk().sha256_text() == protected_disk, "保存失败仍进入餐厅且正式标记回滚")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json.tmp"))
	elif mode == "old":
		_check(JSON.stringify(sm.data).sha256_text() == protected_memory and _disk().sha256_text() == protected_disk, "稳定旧档不播放且状态/文件保持不变")
		_check(max_position == 0.0, "旧档未启动视频")
	else:
		_check(sm.is_prologue_done(), "成功进入餐厅才记录序章完成")
	await get_tree().create_timer(0.8).timeout
	await _capture("restaurant")
	if mode == "natural":
		_check(finished_signals == 1 and max_position >= 200.0, "完整视频自然结束触发唯一 finished", {"position": max_position})
	if watch_replay:
		# 确认预览中的真实检查点写入、取消教程、再次写入均不能泄漏到正式状态。
		_check(sm.record_intro("awakened"), "预览副本可提交检查点")
	tm.skip_all()
	await get_tree().process_frame
	_check(not player.input_locked and player.is_physics_processing() and not guide.visible and not guide.dim.visible and not scene.get_node("Camera").paused, "取消第一章后输入/镜头/教程遮罩正常释放")
	if watch_replay:
		_check(sm._replaying and sm.record_intro("guest_arrived") and sm.save(), "取消教程后仍只能写入预览副本")
		_check(replay_clean and JSON.stringify(sm.data).sha256_text() == protected_memory and _disk().sha256_text() == protected_disk, "整次预览正式 data 与 save.json SHA256 不变")
		watch_replay = false

func _on_scene_changed() -> void:
	if get_tree().current_scene.scene_file_path == "res://scenes/restaurant_map_2d.tscn":
		restaurant_entries += 1

func _on_node_added(node: Node) -> void:
	if node.get_script() == load("res://scripts/prologue_transition.gd"):
		transitions += 1
		node.covered.connect(_on_covered)

func _on_covered() -> void:
	black_seen = true
	await _capture("black")

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _arg("--output-dir=").path_join(mode + "-" + label + ".png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	_check(result == OK, "保存实际渲染截图 " + label)
	captures.append(path)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)

func _mouse(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
