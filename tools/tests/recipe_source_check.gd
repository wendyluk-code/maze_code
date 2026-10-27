extends Node
var failures := 0
var hud: Node
func check(ok: bool, text: String) -> void:
	print(text, ": ", ok)
	if not ok: failures += 1
func key(pressed: bool, echo := false) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.physical_keycode = KEY_E
	e.pressed = pressed
	e.echo = echo
	Input.parse_input_event(e)
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/recipe_unlock_check/" + name + ".png")
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	TutorialManager.active = false
	var scene: Node = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	add_child(scene)
	await get_tree().create_timer(1.0).timeout
	TutorialManager.active = false
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	check(hud != null, "真实餐厅HUD")
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		get_window().size = resolution
		hud.show_recipe_unlock()
		await get_tree().create_timer(0.1).timeout
		check(hud._recipe_unlock.visible and not hud._recipe_entry.visible, "蒙层显示入口隐藏")
		await snap("before_" + str(resolution.x))
		key(true, true)
		await get_tree().process_frame
		check(not hud._recipe_unlock._closing, "重复键不关闭")
		key(false)
		key(true)
		await get_tree().create_timer(0.24).timeout
		check(hud._recipe_unlock._closing and not hud._recipe_entry.visible, "动画期间隐藏入口")
		await snap("moving_" + str(resolution.x))
		key(true, true)
		await get_tree().create_timer(0.4).timeout
		key(false)
		check(not hud._recipe_unlock.visible and hud._recipe_entry.visible, "结束后入口显示")
		await snap("after_" + str(resolution.x))
		TutorialManager._cancel_current_run()
		var guide := get_tree().get_first_node_in_group("tutorial_guide")
		if guide != null: guide.hide()
		hud._player.input_locked = false
		var pos: Vector2 = hud._recipe_entry.get_global_rect().get_center()
		get_viewport().warp_mouse(pos)
		var motion := InputEventMouseMotion.new()
		motion.position = pos
		Input.parse_input_event(motion)
		await get_tree().process_frame
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = pos
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			Input.parse_input_event(click)
			await get_tree().process_frame
		await get_tree().create_timer(0.15).timeout
		await snap("recipe_layout_" + str(resolution.x))
		check(hud._recipe_book.visible and hud._player.input_locked, "打开菜谱锁定输入")

		var catalog = load("res://scripts/cooking/recipe_catalog.gd")
		for id in ["moondew_honey", "cooking_sake", "sour_vine_juice"]:
			var item: Dictionary = catalog.get_ingredient(id)
			var target: Button = hud._recipe_book.ingredient_targets[0]
			hud._recipe_book.show_hint(target, str(item.name) + "\n获取方式：" + str(item.source))
			check(hud._recipe_book.hint_title.text == item.name, "食材名称")
			check(hud._recipe_book.hint_text.text == "获取方式：" + ("支线任务、迷宫探索" if id == "sour_vine_juice" else "支线任务、商店"), "来源文案")
			await snap("source_" + id + "_" + str(resolution.x))
		hud._recipe_book.close()
		check(not hud._player.input_locked, "关闭恢复输入")
		check(hud._recipe_entry.get_canvas_layer_node().layer < guide.get_canvas_layer_node().layer, "入口低于对白蒙层")
		guide.show()
		guide.play_dialog("芽芽", ["订单制作分为领取食材和制作料理，请先去仓库领取食材。"])
		await get_tree().create_timer(0.2).timeout
		await snap("dialog_layer_" + str(resolution.x))
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = hud._recipe_entry.get_global_rect().get_center()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			Input.parse_input_event(click)
			await get_tree().process_frame
		check(not hud._recipe_book.visible, "对白覆盖区域点击不穿透")
		guide.hide_box()
		guide.hide()

	scene.queue_free()
	await get_tree().process_frame
	var next: Node = load("res://scenes/restaurant_map_2d.tscn").instantiate()
	add_child(next)
	await get_tree().create_timer(0.5).timeout
	hud = get_tree().get_first_node_in_group("restaurant_hud")
	check(hud._recipe_entry.visible, "重进餐厅入口恢复")
	print("FAILURES=", failures)
	get_tree().quit(failures)



