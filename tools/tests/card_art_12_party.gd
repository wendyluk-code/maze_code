extends SceneTree
var overlay: Control
var continued := 0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	print("PARTY_USER_DIR=" + OS.get_user_data_dir())
	root.size = Vector2i(1152,648) if OS.get_cmdline_user_args().has("small") else Vector2i(1280,720)
	overlay = preload("res://scripts/ui/party_cards_overlay.gd").new()
	root.add_child(overlay)
	overlay.continue_requested.connect(func(): continued += 1)
	await process_frame
	await key(true)
	overlay.present()
	await create_timer(1.4).timeout
	check(continued == 0, "早按E不穿透")
	await key(true)
	check(continued == 0, "长按E不继续")
	for index in 2:
		var card: SproutCard = overlay.cards[index].get_node("TemplateCard")
		var expected := "yaya" if index == 0 else "tieshan"
		check(card._data.id == expected, "真实角色数据")
		check(card._material_art.texture.resource_path == card._data.illustration_path, "真实新插画")
		check(card._satiety_slot.text == ("6" if index == 0 else "8"), "饱腹6/8")
		check(card._material_stat_attack.text == ("2" if index == 0 else "1"), "攻击2/1")
		check(card._material_stat_health.text == ("5" if index == 0 else "7"), "生命5/7")
		check(card._material_effect.text == card._data.effect, "原表技能")
		if index == 0: check(card._mana_slot.text == "3", "芽芽魔力3")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://output/card_art_12/party")
	root.get_texture().get_image().save_png("res://output/card_art_12/party/%d_actual.png" % root.size.x)
	await key(false)
	await key(true)
	check(continued == 1, "松键后新E继续")
	await key(false)
	overlay.present()
	await create_timer(1.4).timeout
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await process_frame
	check(continued == 2, "鼠标继续")
	overlay.present()
	await create_timer(0.2).timeout
	overlay.cancel()
	await create_timer(1.3).timeout
	check(not overlay.visible and overlay._tween == null and not overlay._ready_for_input, "取消清理旧动画及输入")
	var file := FileAccess.open("res://output/card_art_12/party/%d_report.json" % root.size.x, FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"user_dir":OS.get_user_data_dir()},"\t"))
	quit(0 if failures.is_empty() else 1)
