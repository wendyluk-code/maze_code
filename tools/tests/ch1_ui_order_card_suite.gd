extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const SAVE_PATH := "user://save.json"

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var scene: Node2D
var guide: Control
var tm
var sm
var output_dir := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	output_dir = _argument("--output-dir=")
	if not _verify_isolation():
		_finish()
		return
	tm = get_tree().root.get_node("TutorialManager")
	sm = get_tree().root.get_node("SaveManager")
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	await _start_scene()
	tm.start()
	guide = scene.get_node("UIOverlay/TutorialGuide")
	_check(guide.dialog.visible and guide.dim.visible, "mask_is_visible_during_dialog", {})
	_check(scene.get_node_or_null("UIOverlay/TutorialGuide/TargetMarker") == null,
		"yellow_target_marker_is_removed", {})
	await _advance_opening_to_stage_three()
	await _wait_until(Callable(self, "_is_stage_three_ready"), 3000)
	_check(not guide.dialog.visible and not guide.dim.visible,
		"mask_is_hidden_during_player_movement_and_interaction", {"idx": tm.idx})
	_check(guide.hint_panel.visible and guide.chapter_stage.text == "阶段 3/7 · 前台接单",
		"stage_hint_is_under_chapter_heading_during_play", {"stage": guide.chapter_stage.text})

	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register") as Node2D
	player.global_position = _find_stand_point(player, register)
	await _wait_until(func() -> bool: return tm.idx == 9, 4000)
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	player._unhandled_input(interact)
	await _wait_until(func() -> bool: return tm.idx == 10 and sm.has_active_order(), 3000)
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	_check(tracker.visible and tracker.get("_order_status").text == "0/1"
		and tracker.get("_cook_status").text == "0/1",
		"accepted_order_has_single_uncompleted_card", {
			"delivery": tracker.get("_order_status").text,
			"cooking": tracker.get("_cook_status").text,
		})
	_check(not guide.dim.visible and not guide.toast.visible,
		"no_duplicate_acceptance_toast_or_gameplay_mask", {})

	var store := scene.get_node("InteractPoints/Store") as Node2D
	player.global_position = Vector2(1400, 630)
	await _wait_until(func() -> bool: return tm.idx == 11, 5000)
	player._unhandled_input(interact)
	var modal := scene.get_node("UIOverlay/WarehouseModal")
	await _wait_until(func() -> bool: return modal.visible, 2000)
	_check(modal.visible and modal.get("_overlay").visible and not guide.dim.visible,
		"warehouse_keeps_its_own_modal_overlay_without_tutorial_mask", {})
	modal._on_slot_selected("rockmane_meat")
	modal._on_slot_selected("rock_salt")
	modal._on_claim_pressed()
	await get_tree().process_frame
	_check(tracker.get("_meat_status").text == "1/1"
		and tracker.get("_salt_status").text == "1/1"
		and tracker.get("_cook_status").text == "0/1"
		and tracker.get("_order_status").text == "0/1",
		"claimed_materials_update_only_their_counters", {
			"meat": tracker.get("_meat_status").text,
			"salt": tracker.get("_salt_status").text,
			"cooking": tracker.get("_cook_status").text,
			"delivery": tracker.get("_order_status").text,
		})

	for viewport_size in [Vector2i(1152, 648), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(viewport_size)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
		var actual_size := Vector2i(get_viewport().get_visible_rect().size)
		_check(actual_size == viewport_size, "viewport_size_%dx%d" % [viewport_size.x, viewport_size.y], {
			"actual": [actual_size.x, actual_size.y],
		})
		_check_layout(tracker, viewport_size)
		_capture(viewport_size)

	# Keep the live card through a dialogue and prove the mask/dialogue layout is clean.
	for expected_idx in [13, 14, 15, 16]:
		if tm.idx == expected_idx - 1:
			tm._complete_step(tm._run_token)
			await get_tree().process_frame
	await _wait_until(func() -> bool: return tm.idx == 16 and guide.dialog.visible, 3000)
	var dialog_rect: Rect2 = guide.dialog.get_global_rect()
	var card_rect: Rect2 = tracker.get("_panel").get_global_rect()
	var dialog_card_overlap: Rect2 = dialog_rect.intersection(card_rect)
	_check(guide.dim.visible and dialog_card_overlap.size == Vector2.ZERO,
		"dialog_mask_and_order_card_do_not_overlap", {
			"dialog": [dialog_rect.position.x, dialog_rect.position.y, dialog_rect.size.x, dialog_rect.size.y],
			"card": [card_rect.position.x, card_rect.position.y, card_rect.size.x, card_rect.size.y],
			"overlap": [dialog_card_overlap.position.x, dialog_card_overlap.position.y,
				dialog_card_overlap.size.x, dialog_card_overlap.size.y],
		})
	# Skip while a dialogue is open must synchronously clear its mask and temporary card.
	_check(not modal.visible and guide.dim.visible,
		"dialog_open_after_warehouse_claim", {"idx": tm.idx})
	tm.skip_all()
	await get_tree().process_frame
	_check(not guide.visible and not guide.dim.visible and not tracker.visible,
		"skip_cleans_tutorial_mask_and_order_card", {})
	_finish()

func _advance_opening_to_stage_three() -> void:
	for i in 5:
		await _wait_until(func() -> bool: return tm.idx == i and guide.dialog.visible, 3000)
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	# Wait through the guest camera move; the dim layer must stay absent.
	await _wait_until(func() -> bool: return tm.idx == 5, 1000)
	await get_tree().process_frame
	_check(not guide.dim.visible and scene.get_node("Camera").paused,
		"camera_cutscene_does_not_show_tutorial_mask", {"camera_paused": scene.get_node("Camera").paused})
	await _wait_until(func() -> bool: return tm.idx == 6 and guide.dialog.visible, 5000)
	guide.dialog._advance()
	guide.dialog._advance()
	await get_tree().process_frame
	await _wait_until(func() -> bool: return tm.idx == 7 and guide.dialog.visible, 3000)
	var attempts := 0
	while tm.idx == 7 and attempts < 8:
		attempts += 1
		guide.dialog._advance()
		await get_tree().process_frame
		guide.dialog._advance()
		await get_tree().process_frame
	await _wait_until(func() -> bool: return tm.idx == 8, 3000)
	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register") as Node2D
	player.global_position = _find_stand_point(player, register)
	await _wait_until(func() -> bool: return tm.idx == 9, 3000)

func _is_stage_three_ready() -> bool:
	return tm.idx == 9 and guide.chapter_stage.text == "阶段 3/7 · 前台接单" \
		and not scene.get_node("Camera").paused

func _start_scene() -> void:
	scene = RESTAURANT_SCENE.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	scene.get_node("Player").spawn_ready = true

func _find_stand_point(player: Node, target: Node2D) -> Vector2:
	var zone := scene.get_node("WalkZone")
	var radius: float = player.collision_radius_world()
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if not zone.is_circle_inside(candidate, radius):
				continue
			player.global_position = candidate
			if player.nearest_interactable() == target:
				return candidate
	return target.global_position + Vector2(0, 100)

func _check_layout(tracker: Control, expected_size: Vector2i) -> void:
	var nodes: Array[Control] = [guide.chapter_title, guide.chapter_stage,
		guide.hint_panel, guide.skip_button, tracker.get("_panel")]
	var rects: Array[Rect2] = []
	for node in nodes:
		var rect := node.get_global_rect()
		rects.append(rect)
		_check(rect.position.x >= -1.0 and rect.position.y >= -1.0
			and rect.end.x <= expected_size.x + 1.0 and rect.end.y <= expected_size.y + 1.0,
			"layout_inside_%s_%dx%d" % [node.name, expected_size.x, expected_size.y], {
				"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			})
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var overlap := rects[i].intersection(rects[j])
			_check(overlap.size.x <= 1.0 or overlap.size.y <= 1.0,
				"no_ui_overlap_%s_%s_%dx%d" % [nodes[i].name, nodes[j].name, expected_size.x, expected_size.y], {
				"overlap": [overlap.position.x, overlap.position.y, overlap.size.x, overlap.size.y],
				})
	_check(not guide.dialog.visible, "dialog_is_closed_during_action_hud_capture_%dx%d" % [expected_size.x, expected_size.y], {})
	var player := scene.get_node("Player") as Node2D
	var player_screen := get_viewport().get_canvas_transform() * player.global_position
	var player_rect := Rect2(player_screen + Vector2(-55.0, -155.0), Vector2(110.0, 180.0))
	_check(rects[4].intersection(player_rect).size == Vector2.ZERO,
		"order_card_avoids_player_%dx%d" % [expected_size.x, expected_size.y], {
			"side": tracker.get_layout_side(),
			"player_rect": [player_rect.position.x, player_rect.position.y, player_rect.size.x, player_rect.size.y],
		})
	_check(rects[2].intersection(player_rect).size == Vector2.ZERO,
		"stage_hint_avoids_player_%dx%d" % [expected_size.x, expected_size.y], {
			"player_rect": [player_rect.position.x, player_rect.position.y, player_rect.size.x, player_rect.size.y],
		})
	var step: Dictionary = tm.steps[tm.idx]
	var target: Node2D = tm.resolve_target(step.get("target"))
	if is_instance_valid(target):
		var target_screen := get_viewport().get_canvas_transform() * target.global_position
		var target_rect := Rect2(target_screen + Vector2(-130.0, -165.0), Vector2(260.0, 210.0))
		_check(rects[4].intersection(target_rect).size == Vector2.ZERO,
			"order_card_avoids_interaction_target_%dx%d" % [expected_size.x, expected_size.y], {
				"target": target.name,
				"target_rect": [target_rect.position.x, target_rect.position.y, target_rect.size.x, target_rect.size.y],
			})
		_check(rects[2].intersection(target_rect).size == Vector2.ZERO,
			"stage_hint_avoids_interaction_target_%dx%d" % [expected_size.x, expected_size.y], {
				"target": target.name,
			})
	var ui := scene.get_node("UIOverlay")
	for button in ui.get("_buttons").values():
		if is_instance_valid(button) and button.visible:
			var button_rect: Rect2 = button.get_global_rect()
			_check(rects[3].intersection(button_rect).size == Vector2.ZERO,
				"skip_button_avoids_interaction_prompt_%dx%d" % [expected_size.x, expected_size.y], {
					"button_rect": [button_rect.position.x, button_rect.position.y, button_rect.size.x, button_rect.size.y],
				})
			_check(rects[2].intersection(button_rect).size == Vector2.ZERO,
				"stage_hint_avoids_interaction_prompt_%dx%d" % [expected_size.x, expected_size.y], {
					"button_rect": [button_rect.position.x, button_rect.position.y, button_rect.size.x, button_rect.size.y],
				})

func _capture(viewport_size: Vector2i) -> void:
	if output_dir.is_empty():
		_check(false, "screenshot_output_directory_was_provided", {})
		return
	var filename := "CH1-UI-01-order-card-%dx%d.png" % [viewport_size.x, viewport_size.y]
	var path := output_dir.path_join(filename)
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path) if image != null else ERR_CANT_CREATE
	_check(err == OK and image.get_width() == viewport_size.x and image.get_height() == viewport_size.y,
		"visible_screenshot_%dx%d" % [viewport_size.x, viewport_size.y], {
			"path": path,
			"size": [image.get_width(), image.get_height()] if image else [],
			"error": err,
		})

func _verify_isolation() -> bool:
	var root := _normalize_path(_argument("--isolation-root="))
	var actual := _normalize_path(ProjectSettings.globalize_path("user://"))
	var ok := OS.get_environment("MAZE_CH1_UI_ISOLATED") == "1" \
		and not root.is_empty() and actual.begins_with(root + "/")
	_check(ok, "isolated_user_data_directory", {"actual": actual, "root": root})
	return ok

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return false

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func _normalize_path(value: String) -> String:
	return value.replace("\\", "/").trim_suffix("/").to_lower()

func _check(passed: bool, name: String, details: Dictionary) -> void:
	checks.append({"name": name, "passed": passed, "details": details})
	if not passed:
		failures.append(name)
		push_error("CH1_UI_01 FAILED: %s %s" % [name, JSON.stringify(details)])

func _finish() -> void:
	var report := {
		"ticket": "CH1-UI-01",
		"checks": checks,
		"failures": failures,
		"isolation_root": _argument("--isolation-root="),
		"user_data_dir": ProjectSettings.globalize_path("user://"),
		"save_exists": FileAccess.file_exists(SAVE_PATH),
	}
	var report_path := _argument("--report=")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "\t"))
	print("CH1_UI_01 report=", JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
