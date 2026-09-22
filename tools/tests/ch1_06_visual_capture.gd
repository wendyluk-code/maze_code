extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")
var output_dir := ""
var scene: Node2D
var guide: Control
var tm
var sm

func _ready() -> void:
	output_dir = _argument("--output-dir=")
	call_deferred("capture")

func capture() -> void:
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://ch1_06_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	sm = get_tree().root.get_node("SaveManager")
	tm = get_tree().root.get_node("TutorialManager")
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	sm.save()
	scene = RESTAURANT_SCENE.instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene = scene
	await get_tree().process_frame; await get_tree().process_frame
	DisplayServer.window_set_size(Vector2i(1280, 720))
	guide = scene.get_node("UIOverlay/TutorialGuide")
	tm.start()
	await _advance_to_stage_four()
	var player := scene.get_node("Player")
	var store := scene.get_node("InteractPoints/Store") as Node2D
	player.global_position = Vector2(1400, 630)
	await _wait_until(func(): return tm.idx == 11 and guide.chapter_stage.text == "阶段 4/7 · 仓库取料" and player.nearest_interactable() == store, 5000)
	var real_e := InputEventAction.new(); real_e.action = &"interact"; real_e.pressed = true
	player._unhandled_input(real_e)
	var modal := scene.get_node("UIOverlay/WarehouseModal")
	await _wait_until(func(): return modal.visible, 2000)
	await get_tree().process_frame; await get_tree().process_frame
	var ui := scene.get_node("UIOverlay")
	var visible_buttons_before := _visible_buttons(ui).size()
	var before_path := output_dir.path_join("CH1-06-warehouse-stage4-before.png")
	var before_err := get_viewport().get_texture().get_image().save_png(before_path)
	var meat_slot: SproutItemSlot = modal.get("_meat_slot")
	var salt_slot: SproutItemSlot = modal.get("_salt_slot")
	meat_slot._on_pressed(); salt_slot._on_pressed()
	modal._on_claim_pressed()
	await _wait_until(func(): return tm.idx == 12 and not modal.visible and guide.chapter_stage.text == "阶段 5/7 · 料理制作", 4000)
	var cauldron := scene.get_node("InteractPoints/Cauldron") as Node2D
	player.global_position = _find_quiet_spot(player, cauldron)
	await get_tree().process_frame; await get_tree().process_frame
	var visible_buttons_after := _visible_buttons(ui).size()
	var after_path := output_dir.path_join("CH1-06-warehouse-stage5-after.png")
	var after_err := get_viewport().get_texture().get_image().save_png(after_path)
	var report := {"ticket": "CH1-06", "before": before_path, "after": after_path,
		"before_error": before_err, "after_error": after_err,
		"before_exists": FileAccess.file_exists(before_path), "after_exists": FileAccess.file_exists(after_path),
		"real_flow": tm.current_stage == 5 and guide.chapter_stage.text == "阶段 5/7 · 料理制作", "tutorial_idx_after": tm.idx, "before_modal_visible": true,
		"before_visible_world_buttons": visible_buttons_before, "after_visible_world_buttons": visible_buttons_after, "inventory_after": sm.inventory_snapshot(), "order_after": sm.current_order()}
	var report_path := _argument("--report=")
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE); f.store_string(JSON.stringify(report, "\t")); f.close()
	print("CH1_06 visual report=", JSON.stringify(report))
	get_tree().quit(0 if before_err == OK and after_err == OK and report.real_flow and visible_buttons_before == 0 and visible_buttons_after == 0 else 1)

func _advance_to_stage_four() -> void:
	await _wait_until(func(): return tm.active, 3000)
	for i in 5:
		await _wait_until(func(): return guide.dialog.visible, 2000)
		guide.dialog._advance(); guide.dialog._advance(); await get_tree().process_frame
	await _wait_until(func(): return tm.idx == 6 and guide.dialog.visible, 4000)
	guide.dialog._advance(); guide.dialog._advance(); await get_tree().process_frame
	await _wait_until(func(): return tm.idx == 7 and guide.dialog.visible, 3000)
	while tm.active and tm.idx == 7:
		guide.dialog._advance(); await get_tree().process_frame
	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register") as Node2D
	player.global_position = _find_stand(register)
	await _wait_until(func(): return tm.idx == 9, 5000)
	var e := InputEventAction.new(); e.action = &"interact"; e.pressed = true
	player._unhandled_input(e)
	await _wait_until(func(): return tm.idx == 10, 3000)
	player.global_position = Vector2(1400, 630)
	await _wait_until(func(): return tm.idx == 11 and guide.chapter_stage.text == "阶段 4/7 · 仓库取料", 5000)

func _find_stand(target: Node2D) -> Vector2:
	var player := scene.get_node("Player")
	var zone := scene.get_node("WalkZone")
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := target.global_position + Vector2(x, y)
			if zone.has_method("is_circle_inside") and not zone.is_circle_inside(candidate, player.collision_radius_world()):
				continue
			player.global_position = candidate
			if player.nearest_interactable() == target:
				return candidate
	return target.global_position + Vector2(0, 100)

func _find_quiet_spot(player: Node2D, cauldron: Node2D) -> Vector2:
	var zone := scene.get_node("WalkZone")
	for y in range(180, 900, 20):
		for x in range(180, 1280, 20):
			var candidate := Vector2(x, y)
			if zone.has_method("is_circle_inside") and not zone.is_circle_inside(candidate, player.collision_radius_world()):
				continue
			player.global_position = candidate
			if player.nearest_interactable() == null and player.interaction_distance_to(cauldron) > 150.0:
				return candidate
	return Vector2(720, 720)

func _visible_buttons(ui: Node) -> Array:
	var result: Array = []
	for target in ui._buttons:
		var button: Control = ui._buttons[target]
		if is_instance_valid(button) and button.visible:
			result.append(button)
	return result

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()): return true
		await get_tree().process_frame
	return false

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.substr(prefix.length())
	return ""
