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
	player.global_position = register.global_position
	while tm.active and tm.idx == 8:
		await get_tree().process_frame
	player.interacted.emit(register)
	await get_tree().process_frame
	var tracker = scene.get_node("UIOverlay/OrderTracking")
	var output := _argument("--output=")
	if tm.idx == 10 and sm.has_active_order() and tracker.visible and not output.is_empty():
		# 等待阶段标题、回执和订单面板完成一次可见渲染，再保存真实窗口视口。
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(output)
		print("CH1_05 visual_capture=", output,
			" receipt=", tracker.get("_receipt").text,
			" status=", tracker.get("_status").text)
	else:
		push_error("CH1_05 visual capture precondition failed idx=%d order=%s tracker=%s" %
			[tm.idx, str(sm.current_order()), str(tracker.visible)])
	await get_tree().create_timer(20.0).timeout
	get_tree().quit(0 if tm.idx == 10 and sm.has_active_order() and tracker.visible else 1)

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""
