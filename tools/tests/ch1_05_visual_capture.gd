extends Node

const RESTAURANT_SCENE := preload("res://scenes/restaurant_map_2d.tscn")

var scene: Node2D
var guide: Control
var tm
var sm

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	tm = get_tree().root.get_node("TutorialManager")
	sm = get_tree().root.get_node("SaveManager")
	sm.data = {"tutorial_done": false, "chapter_1_done": false}
	scene = RESTAURANT_SCENE.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().process_frame
	await get_tree().process_frame
	guide = scene.get_node("UIOverlay/TutorialGuide")
	scene.get_node("Player").spawn_ready = true
	tm.start()
	await get_tree().process_frame
	for i in 5:
		guide.dialog._advance()
		guide.dialog._advance()
		await get_tree().process_frame
	while tm.active and tm.idx == 5:
		await get_tree().process_frame
	guide.dialog._advance()
	guide.dialog._advance()
	await get_tree().process_frame
	while tm.active and tm.idx == 7:
		guide.dialog._advance()
		await get_tree().process_frame
	while tm.active and tm.idx != 8:
		await get_tree().process_frame
	var player = scene.get_node("Player")
	var register := scene.get_node("InteractPoints/Register") as Node2D
	player.global_position = _find_register_stand_point(player, register)
	var ui := scene.get_node("UIOverlay")
	var stage3_deadline := Time.get_ticks_msec() + 5000
	while tm.active and tm.idx != 9 and Time.get_ticks_msec() < stage3_deadline:
		await get_tree().process_frame
	var stage3_ready := false
	while tm.active and Time.get_ticks_msec() < stage3_deadline:
		await get_tree().process_frame
		var visible_buttons: Array = []
		for target in ui._buttons:
			var button: Control = ui._buttons[target]
			if is_instance_valid(button) and button.visible:
				visible_buttons.append({"target": target, "button": button})
		stage3_ready = tm.idx == 9 \
			and guide.chapter_stage.text == "阶段 3/7 · 前台接单" \
			and not scene.get_node("Camera").paused \
			and guide.hint_panel.visible \
			and player.nearest_interactable() == register \
			and visible_buttons.size() == 1 \
			and visible_buttons[0]["target"] == register
		if stage3_ready:
			break
	var tracker = scene.get_node("UIOverlay/OrderTracking")
	var output_dir := _argument("--output-dir=")
	if stage3_ready and not output_dir.is_empty():
		var before_path := output_dir.path_join("CH1-05-frontdesk-stage3-before.png")
		get_viewport().get_texture().get_image().save_png(before_path)
		print("CH1_05 visual_capture_stage3=", before_path,
			" stage=", guide.chapter_stage.text)
		var real_e := InputEventAction.new()
		real_e.action = &"interact"
		real_e.pressed = true
		player._unhandled_input(real_e)
		var stage4_deadline := Time.get_ticks_msec() + 4000
		while tm.active and Time.get_ticks_msec() < stage4_deadline:
			await get_tree().process_frame
			if tm.idx == 10 and sm.has_active_order() and tracker.visible \
					and tracker.get("_receipt").visible \
					and guide.chapter_stage.text == "阶段 4/7 · 仓库取料" \
					and not scene.get_node("Camera").paused:
				break
		if tm.idx == 10 and sm.has_active_order() and tracker.visible \
				and tracker.get("_receipt").visible \
				and guide.chapter_stage.text == "阶段 4/7 · 仓库取料" \
				and not scene.get_node("Camera").paused:
			var after_path := output_dir.path_join("CH1-05-frontdesk-stage4-after.png")
			get_viewport().get_texture().get_image().save_png(after_path)
			print("CH1_05 visual_capture_stage4=", after_path,
				" receipt=", tracker.get("_receipt").text,
				" status=", tracker.get("_status").text)
		else:
			push_error("CH1_05 visual capture stage4 precondition failed idx=%d stage=%s order=%s tracker=%s" %
				[tm.idx, guide.chapter_stage.text, str(sm.current_order()), str(tracker.visible)])
	else:
		push_error("CH1_05 visual capture precondition failed idx=%d order=%s tracker=%s" %
			[tm.idx, str(sm.current_order()), str(tracker.visible)])
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0 if stage3_ready and tm.idx == 10 and sm.has_active_order() and tracker.visible else 1)

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func _find_register_stand_point(player: Node, register: Node2D) -> Vector2:
	var zone := scene.get_node("WalkZone")
	var store := scene.get_node("InteractPoints/Store") as Node2D
	var radius: float = player.collision_radius_world()
	for y in range(-240, 241, 10):
		for x in range(-300, 301, 10):
			var candidate := register.global_position + Vector2(x, y)
			if not zone.is_circle_inside(candidate, radius):
				continue
			var distance := maxf(0.0, register.interaction_distance_from(candidate) - radius)
			player.global_position = candidate
			if distance <= 90.0 and player.interaction_distance_to(store) > 180.0:
				return candidate
	return register.global_position + Vector2(0, 180)
