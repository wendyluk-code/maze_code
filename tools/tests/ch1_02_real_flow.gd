extends SceneTree

const RESTAURANT_SCENE := "res://scenes/restaurant_map_2d.tscn"

var scene: Node2D = null
var player: CharacterBody2D = null
var zone: Node = null
var guide: Control = null
var tm = null
var sm = null
var stage_events: Array[int] = []
var interactions: Array = []
var checks: Array = []
var failures: Array[String] = []
var report_dir := ""
var capture_enabled := true
var max_guard_frames := 0

const ROUTE_GRID := 8.0
const ROUTE_CLEARANCE := 24.0
const ROUTE_START_ESCAPE := 160.0
const ROUTE_NEAREST_MARGIN := 12.0
const WAYPOINT_TOLERANCE := 5.0

func _init() -> void:
	report_dir = _argument("--output-dir=")
	capture_enabled = not _has_argument("--no-capture")
	call_deferred("run_real_flow")

func run_real_flow() -> void:
	tm = root.get_node("TutorialManager")
	sm = root.get_node("SaveManager")
	if not tm.chapter_1_stage_changed.is_connected(_on_stage_changed):
		tm.chapter_1_stage_changed.connect(_on_stage_changed)
	# 测试只改变隔离 APPDATA 下的 SaveManager 内存，不接触用户真实存档。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}

	await _load_restaurant()
	if not _check_auto_entry("initial_auto_entry"):
		_finish_report()
		return
	await _wait_for_opening_line()
	await _capture("01-opening")

	# 真实退出重进：只投递一个开场对白后切换场景，不调用 TutorialManager.start()。
	stage_events.clear()
	interactions.clear()
	await _press_viewport_action("ui_accept")
	await _press_viewport_action("ui_accept")
	var interrupted_idx = tm.idx
	await _load_restaurant()
	if tm.active and tm.idx == 0 and guide.visible and guide.chapter_title.visible \
		and get_nodes_in_group("guest").is_empty():
		_record("exit_reentry_starts_clean_flow", true, {"interrupted_idx": interrupted_idx})
	else:
		_record("exit_reentry_starts_clean_flow", false, {"interrupted_idx": interrupted_idx, "idx": tm.idx, "active": tm.active})
	stage_events.clear()
	if tm.current_stage == 1:
		stage_events.append(1)

	await _complete_opening_dialogues_with_input()
	await _run_remaining_steps_with_input()
	# 真实首单交付后故意停在阶段7；CH1-09 负责真实仓库、地图、队伍与 ready_to_depart。
	await _capture("02-stage7-checkpoint")
	var normal_stage_events := stage_events.duplicate()
	_record("seven_stages_in_order", normal_stage_events == [1, 2, 3, 4, 5, 6, 7], {"events": normal_stage_events})
	_record("four_real_interactions", interactions.size() == 4 and _all_interactions_valid(), {"interactions": interactions})

	_record("stage7_checkpoint_is_not_completion", tm.active and tm.current_stage == 7
		and not sm.is_chapter_1_done() and not sm.is_tutorial_done()
		and not sm.is_ready_to_depart()
		and sm.departure_state().cards == {"status": "pending_content", "unlocked": false, "card_ids": []}, {
		"active": tm.active, "stage": tm.current_stage, "idx": tm.idx,
		"chapter_1_done": sm.is_chapter_1_done(), "tutorial_done": sm.is_tutorial_done(),
		"departure_step": sm.departure_state().step, "cards": sm.departure_state().cards})
	_record("chapter_stays_in_restaurant", current_scene == scene
		and scene.name == "RestaurantMap", {"scene": current_scene.name if current_scene else "none"})

	# 首单结算档再次进入：应恢复阶段7检查点，而不是重播阶段1或伪造完成。
	tm._cancel_current_run()
	await _load_restaurant()
	_record("settled_reentry_resumes_wrapup", tm.active and tm.current_stage == 7
		and tm.idx >= 0 and str(tm.steps[tm.idx].get("wrapup_id", "")) == "relief"
		and guide.visible and not sm.is_chapter_1_done() and not sm.is_tutorial_done()
		and not scene.get_node("Camera").paused, {
			"active": tm.active, "stage": tm.current_stage, "idx": tm.idx,
			"wrapup_id": str(tm.steps[tm.idx].get("wrapup_id", "")) if tm.active else "inactive",
			"guide_visible": guide.visible, "camera_paused": scene.get_node("Camera").paused})
	tm._cancel_current_run()

	_finish_report()

