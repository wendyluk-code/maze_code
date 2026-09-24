extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const TIESHAN_TEXTURE := "res://assets/characters/tieshan/tieshan_collapse.tres"
const TIESHAN_PORTRAIT := "res://assets/characters/tieshan/tieshan_portrait.png"
const EXPECTED_GUEST_POSITION := Vector2(910, 198)

var checks: Array = []
var failures: Array[String] = []
var scene: Node2D = null
var guide: Control = null
var tm = null
var sm = null
var unknown_portrait_stages: Array[int] = []

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
	_verify_lesson_portrait_contract()

	# 路径一：阶段 2 可见、对白驻留；阶段 7 的正式事务由 CH1-05~09 夹具覆盖。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	await _start_scene()
	tm.start()
	var normal_guest := await _reach_guest_spawn()
	await _wait_for_guest_dialog(normal_guest, true)
	_verify_guest_visual(normal_guest)
	_verify_unknown_portrait(2)
	await _capture_if_requested()
	# 正常对白播完后，镜头、输入与教程阶段仍沿生产路径恢复。
	for line in 3:
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	await get_tree().create_timer(1.1).timeout
	_record("normal_cutscene_restores_camera_input_stage", tm.current_stage == 3
		and not tm._camera_parked and not scene.get_node("Camera").paused
		and scene.get_node("Camera").zoom.is_equal_approx(Vector2(0.85, 0.85))
		and not scene.get_node("Player").input_locked
		and scene.get_node("Player").is_physics_processing() and not guide.dim.visible)
	var player := scene.get_node("Player") as CharacterBody2D
	var before_move := player.position
	Input.action_press("ui_right")
	await get_tree().create_timer(0.2).timeout
	Input.action_release("ui_right")
	_record("normal_cutscene_allows_real_movement", player.position.distance_to(before_move) > 5.0)
	tm._cancel_current_run()
	await get_tree().create_timer(0.8).timeout
	_record("dialog_path_cancel_cleans_guest", not tm.active
		and not is_instance_valid(tm._parked_guest)
		and get_tree().get_nodes_in_group("guest").is_empty()
		and not sm.is_chapter_1_done() and not sm.is_tutorial_done())

	# 路径二：阶段 2 直接跳过，旧异步 timer 不得复活角色。
	await _dispose_scene()
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	await _start_scene()
	tm.start()
	var skipped_guest := await _reach_guest_spawn()
	_record("skip_precondition_is_mid_fade", is_instance_valid(skipped_guest)
		and skipped_guest.fade_started and not skipped_guest.fade_completed
		and skipped_guest.modulate.a < 1.0, {
			"alpha": skipped_guest.modulate.a if is_instance_valid(skipped_guest) else -1.0,
		})
	tm.skip_all()
	await get_tree().create_timer(1.2).timeout
	_record("skip_cleans_guest_and_stale_async", not tm.active
		and not is_instance_valid(tm._parked_guest)
		and tm._guest_fade_tween == null
		and get_tree().get_nodes_in_group("guest").is_empty())

	# 路径三：客人驻留时退出再进入，旧场景链失效且新流程从阶段 1 唯一启动。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	tm.start()
	var exited_guest := await _reach_guest_spawn()
	_record("exit_precondition_is_mid_fade", is_instance_valid(exited_guest)
		and exited_guest.fade_started and not exited_guest.fade_completed
		and exited_guest.modulate.a < 1.0, {
			"alpha": exited_guest.modulate.a if is_instance_valid(exited_guest) else -1.0,
		})
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
	# 跪倒与趴下前分别跳过，节点和旧动画均不能继续推进教程。
	for target_frame in [3, 6]:
		sm.data = {"tutorial_done": false, "chapter_1_done": false}
		tm.start()
		var moving_guest := await _reach_guest_spawn()
		var deadline := Time.get_ticks_msec() + 5000
		while is_instance_valid(moving_guest) and moving_guest.get_node("Portrait").frame < target_frame \
				and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		_record("skip_pose_%d_reached" % target_frame, is_instance_valid(moving_guest)
			and moving_guest.get_node("Portrait").frame == target_frame)
		tm.skip_all()
		await get_tree().create_timer(2.0).timeout
		_record("skip_pose_%d_restores_everything" % target_frame, not tm.active
			and get_tree().get_nodes_in_group("guest").is_empty()
			and not scene.get_node("Player").input_locked and not scene.get_node("Camera").paused
			and scene.get_node("Camera").zoom.is_equal_approx(Vector2(0.85, 0.85))
			and scene.get_node("Player").is_physics_processing() and not guide.dim.visible)

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

