extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const SAVE_PATH := "user://save.json"
var checks: Array = []
var failures := 0
var scene: Node2D
var guide: Control
var tm
var sm

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	if not _verify_isolation():
		_write_report()
		get_tree().quit(2)
		return
	tm = get_tree().root.get_node("TutorialManager")
	sm = get_tree().root.get_node("SaveManager")
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	sm.load_data()
	_check(sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0,
		"legacy_save_migrates_empty_inventory", {"inventory": sm.inventory_snapshot()})
	_check(not sm.claim_first_order_ingredients().get("success", false),
		"claim_without_canonical_order_rejected", {})
	sm.data[sm.CURRENT_ORDER_KEY] = {"id": "other_order", "item_id": "other_item", "item_name": "其他料理", "quantity": 1, "status": "in_progress"}
	var conflict_claim: Dictionary = sm.claim_first_order_ingredients()
	_check(not bool(conflict_claim.get("success", true)) and str(conflict_claim.get("reason", "")) == "no_canonical_order",
		"conflicting_order_rejected", {"result": conflict_claim})
	# 隔离存档写入失败：材料与领取标记必须完整回滚。
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	var accepted: Dictionary = sm.accept_first_order()
	var isolated_save_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(isolated_save_path)
	DirAccess.make_dir_absolute(isolated_save_path)
	var failed_claim: Dictionary = sm.claim_first_order_ingredients()
	_check(not bool(failed_claim.get("success", true)) and str(failed_claim.get("reason", "")) == "save_failed"
		and sm.inventory_quantity("rockmane_meat") == 0 and not bool(sm.first_order_progress().get("ingredients_claimed", false)),
		"save_failure_rolls_back_claim", {"result": failed_claim, "inventory": sm.inventory_snapshot()})
	DirAccess.remove_absolute(isolated_save_path)
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	sm.load_data()
	var restored_accept: Dictionary = sm.accept_first_order()

	await _start_scene()
	await _reach_stage_four()
	var player := scene.get_node("Player")
	var store := scene.get_node("InteractPoints/Store") as Node2D
	var modal := scene.get_node("UIOverlay/WarehouseModal")
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	var before_idx := int(tm.idx)
	var before_order: Dictionary = sm.current_order()
	player.interacted.emit(scene.get_node("InteractPoints/Fridge"))
	await get_tree().process_frame
	_check(tm.idx == before_idx and sm.current_order() == before_order and not modal.visible,
		"wrong_target_does_not_open_warehouse", {"idx": tm.idx})
	player.global_position = Vector2(-10000, -10000)
	var out_of_range_e := InputEventAction.new(); out_of_range_e.action = &"interact"; out_of_range_e.pressed = true
	player._unhandled_input(out_of_range_e)
	await get_tree().process_frame
	_check(not modal.visible and tm.idx == before_idx and sm.inventory_snapshot() == {"rockmane_meat": 0, "rock_salt": 0},
		"out_of_range_e_does_not_open_warehouse", {})

	# 真实 E：先确认唯一最近目标为仓库，再由玩家入口发出 interact。
	player.global_position = Vector2(1400, 630)
	await _wait_until(func(): return player.nearest_interactable() == store, 3000)
	_check(player.nearest_interactable() == store, "store_is_nearest_target", {})
	var real_e := InputEventAction.new()
	real_e.action = &"interact"
	real_e.pressed = true
	player._unhandled_input(real_e)
	await get_tree().process_frame
	_check(modal.visible and player.input_locked and tm.idx == before_idx,
		"real_e_opens_modal_and_locks_player", {"visible": modal.visible, "locked": player.input_locked})
	var locked_position: Vector2 = player.global_position
	var world_buttons_before := _visible_buttons(scene.get_node("UIOverlay"))
	var blocked_e := InputEventAction.new(); blocked_e.action = &"interact"; blocked_e.pressed = true
	player._unhandled_input(blocked_e)
	_check(modal.visible and player.input_locked and not player.is_physics_processing()
		and player.global_position == locked_position and world_buttons_before.is_empty(),
		"modal_blocks_world_input_and_hides_e_button", {"buttons": world_buttons_before.size()})

	modal._on_claim_pressed()
	_check(sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0,
		"missing_selection_cannot_claim", {})
	modal._on_slot_selected("rockmane_meat")
	modal._on_slot_selected("rockmane_meat")
	_check(modal.get("_claim_button").disabled and str(modal.get("_selection_label").text).contains("0 / 2"),
		"reclick_material_cancels_selection", {"selection": modal.get("_selection_label").text})
	modal._on_cancel_pressed()
	await get_tree().process_frame
	_check(not modal.visible and not player.input_locked and tm.idx == before_idx
		and sm.inventory_quantity("rockmane_meat") == 0 and sm.inventory_quantity("rock_salt") == 0,
		"cancel_closes_without_side_effects", {"idx": tm.idx})
	player._unhandled_input(real_e)
	await _wait_until(func(): return modal.visible, 2000)
	modal._on_slot_selected("rockmane_meat")
	modal._on_slot_selected("rock_salt")
	_check(not modal.get("_claim_button").disabled, "both_materials_selected_enables_claim", {})
	modal._on_claim_pressed()
	await get_tree().process_frame
	_check(sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1,
		"successful_claim_writes_exact_inventory", {"inventory": sm.inventory_snapshot()})
	_check(tm.idx == before_idx + 1 and not modal.visible and not player.input_locked,
		"successful_claim_advances_tutorial_and_unlocks", {"idx": tm.idx})
	_check(str(tracker.get("_status").text).contains("下一步：制作料理")
		and str(tracker.get("_inventory").text).contains("岩鬃肉 ×1")
		and str(tracker.get("_inventory").text).contains("岩盐 ×1"),
		"hud_shows_cooking_next_step_and_inventory", {"status": tracker.get("_status").text, "inventory": tracker.get("_inventory").text})

	var duplicate: Dictionary = sm.claim_first_order_ingredients()
	_check(bool(duplicate.get("success", false)) and not bool(duplicate.get("created", true))
		and sm.inventory_quantity("rockmane_meat") == 1 and sm.inventory_quantity("rock_salt") == 1,
		"duplicate_claim_is_idempotent", {"result": duplicate})
	var saved_inventory: Dictionary = sm.inventory_snapshot()
	var saved_order: Dictionary = sm.current_order()
	sm.save()
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	sm.load_data()
	var restored_order: Dictionary = sm.current_order()
	var order_restored := str(restored_order.get("id", "")) == str(saved_order.get("id", "")) \
		and str(restored_order.get("item_id", "")) == str(saved_order.get("item_id", "")) \
		and int(restored_order.get("quantity", 0)) == int(saved_order.get("quantity", 0)) \
		and str(restored_order.get("status", "")) == str(saved_order.get("status", ""))
	_check(sm.inventory_snapshot() == saved_inventory and order_restored,
		"reload_restores_inventory_and_order", {"inventory": sm.inventory_snapshot(), "saved_inventory": saved_inventory, "order": sm.current_order(), "saved_order": saved_order})

	var report := {"ticket": "CH1-06", "checks": checks, "failures": failures,
		"isolation_root": _argument("--isolation-root="), "isolated_save": _save_metadata()}
	_write_report(report)
	print("CH1_06 warehouse report=", JSON.stringify(report))
	get_tree().quit(0 if failures == 0 else 1)