func _load_restaurant() -> void:
	change_scene_to_file(RESTAURANT_SCENE)
	await scene_changed
	await process_frame
	await process_frame
	scene = current_scene as Node2D
	player = scene.get_node("Player") as CharacterBody2D
	zone = scene.get_node("WalkZone")
	guide = scene.get_node("UIOverlay/TutorialGuide") as Control
	# 真实入口必须在教程锁定玩家物理前完成出生定位；测试不得临时开启
	# 物理帧来掩盖产品初始化时序错误。
	max_guard_frames = 0
	var spawn_point := Vector2.ZERO
	while max_guard_frames < 4 and not player.spawn_ready:
		max_guard_frames += 1
		await process_frame
	if zone.polygons.size() > 0:
		spawn_point = zone.get_spawn_point(player.collision_radius_world())
	var spawn_safe: bool = zone.has_method("is_circle_inside") \
		and zone.is_circle_inside(player.global_position, player.collision_radius_world())
	var spawn_not_on_interactable: bool = player.nearest_interactable() == null
	var camera := scene.get_node("Camera") as Camera2D
	var camera_on_spawn: bool = camera.global_position.distance_to(player.global_position) <= 0.1
	_record("scene_loaded", scene != null and player != null and guide != null and spawn_safe \
		and player.spawn_ready and spawn_not_on_interactable and camera_on_spawn, {
		"scene": scene.name if scene else "none", "save_path": ProjectSettings.globalize_path("user://save.json"),
		"spawn_ready": player.spawn_ready, "spawn": [player.global_position.x, player.global_position.y],
		"spawn_expected": [spawn_point.x, spawn_point.y], "spawn_safe": spawn_safe,
		"nearest_interactable": player.nearest_interactable().name if player.nearest_interactable() else "none",
		"camera_on_spawn": camera_on_spawn,
		"physics_processing": player.is_physics_processing(), "input_locked": player.input_locked})

func _wait_for_opening_line() -> void:
	var expected := "……你终于醒了。"
	var frames := 0
	while guide.dialog.dialog_text.text != expected and frames < 120:
		frames += 1
		await process_frame
	_record("opening_line_visible_at_safe_spawn",
		guide.dialog.speaker_name.text == "芽芽" and guide.dialog.dialog_text.text == expected \
		and player.spawn_ready and player.input_locked and not player.is_physics_processing() \
		and player.nearest_interactable() == null,
		{"frames": frames, "speaker": guide.dialog.speaker_name.text,
		"line": guide.dialog.dialog_text.text, "spawn": [player.global_position.x, player.global_position.y]})

func _check_auto_entry(label: String) -> bool:
	var ok: bool = tm.active and tm.idx == 0 and tm.current_stage == 1 and guide.visible \
		and guide.chapter_title.visible and guide.chapter_title.text == "第一章：醒来与首单教程" \
		and guide.chapter_stage.text == "阶段 1/7 · 苏醒与失忆"
	_record(label, ok, {"active": tm.active, "idx": tm.idx, "stage": tm.current_stage,
		"title": guide.chapter_title.text if guide else "none", "stage_text": guide.chapter_stage.text if guide else "none"})
	return ok

func _complete_opening_dialogues_with_input() -> void:
	for dialog_index in 5:
		var before = tm.idx
		if not guide.dialog.visible:
			_record("dialog_visible_%d" % (dialog_index + 1), false, {"idx": tm.idx})
			return
		# 每句先用一次视口确认输入补全打字，再用一次进入下一句。
		await _press_viewport_action("ui_accept")
		await _press_viewport_action("ui_accept")
		_record("dialog_input_%d" % (dialog_index + 1), tm.idx == before + 1, {
			"before_idx": before, "after_idx": tm.idx})

