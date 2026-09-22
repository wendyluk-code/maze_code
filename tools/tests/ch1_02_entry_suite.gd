extends Node

const SCENE_PATH := "res://scenes/restaurant_map_2d.tscn"

class EmptyWalkZone:
	extends Node
	var polygons: Array = []
	var rebuild_calls := 0

	func _build_polygons() -> void:
		rebuild_calls += 1

	func get_spawn_point(_radius: float = 0.0) -> Vector2:
		return Vector2.ZERO

var report := {"checks": [], "stage_events": [], "failures": 0}
var failures := 0
var scene: Node2D = null
var guide: Control = null
var tm = null
var sm = null
var stage_events: Array = []

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	tm = get_tree().root.get_node("TutorialManager")
	sm = get_tree().root.get_node("SaveManager")
	if not tm.chapter_1_stage_changed.is_connected(_on_stage_changed):
		tm.chapter_1_stage_changed.connect(_on_stage_changed)
	sm.data = {"tutorial_done": false, "chapter_1_done": false}

	check_lesson_shape()
	await start_scene()
	verify_real_entry_spawn()
	check(guide.should_start_chapter_1(), "new_entry_requires_chapter")
	await get_tree().process_frame
	check(tm.active and tm.current_stage == 1, "new_entry_starts_chapter_1")
	check(guide.visible and guide.chapter_title.visible
		and guide.chapter_title.text == "第一章：醒来与首单教程"
		and guide.chapter_stage.text == "阶段 1/7 · 苏醒与失忆",
		"chapter_title_and_identity_visible")

	await verify_opening_dialogue()
	# 本夹具只验证真实入口与早期退出；首单及阶段7由 CH1-05~09 的真实事务夹具覆盖。
	tm._cancel_current_run()
	await get_tree().create_timer(0.8).timeout
	check(not tm.active and not sm.is_chapter_1_done() and not sm.is_tutorial_done(),
		"early_exit_keeps_chapter_unfinished")
	check(not guide.visible and not guide.dim.visible and not guide.chapter_title.visible
		and not guide.chapter_stage.visible and not guide.skip_button.visible,
		"early_exit_cleans_guide")
	check(not is_instance_valid(tm._parked_guest)
		and get_tree().get_nodes_in_group("guest").is_empty()
		and not scene.get_node("Camera").paused
		and not scene.get_node("Player").input_locked
		and scene.get_node("Player").is_physics_processing(),
		"early_exit_cleans_async_state")
	check(get_tree().current_scene == scene, "chapter_stays_in_restaurant")
	check(stage_events == [1, 2],
		"entry_reaches_guest_stage_only", {"events": stage_events})
	report["entry_stage_events"] = stage_events.duplicate()

	await dispose_scene()
	# 旧存档只带 tutorial_done 时，第一章仍然是未完成状态。
	sm.data = {"tutorial_done": true}
	await start_scene()
	check(guide.should_start_chapter_1() and tm.active,
		"legacy_tutorial_done_does_not_skip_chapter")
	tm._cancel_current_run()
	await dispose_scene()
	# 新完成态独立于旧兼容字段。
	sm.data = {"tutorial_done": true, "chapter_1_done": true}
	await start_scene()
	check(not guide.should_start_chapter_1(),
		"completed_chapter_skips_normal_entry")

	check(not guide.should_start_chapter_1(), "completed_entry_is_not_replayed")
	# --replay-tutorial 的同一入口允许已完成章节再次播放，但仍可安全跳过。
	tm._replay_requested = true
	check(guide.should_start_chapter_1(), "replay_overrides_completed_state")
	tm.start()
	await get_tree().process_frame
	check(tm.active and tm.idx == 0 and guide.chapter_title.visible, "replay_starts_chapter_1")
	tm.skip_all()
	await get_tree().create_timer(0.8).timeout
	check(not tm.active and get_tree().get_nodes_in_group("guest").is_empty()
		and not scene.get_node("Camera").paused, "replay_skip_cleans_state")
	tm._replay_requested = false
	# 跳过路径需要恢复锁定、镜头、遮罩，但不能伪造章节完成态。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	tm.start()
	await get_tree().process_frame
	tm.skip_all()
	await get_tree().create_timer(0.8).timeout
	check(not tm.active and not sm.is_chapter_1_done() and not sm.is_tutorial_done() and not guide.visible
		and not scene.get_node("Camera").paused
		and not scene.get_node("Player").input_locked
		and scene.get_node("Player").is_physics_processing(),
		"skip_restores_without_marking_completion")
	check(get_tree().get_nodes_in_group("guest").is_empty(), "skip_cleans_guest")

	# 在客人过场期间退出，旧 token 失效；重新进入只能启动一条新流程。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	tm.start()
	await verify_opening_dialogue()
	await get_tree().create_timer(0.15).timeout
	await dispose_scene()
	await start_scene()
	await get_tree().process_frame
	check(tm.active and tm.idx == 0 and tm.current_stage == 1
		and guide.chapter_title.visible and get_tree().get_nodes_in_group("guest").is_empty(),
		"exit_reentry_starts_one_clean_flow")
	tm.skip_all()
	await get_tree().create_timer(0.8).timeout
	check(not tm.active and not guide.visible and get_tree().get_nodes_in_group("guest").is_empty(),
		"exit_reentry_skip_has_no_residue")
	await verify_spawn_failure_is_bounded()

	report["stage_events"] = stage_events
	report["failures"] = failures
	var output := argument("--output=")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "\t"))
		else:
			push_error("Cannot write report: " + output)
			failures += 1
	print("CH1_02 checks=", report["checks"].size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func check_lesson_shape() -> void:
	var lesson: Array = tm.chapter_1_lesson()
	var stages: Array = []
	for step in lesson:
		var stage := int(step.get("stage", 0))
		if stages.is_empty() or stages.back() != stage:
			stages.append(stage)
	check(stages == [1, 2, 3, 4, 5, 6, 7], "lesson_has_seven_ordered_stages", {"stages": stages})
	var opening: Array = []
	for i in 5:
		var step: Dictionary = lesson[i]
		opening.append(str(step["speaker"]) + ":" + str(step["lines"][0]))
	check(opening == ["芽芽:……你终于醒了。", "芽芽:你还记得我吗？", "你:……？",
		"芽芽:……果然，你又想不起来了。", "芽芽:没关系。我陪着你，总会想起来的。"],
		"opening_dialogue_is_locked")

func start_scene() -> void:
	# 测试控制节点留在 root 下，不再把夹具实例当作 current_scene；使用与产品
	# 相同的场景切换，使 TutorialGuide._ready() 自动启动并立即锁定玩家。
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	var err := get_tree().change_scene_to_file(SCENE_PATH)
	check(err == OK, "restaurant_scene_change_started", {"error": err})
	if err != OK:
		return
	await get_tree().scene_changed
	scene = get_tree().current_scene as Node2D
	guide = scene.get_node("UIOverlay/TutorialGuide")

func verify_real_entry_spawn() -> void:
	var player := scene.get_node("Player")
	var zone := scene.get_node("WalkZone")
	var safe: bool = zone.has_method("is_circle_inside") \
		and zone.is_circle_inside(player.global_position, player.collision_radius_world())
	var entry_observation := {
		"tutorial_active": tm.active,
		"tutorial_index": tm.idx,
		"input_locked": player.input_locked,
		"physics_processing": player.is_physics_processing(),
		"spawn_ready": player.spawn_ready,
		"spawn_init_state": player.spawn_init_state,
		"spawn_init_attempts": player.spawn_init_attempts,
		"spawn_resolved_in_ready": player.spawn_resolved_in_ready,
		"position": [player.global_position.x, player.global_position.y],
	}
	report["real_entry_observation"] = entry_observation
	check(tm.active and tm.idx == 0 and player.input_locked \
		and not player.is_physics_processing() and player.spawn_ready \
		and player.spawn_init_state == player.SPAWN_INIT_READY \
		and player.spawn_init_attempts == 1 and player.spawn_resolved_in_ready,
		"real_entry_spawn_ready_before_tutorial_lock", entry_observation)
	check(safe, "real_entry_spawn_has_collision_clearance", {
		"position": [player.global_position.x, player.global_position.y],
		"radius": player.collision_radius_world()})
	check(player.nearest_interactable() == null, "real_entry_spawn_not_on_interactable", {
		"nearest": player.nearest_interactable().name if player.nearest_interactable() else "none"})
	var camera := scene.get_node("Camera") as Camera2D
	check(player.global_position == zone.preferred_spawn_point \
		and camera.global_position.distance_to(player.global_position) <= 0.1,
		"camera_starts_on_final_spawn_without_jump", {
			"player": [player.global_position.x, player.global_position.y],
			"camera": [camera.global_position.x, camera.global_position.y],
			"preferred": [zone.preferred_spawn_point.x, zone.preferred_spawn_point.y]})

func dispose_scene() -> void:
	if is_instance_valid(scene):
		if get_tree().current_scene == scene:
			get_tree().current_scene = null
		scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	scene = null
	guide = null

func verify_spawn_failure_is_bounded() -> void:
	var player = scene.get_node("Player")
	var fake_zone := EmptyWalkZone.new()
	scene.add_child(fake_zone)
	player.walk_zone = fake_zone
	player.spawn_ready = false
	player.spawn_init_state = player.SPAWN_INIT_PENDING
	player.spawn_init_attempts = 0
	for _i in 8:
		player._try_resolve_spawn()
	var attempts_after_calls: int = player.spawn_init_attempts
	for _i in 3:
		await get_tree().physics_frame
	var details := {
		"state": player.spawn_init_state,
		"attempts_after_calls": attempts_after_calls,
		"attempts_after_physics": player.spawn_init_attempts,
		"rebuild_calls": fake_zone.rebuild_calls,
	}
	report["spawn_failure_probe"] = details
	check(player.spawn_init_state == player.SPAWN_INIT_FAILED \
		and attempts_after_calls == 1 and player.spawn_init_attempts == 1 \
		and fake_zone.rebuild_calls == 0,
		"spawn_failure_is_terminal_without_rebuild_loop", details)
	fake_zone.queue_free()

func verify_opening_dialogue() -> void:
	var lesson: Array = tm.chapter_1_lesson()
	for i in 5:
		check(tm.idx == i and guide.dialog.visible, "opening_dialog_%d_progresses" % (i + 1))
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	check(tm.idx == 5, "opening_dialogue_reaches_guest_stage")

func _on_stage_changed(stage: int, _title: String) -> void:
	stage_events.append(stage)

func check(condition: bool, name: String, details: Dictionary = {}) -> void:
	report["checks"].append({"name": name, "passed": condition, "details": details})
	if not condition:
		failures += 1
		push_error("CH1_02 FAILED: " + name + " " + JSON.stringify(details))

func argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""