func _verify_lesson_portrait_contract() -> void:
	var unknown_steps: Array = []
	for step in tm.chapter_1_lesson():
		if str(step.get("speaker", "")) == "？？？":
			unknown_steps.append(step)
	var stages: Array[int] = []
	var portraits: Array[String] = []
	for step in unknown_steps:
		stages.append(int(step.get("stage", 0)))
		portraits.append(str(step.get("portrait", "")))
	var departure_unknown: Array = []
	var introduction_speaker := ""
	var offer_speaker := ""
	var agreement_speaker := ""
	for step in tm.departure_lesson():
		if str(step.get("speaker", "")) == "？？？":
			departure_unknown.append(step)
		match str(step.get("wrapup_id", "")):
			"introduction":
				introduction_speaker = str(step.get("speaker", ""))
			"offer":
				offer_speaker = str(step.get("speaker", ""))
			"agreement":
				agreement_speaker = str(step.get("speaker", ""))
	var chapter_unknown_contract := unknown_steps.size() > 2
	if chapter_unknown_contract:
		chapter_unknown_contract = stages[0] == 2
	for i in range(1, stages.size()):
		chapter_unknown_contract = chapter_unknown_contract and stages[i] == 7
	for portrait in portraits:
		chapter_unknown_contract = chapter_unknown_contract and portrait == TIESHAN_PORTRAIT
	var departure_portraits_are_tieshan := departure_unknown.size() > 1
	for step in departure_unknown:
		departure_portraits_are_tieshan = departure_portraits_are_tieshan \
			and str(step.get("portrait", "")) == TIESHAN_PORTRAIT
	_record("lesson_unknown_identity_contract", chapter_unknown_contract
		and departure_unknown.size() > 1
		and departure_portraits_are_tieshan
		and introduction_speaker == "？？？"
		and offer_speaker == "铁山"
		and agreement_speaker == "铁山", {
			"stages": stages,
			"portraits": portraits,
			"departure_unknown_count": departure_unknown.size(),
			"chapter_unknown_count": unknown_steps.size(),
			"introduction_speaker": introduction_speaker,
			"offer_speaker": offer_speaker,
			"agreement_speaker": agreement_speaker,
		})

func _reach_guest_spawn() -> Node2D:
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
	return guest

func _wait_for_guest_dialog(guest: Node2D, verify_fade: bool) -> void:
	var poses: Array[int] = []
	var anchor_stable := true
	var capture_count := 0
	var last_capture := 0
	var first_observed_alpha := guest.modulate.a if is_instance_valid(guest) else -1.0
	var saw_intermediate_alpha := false
	var dialog_appeared_before_fade := false
	if verify_fade:
		_record("guest_is_created_transparent", is_instance_valid(guest)
			and is_equal_approx(guest.fade_initial_alpha, 0.0)
			and first_observed_alpha <= 0.01
			and guest.fade_started, {
				"recorded_initial_alpha": guest.fade_initial_alpha if is_instance_valid(guest) else -1.0,
				"first_observed_alpha": first_observed_alpha,
			})
	var frames := 0
	var wait_started := Time.get_ticks_msec()
	while tm.active and Time.get_ticks_msec() - wait_started < 5000:
		if is_instance_valid(guest):
			var pose: int = guest.get_node("Portrait").frame
			if not pose in poses:
				poses.append(pose)
			anchor_stable = anchor_stable and guest.position.distance_to(EXPECTED_GUEST_POSITION) < 0.01
			var output := _argument("--output=")
			if not output.is_empty() and Time.get_ticks_msec() - last_capture >= 100:
				await RenderingServer.frame_post_draw
				var capture := get_viewport().get_texture().get_image()
				capture.save_png(output.get_base_dir().path_join("motion_%03d.png" % capture_count))
				capture_count += 1
				last_capture = Time.get_ticks_msec()
			var alpha := guest.modulate.a
			saw_intermediate_alpha = saw_intermediate_alpha or (alpha > 0.01 and alpha < 0.99)
			var unknown_visible: bool = guide.dialog.visible \
				and guide.dialog.speaker_name.text == "？？？"
			if unknown_visible:
				dialog_appeared_before_fade = alpha < 0.999 or not guest.fade_completed
				break
		frames += 1
		await get_tree().process_frame
	if verify_fade:
		_record("guest_fade_has_intermediate_frame", saw_intermediate_alpha, {
			"first_observed_alpha": first_observed_alpha,
			"frames": frames,
		})
	_record("unknown_dialog_visible", tm.idx == 6 and guide.dialog.visible
		and guide.dialog.speaker_name.text == "？？？", {
			"idx": tm.idx,
			"speaker": guide.dialog.speaker_name.text,
		})
	if verify_fade:
		_record("unknown_dialog_waits_for_completed_fade", not dialog_appeared_before_fade
			and is_instance_valid(guest) and guest.fade_completed
			and is_equal_approx(guest.modulate.a, 1.0), {
				"dialog_appeared_before_fade": dialog_appeared_before_fade,
				"fade_completed": guest.fade_completed if is_instance_valid(guest) else false,
				"final_alpha": guest.modulate.a if is_instance_valid(guest) else -1.0,
			})
	_record("guest_stays_for_unknown_dialog", is_instance_valid(guest)
		and guest == tm._parked_guest and guest.is_in_group("guest"))
	_record("collapse_visits_all_poses_in_order", poses == [0, 1, 2, 3, 4, 5, 6, 7], {"poses": poses})
	_record("collapse_does_not_move_ground_anchor", anchor_stable)