func _reach_stage_four() -> void:
	tm.start()
	await get_tree().process_frame
	for i in 5:
		guide.dialog._advance(); guide.dialog._advance(); await get_tree().process_frame
	while tm.active and tm.idx == 5:
		await get_tree().process_frame
	guide.dialog._advance(); guide.dialog._advance(); await get_tree().process_frame
	while tm.active and tm.idx == 7:
		guide.dialog._advance(); await get_tree().process_frame
	var player := scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register") as Node2D
	player.global_position = _find_stand(register)
	await _wait_until(func(): return tm.idx == 9, 5000)
	await get_tree().process_frame
	var e := InputEventAction.new(); e.action = &"interact"; e.pressed = true
	player._unhandled_input(e)
	await _wait_until(func(): return tm.idx == 10, 3000)
	var store := scene.get_node("InteractPoints/Store") as Node2D
	player.global_position = Vector2(1400, 630)
	await _wait_until(func(): return tm.idx == 11 and guide.chapter_stage.text == "阶段 4/7 · 仓库取料", 5000)
	_check(tm.idx == 11 and guide.chapter_stage.text == "阶段 4/7 · 仓库取料", "stage_four_interact_ready", {"idx": tm.idx, "stage": guide.chapter_stage.text, "store": store.name})

func _start_scene() -> void:
	scene = RESTAURANT_SCENE.instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene = scene
	await get_tree().process_frame; await get_tree().process_frame
	guide = scene.get_node("UIOverlay/TutorialGuide")
	scene.get_node("Player").spawn_ready = true

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()): return true
		await get_tree().process_frame
	return false

func _visible_buttons(ui: Node) -> Array:
	var result: Array = []
	for target in ui._buttons:
		var button: Control = ui._buttons[target]
		if is_instance_valid(button) and button.visible:
			result.append(button)
	return result

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

func _verify_isolation() -> bool:
	var root := _normalize_path(_argument("--isolation-root="))
	var actual := _normalize_path(ProjectSettings.globalize_path("user://"))
	var ok := OS.get_environment("MAZE_CH1_06_ISOLATED") == "1" and not root.is_empty() and actual.begins_with(root + "/")
	_check(ok, "isolated_user_data_directory", {"actual": actual, "root": root})
	return ok

func _check(ok: bool, name: String, details: Dictionary) -> void:
	checks.append({"name": name, "passed": ok, "details": details})
	if not ok: failures += 1

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.substr(prefix.length())
	return ""

func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/").to_lower()

func _save_metadata() -> Dictionary:
	var path := ProjectSettings.globalize_path(SAVE_PATH)
	if not FileAccess.file_exists(SAVE_PATH): return {"exists": false}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	return {"exists": true, "length": file.get_length(), "sha256": "redacted-in-report"}

func _write_report(report: Dictionary = {}) -> void:
	var path := _argument("--report=")
	if path.is_empty(): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t")); file.close()