func _run_remaining_steps_with_input() -> void:
	var guard := 0
	while tm.active and guard < 1600:
		guard += 1
		if tm.idx < 0 or tm.idx >= tm.steps.size():
			break
		var step: Dictionary = tm.steps[tm.idx]
		if int(step.get("stage", 0)) == 7:
			# 首单交付已经完成 CH1-05~08；阶段7的真实经营检查点由 CH1-09 接管。
			break
		var step_type := str(step.get("type", ""))
		match step_type:
			"cutscene_guest":
				var before_cutscene = tm.idx
				await _wait_until_index_changes(before_cutscene, 240)
				_record("guest_cutscene_auto_advance", tm.idx > before_cutscene, {"idx": tm.idx})
			"dialog":
				var before_dialog = tm.idx
				var dialog_attempts := 0
				while tm.active and tm.idx == before_dialog and dialog_attempts < 6:
					dialog_attempts += 1
					await _wait_frames(2)
					await _press_viewport_action("ui_accept")
				_record("later_dialog_input_%d" % before_dialog, tm.idx == before_dialog + 1, {
					"before_idx": before_dialog, "after_idx": tm.idx, "attempts": dialog_attempts})
			"move_to":
				var target = tm.resolve_target(step.get("target"))
				var radius := float(step.get("radius", 120.0))
				if not await _walk_to_target_with_input(target, radius):
					break
			"interact":
				# TutorialManager 的 move_to 只按距离推进；若玩家在上一处交互后
				# 已进入下一目标半径，move_to 可能被同一帧跳过，但目标仍未成为
				# 最近交互点。此处补做真实移动，不推进任何教程步骤。
				var interaction_target = tm.resolve_target(step.get("target"))
				if interaction_target != null and player.nearest_interactable() != interaction_target:
					var interaction_radius := float(step.get("radius", 120.0))
					if not await _walk_to_target_with_input(interaction_target, interaction_radius, false):
						break
				if not await _interact_with_input(step):
					break
			"notify":
				var before_notify = tm.idx
				await _wait_until_index_changes(before_notify, 240)
				_record("chapter_hint_auto_advance", tm.idx > before_notify, {"idx": tm.idx})
			"finish":
				await process_frame
				break
			_:
				_record("known_step_type", false, {"type": step_type, "idx": tm.idx})
				break
	if guard >= 1600:
		_record("real_flow_guard", false, {"idx": tm.idx, "active": tm.active})

func _interact_with_input(step: Dictionary) -> bool:
	var before = tm.idx
	var target = tm.resolve_target(step.get("target"))
	var chosen = player.nearest_interactable()
	var in_range: bool = target != null and player.interaction_distance_to(target) <= player.INTERACT_RANGE
	var nearest_matches: bool = chosen == target
	await _press_viewport_action("interact")
	# CH1-06 的仓库交互先打开真实模态；回归流继续走真实 UI 选择与领取，
	# 不把仓库领取重新降级为单次 Toast。
	if str(step.get("target", "")) == "仓库":
		var warehouse_modal := scene.get_node_or_null("UIOverlay/WarehouseModal")
		if is_instance_valid(warehouse_modal) and warehouse_modal.visible:
			warehouse_modal._on_slot_selected("rockmane_meat")
			warehouse_modal._on_slot_selected("rock_salt")
			warehouse_modal._on_claim_pressed()
			await process_frame
	var step_delta: int = tm.idx - before
	# 交互完成后若下一步立刻是单句对话，同一个 E 事件可能被新对话框消费，
	# 因此允许 idx 多推进一步；仍要求本次输入至少推进了当前 interact 步骤。
	var advanced: bool = step_delta >= 1
	interactions.append({"target": target.display_name if target else "none",
		"nearest": chosen.display_name if chosen else "none",
		"before_idx": before, "after_idx": tm.idx, "step_delta": step_delta,
		"position": [snappedf(player.global_position.x, 0.001), snappedf(player.global_position.y, 0.001)],
		"effective_distance": player.interaction_distance_to(target) if target else -1.0,
		"in_range": in_range, "nearest_matches": nearest_matches, "advanced": advanced})
	_record("real_E_%s" % str(step.get("target", "unknown")), advanced,
		{"in_range": in_range, "nearest_matches": nearest_matches, "before_idx": before,
		"after_idx": tm.idx, "step_delta": step_delta})
	return advanced

