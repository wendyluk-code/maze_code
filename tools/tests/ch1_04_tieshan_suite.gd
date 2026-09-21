extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const TIESHAN_TEXTURE := "res://assets/characters/tieshan/tieshan_original.png"
const EXPECTED_GUEST_POSITION := Vector2(1035, 415)

var checks: Array = []
var failures: Array[String] = []
var scene: Node2D = null
var guide: Control = null
var tm = null
var sm = null

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	if not _verify_isolation():
		var isolation_report := _build_report()
		_write_report(isolation_report)
		print("CH1_04 tieshan refused: isolation precondition failed report=", JSON.stringify(isolation_report))
		get_tree().quit(2)
		return
	tm = get_tree().root.get_node("TutorialManager")
	sm = get_tree().root.get_node("SaveManager")
	_record("replay_argument_detected", tm.is_replay_requested(), {
		"args": OS.get_cmdline_user_args(),
	})

	# 路径一：阶段 2 可见、对白驻留，并在正常完成时清理。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	await _start_scene()
	tm.start()
	var normal_guest := await _reach_guest_dialog()
	_verify_guest_visual(normal_guest)
	await _capture_if_requested()
	await _complete_default_lesson()
	await get_tree().create_timer(0.8).timeout
	_record("normal_completion_cleans_guest", not tm.active
		and not is_instance_valid(tm._parked_guest)
		and get_tree().get_nodes_in_group("guest").is_empty())

	# 路径二：阶段 2 直接跳过，旧异步 timer 不得复活角色。
	await _dispose_scene()
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	await _start_scene()
	tm.start()
	var skipped_guest := await _reach_guest_dialog()
	_record("skip_precondition_has_guest", is_instance_valid(skipped_guest))
	tm.skip_all()
	await get_tree().create_timer(1.2).timeout
	_record("skip_cleans_guest_and_stale_async", not tm.active
		and not is_instance_valid(tm._parked_guest)
		and get_tree().get_nodes_in_group("guest").is_empty())

	# 路径三：客人驻留时退出再进入，旧场景链失效且新流程从阶段 1 唯一启动。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	tm.start()
	var exited_guest := await _reach_guest_dialog()
	_record("exit_precondition_has_guest", is_instance_valid(exited_guest))
	await _dispose_scene()
	await _start_scene()
	tm.start()
	await get_tree().process_frame
	await get_tree().process_frame
	_record("exit_reentry_has_one_clean_flow", tm.active and tm.idx == 0
		and tm.current_stage == 1 and not is_instance_valid(tm._parked_guest)
		and get_tree().get_nodes_in_group("guest").is_empty())
	tm.skip_all()
	await get_tree().create_timer(0.8).timeout
	_record("exit_reentry_final_cleanup", not tm.active
		and get_tree().get_nodes_in_group("guest").is_empty())

	var report := _build_report()
	_write_report(report)
	print("CH1_04 tieshan report=", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

func _verify_isolation() -> bool:
	var declared_root := _normalize_path(_argument("--isolation-root="))
	var declared_appdata := _normalize_path(_argument("--isolation-appdata="))
	var actual_user_dir := _normalize_path(ProjectSettings.globalize_path("user://"))
	var actual_appdata := _normalize_path(OS.get_environment("APPDATA"))
	var marker_ok := OS.get_environment("MAZE_CH1_04_ISOLATED") == "1"
	var root_ok := not declared_root.is_empty() \
		and actual_user_dir.begins_with(declared_root + "/")
	var appdata_ok := not declared_appdata.is_empty() \
		and actual_appdata == declared_appdata \
		and actual_appdata.begins_with(declared_root + "/")
	_record("isolated_user_data_directory", marker_ok and root_ok and appdata_ok, {
		"marker": marker_ok,
		"declared_root": declared_root,
		"declared_appdata": declared_appdata,
		"actual_appdata": actual_appdata,
		"actual_user_dir": actual_user_dir,
	})
	return marker_ok and root_ok and appdata_ok

func _normalize_path(value: String) -> String:
	return value.replace("\\", "/").trim_suffix("/").to_lower()

func _build_report() -> Dictionary:
	return {
		"checks": checks,
		"failures": failures,
		"guest_position": [EXPECTED_GUEST_POSITION.x, EXPECTED_GUEST_POSITION.y],
		"texture": TIESHAN_TEXTURE,
		"capture": _argument("--output="),
		"isolation_root": _argument("--isolation-root="),
		"isolation_appdata": _argument("--isolation-appdata="),
		"user_data_dir": ProjectSettings.globalize_path("user://"),
	}

func _write_report(report: Dictionary) -> void:
	var report_path := _argument("--report=")
	if report_path.is_empty():
		return
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		failures.append("write_report")

func _start_scene() -> void:
	scene = RESTAURANT_SCENE.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	guide = scene.get_node("UIOverlay/TutorialGuide")
	scene.get_node("Player").spawn_ready = true

func _dispose_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	get_tree().current_scene = self
	await get_tree().process_frame
	await get_tree().process_frame
	scene = null
	guide = null

func _reach_guest_dialog() -> Node2D:
	for i in 5:
		if not tm.active or tm.idx != i or not guide.dialog.visible:
			_record("opening_dialog_%d_ready" % (i + 1), false, {"idx": tm.idx})
			return null
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	var frames := 0
	var wait_started := Time.get_ticks_msec()
	while tm.active and not is_instance_valid(tm._parked_guest) \
		and Time.get_ticks_msec() - wait_started < 5000:
		frames += 1
		await get_tree().process_frame
	var guest := tm._parked_guest as Node2D
	_record("stage_2_spawns_guest", is_instance_valid(guest), {
		"frames": frames,
		"elapsed_ms": Time.get_ticks_msec() - wait_started,
		"idx": tm.idx,
	})
	frames = 0
	wait_started = Time.get_ticks_msec()
	while tm.active and tm.idx == 5 and Time.get_ticks_msec() - wait_started < 5000:
		frames += 1
		await get_tree().process_frame
	_record("unknown_dialog_visible", tm.idx == 6 and guide.dialog.visible
		and guide.dialog.speaker_name.text == "？？？", {
			"idx": tm.idx,
			"speaker": guide.dialog.speaker_name.text,
		})
	_record("guest_stays_for_unknown_dialog", is_instance_valid(guest)
		and guest == tm._parked_guest and guest.is_in_group("guest"))
	return guest

func _verify_guest_visual(guest: Node2D) -> void:
	if not is_instance_valid(guest):
		_record("guest_visual_available", false)
		return
	var portrait := guest.get_node_or_null("Portrait") as Sprite2D
	_record("guest_uses_tieshan_texture", portrait != null and portrait.texture != null
		and portrait.texture.resource_path == TIESHAN_TEXTURE, {
			"resource_path": portrait.texture.resource_path if portrait and portrait.texture else "none",
		})
	if portrait == null or portrait.texture == null:
		return
	var image := portrait.texture.get_image()
	var transparent_corners := image != null \
		and image.get_pixel(0, 0).a == 0.0 \
		and image.get_pixel(image.get_width() - 1, 0).a == 0.0 \
		and image.get_pixel(0, image.get_height() - 1).a == 0.0 \
		and image.get_pixel(image.get_width() - 1, image.get_height() - 1).a == 0.0
	_record("texture_has_no_opaque_rectangle", transparent_corners, {
		"size": [image.get_width(), image.get_height()] if image else [],
	})
	var register := scene.get_node("InteractPoints/Register") as Node2D
	_record("guest_is_outside_register", guest.position.y > register.position.y + 150.0
		and absf(guest.position.x - register.position.x) < 100.0, {
			"guest": [guest.position.x, guest.position.y],
			"register": [register.position.x, register.position.y],
		})
	_record("guest_position_survives_bobbing", guest.position.distance_to(EXPECTED_GUEST_POSITION) <= 4.0, {
		"actual": [guest.position.x, guest.position.y],
	})
	var opaque_bottom_local := portrait.position.y + 927.0 * portrait.scale.y
	var visual_size := Vector2(1301.0, 909.0) * portrait.scale.abs()
	_record("foot_anchor_and_scale_are_reasonable", absf(opaque_bottom_local) <= 0.25
		and visual_size.x >= 280.0 and visual_size.x <= 320.0
		and visual_size.y >= 195.0 and visual_size.y <= 220.0
		and guest.z_index > 0, {
			"opaque_bottom_local": opaque_bottom_local,
			"visual_size": [visual_size.x, visual_size.y],
			"z_index": guest.z_index,
		})

func _complete_default_lesson() -> void:
	var guard := 0
	while tm.active and guard < 40:
		guard += 1
		if tm.idx < 0 or tm.idx >= tm.steps.size():
			break
		var step: Dictionary = tm.steps[tm.idx]
		match str(step.get("type", "")):
			"cutscene_guest":
				await get_tree().create_timer(2.3).timeout
			"dialog":
				guide.dialog._advance()
				guide.dialog._advance()
				await get_tree().process_frame
			"move_to", "interact":
				tm._complete_step(tm._run_token)
				await get_tree().create_timer(1.0).timeout
			"notify":
				await get_tree().create_timer(2.2).timeout
			"finish":
				break
			_:
				break

func _capture_if_requested() -> void:
	var output := _argument("--output=")
	if output.is_empty():
		return
	# 等打字机文本显出后再截，证据同时包含“？？？”对白与驻留角色。
	await get_tree().create_timer(1.1).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	_record("capture_dialog_text_visible", guide.dialog.visible
		and guide.dialog.speaker_name.text == "？？？"
		and not guide.dialog.dialog_text.text.is_empty(), {
			"speaker": guide.dialog.speaker_name.text,
			"text": guide.dialog.dialog_text.text,
		})
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		_record("visible_capture", false, {"reason": "no_viewport_texture"})
		return
	var image := viewport_texture.get_image()
	if image == null:
		_record("visible_capture", false, {"reason": "no_viewport_image"})
		return
	var err := image.save_png(output)
	_record("visible_capture", err == OK, {
		"path": output,
		"size": [image.get_width(), image.get_height()],
		"error": err,
	})

func _record(name: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"name": name, "passed": passed, "details": details})
	if not passed:
		failures.append(name)
		push_error("CH1_04 FAILED: " + name + " " + JSON.stringify(details))

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""
