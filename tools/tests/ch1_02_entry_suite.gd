extends Node

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")

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
	check(guide.should_start_chapter_1(), "new_entry_requires_chapter")
	tm.start()
	await get_tree().process_frame
	check(tm.active and tm.current_stage == 1, "new_entry_starts_chapter_1")
	check(guide.visible and guide.chapter_title.visible
		and guide.chapter_title.text == "第一章：醒来与首单教程"
		and guide.chapter_stage.text == "阶段 1/7 · 苏醒与失忆",
		"chapter_title_and_identity_visible")

	await verify_opening_dialogue()
	await complete_default_lesson()
	await get_tree().create_timer(0.8).timeout
	check(not tm.active and sm.is_chapter_1_done() and sm.is_tutorial_done(),
		"normal_completion_persists_independent_state")
	check(not guide.visible and not guide.dim.visible and not guide.chapter_title.visible
		and not guide.chapter_stage.visible and not guide.skip_button.visible,
		"normal_completion_cleans_guide")
	check(not is_instance_valid(tm._parked_guest)
		and get_tree().get_nodes_in_group("guest").is_empty()
		and not scene.get_node("Camera").paused
		and not scene.get_node("Player").input_locked
		and scene.get_node("Player").is_physics_processing(),
		"normal_completion_cleans_async_state")
	check(get_tree().current_scene == scene, "chapter_stays_in_restaurant")
	check(stage_events == [1, 2, 3, 4, 5, 6, 7],
		"seven_stages_run_in_order", {"events": stage_events})
	report["normal_stage_events"] = stage_events.duplicate()

	await dispose_scene()
	# 旧存档只带 tutorial_done 时，第一章仍然是未完成状态。
	sm.data = {"tutorial_done": true}
	await start_scene()
	check(guide.should_start_chapter_1(), "legacy_tutorial_done_does_not_skip_chapter")
	# 新完成态独立于旧兼容字段。
	sm.data["chapter_1_done"] = true
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
	# 跳过路径需要恢复锁定、镜头、遮罩并写入同一独立完成态。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	tm.start()
	await get_tree().process_frame
	tm.skip_all()
	await get_tree().create_timer(0.8).timeout
	check(not tm.active and sm.is_chapter_1_done() and not guide.visible
		and not scene.get_node("Camera").paused
		and not scene.get_node("Player").input_locked
		and scene.get_node("Player").is_physics_processing(),
		"skip_restores_and_persists")
	check(get_tree().get_nodes_in_group("guest").is_empty(), "skip_cleans_guest")

	# 在客人过场期间退出，旧 token 失效；重新进入只能启动一条新流程。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	tm.start()
	await verify_opening_dialogue()
	await get_tree().create_timer(0.15).timeout
	await dispose_scene()
	await start_scene()
	tm.start()
	await get_tree().process_frame
	check(tm.active and tm.idx == 0 and tm.current_stage == 1
		and guide.chapter_title.visible and get_tree().get_nodes_in_group("guest").is_empty(),
		"exit_reentry_starts_one_clean_flow")
	tm.skip_all()
	await get_tree().create_timer(0.8).timeout
	check(not tm.active and not guide.visible and get_tree().get_nodes_in_group("guest").is_empty(),
		"exit_reentry_skip_has_no_residue")

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
	scene = SCENE.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	guide = scene.get_node("UIOverlay/TutorialGuide")
	scene.get_node("Player").spawn_ready = true

func dispose_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	get_tree().current_scene = self
	await get_tree().process_frame
	await get_tree().process_frame
	scene = null
	guide = null

func verify_opening_dialogue() -> void:
	var lesson: Array = tm.chapter_1_lesson()
	for i in 5:
		check(tm.idx == i and guide.dialog.visible, "opening_dialog_%d_progresses" % (i + 1))
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	check(tm.idx == 5, "opening_dialogue_reaches_guest_stage")

func complete_default_lesson() -> void:
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