func _walk_to_target_with_input(target: Node2D, radius: float, advance_step: bool = true) -> bool:
	if target == null:
		_record("walk_target_resolved", false, {"target": "none"})
		return false
	var before = tm.idx
	var start_position: Vector2 = player.global_position
	var route: Array = _find_route(target, radius)
	if route.is_empty():
		_record("walk_route_%s" % target.display_name, false, {"target": target.display_name,
			"reason": "no_route", "start": [start_position.x, start_position.y],
			"target_position": [target.global_position.x, target.global_position.y],
			"clearance": ROUTE_CLEARANCE, "start_escape": ROUTE_START_ESCAPE})
		return false
	var movement_frames := 0
	var blocked_frames := 0
	var movement_trace: Array = []
	var last_destination := start_position
	var blocked_position := start_position
	if not player.is_physics_processing():
		_record("walk_physics_enabled_%s" % target.display_name, false, {
			"input_locked": player.input_locked, "physics_processing": player.is_physics_processing()})
		return false
	var active_action := ""
	for destination in route:
		last_destination = destination
		while player.global_position.distance_to(destination) > WAYPOINT_TOLERANCE and movement_frames < 1600:
			var offset: Vector2 = destination - player.global_position
			var action: String = _direction_action(offset)
			if action != active_action:
				if not active_action.is_empty():
					Input.action_release(active_action)
				Input.action_press(action)
				active_action = action
			var previous: Vector2 = player.global_position
			await physics_frame
			movement_frames += 1
			if player.global_position.distance_to(previous) < 0.01:
				blocked_frames += 1
				blocked_position = player.global_position
			else:
				blocked_frames = 0
			if movement_trace.size() < 12:
				movement_trace.append({"action": action,
					"position": [player.global_position.x, player.global_position.y],
					"velocity": [player.velocity.x, player.velocity.y],
					"walkable": zone.is_point_inside(player.global_position),
					"action_pressed": Input.is_action_pressed(action)})
			if blocked_frames >= 20:
				break
		if not active_action.is_empty():
			Input.action_release(active_action)
			active_action = ""
		if blocked_frames >= 20:
			break
		if player.interaction_distance_to(target) <= radius and _nearest_target_at(player.global_position) == target:
			break
	var final_distance: float = player.interaction_distance_to(target)
	var nearest = player.nearest_interactable()
	var arrived: bool = final_distance <= radius and nearest == target \
		and (not advance_step or tm.idx == before + 1)
	_record("walk_%s" % target.display_name, arrived, {
		"target": target.display_name, "start": [start_position.x, start_position.y],
		"end": [player.global_position.x, player.global_position.y],
		"effective_distance": final_distance, "step_radius": radius,
		"nearest": nearest.display_name if nearest else "none", "movement_frames": movement_frames,
		"blocked_frames": blocked_frames, "tutorial_idx_before": before, "tutorial_idx_after": tm.idx,
		"input_locked": player.input_locked, "physics_processing": player.is_physics_processing(),
		"route_points": route.size(), "last_destination": [last_destination.x, last_destination.y],
		"blocked_position": [blocked_position.x, blocked_position.y],
		"last_destination_walkable": zone.is_point_inside(last_destination),
		"interaction_distances": _interaction_distances(),
		"movement_trace": movement_trace})
	return arrived

func _find_route(target: Node2D, radius: float) -> Array:
	var origin: Vector2 = player.global_position
	var start := Vector2i.ZERO
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var head := 0
	var body_radius: float = player.collision_radius_world()
	var all_targets: Array = get_nodes_in_group("interactable")
	var goal := Vector2i.ZERO
	var found := false
	while head < queue.size() and head < 100000:
		var cell: Vector2i = queue[head]
		head += 1
		var point: Vector2 = origin + Vector2(cell) * ROUTE_GRID
		var effective: float = maxf(0.0, target.interaction_distance_from(point) - body_radius)
		var allow_unbuffered := origin.distance_to(point) <= ROUTE_START_ESCAPE
		if effective <= radius and _nearest_target_at(point, all_targets) == target \
			and _target_is_clearly_nearest(point, target, all_targets) \
			and _route_point_is_safe(point, allow_unbuffered):
			goal = cell
			found = true
			break
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if parents.has(next):
				continue
			var next_point: Vector2 = origin + Vector2(next) * ROUTE_GRID
			var next_unbuffered := origin.distance_to(next_point) <= ROUTE_START_ESCAPE
			var midpoint := point.lerp(next_point, 0.5)
			var midpoint_unbuffered := origin.distance_to(midpoint) <= ROUTE_START_ESCAPE
			if _route_point_is_safe(next_point, next_unbuffered) \
				and _route_point_is_safe(midpoint, midpoint_unbuffered):
				parents[next] = cell
				queue.append(next)
	if not found:
		return []
	var route: Array = []
	var cursor: Vector2i = goal
	while cursor != start:
		route.push_front(origin + Vector2(cursor) * ROUTE_GRID)
		cursor = parents[cursor]
	if route.is_empty():
		route.append(origin)
	return route

