extends "res://tools/tests/day1_customers.gd"
func capture_card(label: String) -> void:
	var tracker = load("res://scripts/ui/order_tracking.gd").new()
	add_child(tracker)
	await get_tree().process_frame
	tracker.refresh_saved_state()
	tracker._toggle_tasks()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var rect: Rect2 = tracker._panel.get_global_rect()
	get_viewport().get_texture().get_image().get_region(Rect2i(rect)).save_png("res://output/order_card_compare/" + label + ".png")
	check(tracker._panel.visible, label + " visible")
	tracker.queue_free()
	await get_tree().process_frame
func run() -> void:
	sm = get_node("/root/SaveManager")
	sm.data = sm._defaults()
	sm._active_save_path = "res://output/order_card_compare/state.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	check(sm.accept_first_order().success, "first accept")
	await capture_card("tieshan")
	seed_completed()
	check(sm.ensure_restaurant_customer().success, "arrival")
	check(sm.accept_restaurant_customer(sm.restaurant_customers().front.id).success, "customer accept")
	await capture_card("customer")
	print("RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(failures)