func _verify_guest_visual(guest: Node2D) -> void:
	if not is_instance_valid(guest):
		_record("guest_visual_available", false)
		return
	var portrait := guest.get_node_or_null("Portrait") as AnimatedSprite2D
	_record("guest_uses_playable_spriteframes", portrait != null
		and portrait.sprite_frames.resource_path == TIESHAN_TEXTURE)
	if portrait == null:
		return
	var animation := portrait.sprite_frames
	_record("eight_nonlooping_poses", animation.get_frame_count("collapse") == 8
		and not animation.get_animation_loop("collapse"))
	var first_bounds := Rect2()
	for i in 8:
		var image := animation.get_frame_texture("collapse", i).get_image()
		var bounds := _opaque_bounds(image)
		var foot := portrait.position.y + bounds.end.y * portrait.scale.y
		_record("pose_%d_transparency_and_anchor" % i, image.get_pixel(0, 0).a == 0.0
			and image.get_pixel(479, 479).a == 0.0 and absf(foot) <= 0.4,
			{"foot_local_y": foot, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
		if i == 0:
			first_bounds = bounds
	var body := scene.get_node("Player/Body") as Sprite2D
	var hero_height := _opaque_bounds(body.texture.get_image()).size.y * absf(body.scale.y)
	var standing_height := first_bounds.size.y * absf(portrait.scale.y)
	var ratio := standing_height / hero_height
	_record("standing_height_115_to_130_percent_of_hero", ratio >= 1.15 and ratio <= 1.30,
		{"hero_height": hero_height, "standing_height": standing_height, "ratio": ratio})
	_record("fixed_ground_anchor", guest.position.distance_to(EXPECTED_GUEST_POSITION) < 0.01)
	var cam := get_viewport().get_camera_2d()
	var screen_top := (guest.global_position + portrait.position + first_bounds.position * portrait.scale
		- cam.get_screen_center_position()) * cam.zoom + get_viewport().get_visible_rect().size * 0.5
	var screen_right := screen_top.x + first_bounds.size.x * portrait.scale.x * cam.zoom.x
	_record("standing_head_clear_of_chapter_header", screen_top.y >= 80.0 or screen_right <= 410.0,
		{"screen_top": [screen_top.x, screen_top.y]})
	_record("dialog_waits_for_prone_pose", guest.collapse_completed and portrait.frame == 7)
	var register := scene.get_node("InteractPoints/Register") as Node2D
	_record("guest_is_in_frontdesk_exterior", guest.position.y < register.position.y
		and absf(guest.position.x - register.position.x) <= 120.0)

func _opaque_bounds(image: Image) -> Rect2:
	var minimum := Vector2(image.get_size())
	var maximum := Vector2.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				minimum = minimum.min(Vector2(x, y))
				maximum = maximum.max(Vector2(x + 1, y + 1))
	return Rect2(minimum, maximum - minimum)

func _verify_unknown_portrait(stage: int) -> void:
	if stage in unknown_portrait_stages:
		return
	unknown_portrait_stages.append(stage)
	var texture_rect := guide.dialog.portrait_texture as TextureRect
	var fallback := guide.dialog.portrait_fallback as Label
	var texture := texture_rect.texture if is_instance_valid(texture_rect) else null
	_record("stage_%d_unknown_portrait_texture" % stage, texture != null
		and texture.resource_path == TIESHAN_PORTRAIT
		and texture.get_width() == 256 and texture.get_height() == 256, {
			"resource_path": texture.resource_path if texture else "none",
			"source_size": [texture.get_width(), texture.get_height()] if texture else [],
		})
	_record("stage_%d_unknown_portrait_layout" % stage, is_instance_valid(texture_rect)
		and guide.dialog.visible and guide.dialog.speaker_name.text == "？？？"
		and texture_rect.visible and is_instance_valid(fallback) and not fallback.visible
		and texture_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		and absf(texture_rect.size.x - 80.0) <= 2.0
		and absf(texture_rect.size.y - 80.0) <= 2.0, {
			"content_size": [texture_rect.size.x, texture_rect.size.y] if is_instance_valid(texture_rect) else [],
			"stretch_mode": texture_rect.stretch_mode if is_instance_valid(texture_rect) else -1,
			"fallback_visible": fallback.visible if is_instance_valid(fallback) else true,
		})

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
	_record("visible_capture", err == OK and image.get_width() == 1152 and image.get_height() == 648, {
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