func _route_point_is_safe(point: Vector2, allow_start: bool = false) -> bool:
	var body_radius: float = player.collision_radius_world()
	if zone.has_method("is_circle_inside"):
		if not allow_start and not zone.is_circle_inside(point, body_radius):
			return false
	elif not zone.is_point_inside(point):
		return false
	if allow_start:
		return true
	for offset in [
		Vector2(-ROUTE_CLEARANCE, 0), Vector2(ROUTE_CLEARANCE, 0),
		Vector2(0, -ROUTE_CLEARANCE), Vector2(0, ROUTE_CLEARANCE),
		Vector2(-ROUTE_CLEARANCE, -ROUTE_CLEARANCE), Vector2(ROUTE_CLEARANCE, -ROUTE_CLEARANCE),
		Vector2(-ROUTE_CLEARANCE, ROUTE_CLEARANCE), Vector2(ROUTE_CLEARANCE, ROUTE_CLEARANCE)]:
		if not zone.is_point_inside(point + offset):
			return false
	return true

func _nearest_target_at(point: Vector2, candidates: Array = []) -> Node2D:
	var targets: Array = candidates if not candidates.is_empty() else get_nodes_in_group("interactable")
	var best: Node2D = null
	var best_distance: float = player.INTERACT_RANGE
	var body_radius: float = player.collision_radius_world()
	for candidate in targets:
		var node: Node2D = candidate as Node2D
		if node == null:
			continue
		var distance: float = maxf(0.0, node.interaction_distance_from(point) - body_radius)
		if distance <= best_distance and (best == null or distance < best_distance
				or str(node.get_path()) < str(best.get_path())):
			best = node
			best_distance = distance
	return best

func _target_is_clearly_nearest(point: Vector2, target: Node2D, candidates: Array,
		margin: float = ROUTE_NEAREST_MARGIN) -> bool:
	var target_distance := maxf(0.0, target.interaction_distance_from(point) - player.collision_radius_world())
	for candidate in candidates:
		var node := candidate as Node2D
		if node == null or node == target:
			continue
		var other_distance := maxf(0.0, node.interaction_distance_from(point) - player.collision_radius_world())
		if target_distance + margin > other_distance:
			return false
	return true

func _interaction_distances() -> Dictionary:
	var result := {}
	for candidate in get_nodes_in_group("interactable"):
		var node := candidate as Node2D
		if node:
			result[player.display_name_of(node)] = snappedf(player.interaction_distance_to(node), 0.001)
	return result

func _all_interactions_valid() -> bool:
	for item in interactions:
		if not item.get("advanced", false) or not item.get("in_range", false) \
			or not item.get("nearest_matches", false):
			return false
	return true

func _direction_action(offset: Vector2) -> String:
	if absf(offset.x) >= absf(offset.y):
		return "ui_right" if offset.x > 0.0 else "ui_left"
	return "ui_down" if offset.y > 0.0 else "ui_up"

func _press_viewport_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	event.strength = 1.0
	root.push_input(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	root.push_input(event)
	await process_frame

func _wait_until_index_changes(before: int, max_frames: int) -> void:
	var frames := 0
	while tm.active and tm.idx == before and frames < max_frames:
		frames += 1
		await process_frame
		await physics_frame
	if tm.idx == before:
		_record("async_step_advance", false, {"idx": tm.idx, "frames": frames})

func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame

func _capture(label: String) -> void:
	if report_dir.is_empty() or not capture_enabled:
		return
	var viewport_texture: Texture2D = current_scene.get_viewport().get_texture()
	if viewport_texture == null:
		_record("visual_capture_%s" % label, false, {"reason": "no_viewport_texture"})
		return
	var path: String = report_dir.path_join("CH1-02-real-flow-%s.png" % label)
	var err: int = viewport_texture.get_image().save_png(path)
	_record("visual_capture_%s" % label, err == OK, {"path": path, "error": err})

func _on_stage_changed(stage: int, _title: String) -> void:
	stage_events.append(stage)

func _record(name: String, passed: bool, details: Dictionary = {}) -> void:
	checks.append({"name": name, "passed": passed, "details": details})
	if not passed:
		failures.append(name)

func _finish_report() -> void:
	var report := {
		"checks": checks,
		"failures": failures,
		"stage_events": stage_events,
		"interactions": interactions,
		"chapter_1_done": sm.is_chapter_1_done() if sm else false,
		"tutorial_done": sm.is_tutorial_done() if sm else false,
		"active": tm.active if tm else false,
		"scene": current_scene.name if current_scene else "none",
		"save_path": ProjectSettings.globalize_path("user://save.json"),
		"position": [player.global_position.x, player.global_position.y] if is_instance_valid(player) else [],
	}
	if not report_dir.is_empty():
		var file := FileAccess.open(report_dir.path_join("ch1-02-real-flow-report.json"), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "\t"))
	print("CH1_02 real flow report=", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func _has_argument(value: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == value:
			return true
	return false
