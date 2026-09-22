extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")
var output_dir := ""
var scene: Node2D
var guide: Control
var sm

func _ready() -> void:
	output_dir = _argument("--output-dir=")
	call_deferred("capture")

func capture() -> void:
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://ch1_06_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	sm = get_tree().root.get_node("SaveManager")
	sm.data = {"tutorial_done": true, "chapter_1_done": true,
		"current_order": {"id": "chapter_1_first_order", "item_id": "salt_grilled_rockmane", "item_name": "盐烤岩鬃肉", "quantity": 1, "status": "in_progress"},
		"inventory": {"rockmane_meat": 0, "rock_salt": 0},
		"first_order_progress": {"ingredients_claimed": false, "next_step": "prepare_ingredients"}}
	sm.save()
	scene = RESTAURANT_SCENE.instantiate()
	get_tree().root.add_child(scene); get_tree().current_scene = scene
	await get_tree().process_frame; await get_tree().process_frame
	DisplayServer.window_set_size(Vector2i(1280, 720))
	guide = scene.get_node("UIOverlay/TutorialGuide")
	guide.prepare_for_start(); guide.set_chapter_stage(4, "仓库取料")
	guide.setup({"stage": 4, "type": "interact", "target": "仓库", "hint": "靠近仓库，按 E 打开仓库并领取食材"})
	var player := scene.get_node("Player")
	player.global_position = Vector2(1400, 630)
	var tracker := scene.get_node("UIOverlay/OrderTracking")
	tracker.refresh_saved_state()
	var modal := scene.get_node("UIOverlay/WarehouseModal")
	modal.open_for_order()
	await get_tree().process_frame; await get_tree().process_frame
	var before_path := output_dir.path_join("CH1-06-warehouse-stage4-before.png")
	var before_err := get_viewport().get_texture().get_image().save_png(before_path)
	modal._on_slot_selected("rockmane_meat"); modal._on_slot_selected("rock_salt"); modal._on_claim_pressed()
	var claim_result: Dictionary = sm.claim_first_order_ingredients()
	await get_tree().process_frame
	guide.set_chapter_stage(5, "料理制作")
	guide.show_toast("获得：岩鬃肉 ×1、岩盐 ×1")
	tracker.refresh_saved_state()
	await get_tree().process_frame; await get_tree().process_frame
	var after_path := output_dir.path_join("CH1-06-warehouse-stage5-after.png")
	var after_err := get_viewport().get_texture().get_image().save_png(after_path)
	var report := {"ticket": "CH1-06", "before": before_path, "after": after_path,
		"before_error": before_err, "after_error": after_err,
		"before_exists": FileAccess.file_exists(before_path), "after_exists": FileAccess.file_exists(after_path),
		"claim_result": claim_result, "stage_after": guide.chapter_stage.text,
		"inventory_after": sm.inventory_snapshot()}
	var report_path := _argument("--report=")
	if not report_path.is_empty():
		var f := FileAccess.open(report_path, FileAccess.WRITE); f.store_string(JSON.stringify(report, "\t")); f.close()
	print("CH1_06 visual report=", JSON.stringify(report))
	get_tree().quit(0 if before_err == OK and after_err == OK else 1)

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.substr(prefix.length())
	return ""
