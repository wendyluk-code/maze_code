extends Node

func _ready() -> void:
	var root := OS.get_environment("MAZE_START01_ROOT").replace("\\","/").to_lower()
	if root.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(root):
		get_tree().quit(2)
		return
	get_window().title = "Save name IME isolated test"
	var created := SaveManager.create_new_game()
	var screen = load("res://scenes/start_screen.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen.save_modal.open_slots(created.id)
	screen.save_modal._begin_edit("rename")
	await get_tree().process_frame
	var modal = screen.save_modal
	var checks: Array = []
	checks.append({"label":"打开时进入编辑状态","passed":modal._name_edit.is_editing()})
	modal._name_edit.text = ""
	modal._confirm_edit()
	await get_tree().process_frame
	checks.append({"label":"空名称校验失败后恢复编辑焦点","passed":modal._name_edit.has_focus() and modal._name_edit.is_editing()})
	for character in "中文存档测试":
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	checks.append({"label":"中文字符事件进入输入框","passed":modal._name_edit.text=="中文存档测试"})
	var destination := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): destination=arg.trim_prefix("--output-dir=")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(destination+"/chinese_name.png")
	modal._confirm_edit()
	modal.open_slots(created.id)
	checks.append({"label":"重新读取存档列表保留中文名称","passed":modal._slots.any(func(slot): return slot.id==created.id and slot.name=="中文存档测试")})
	var report := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	var failures := checks.filter(func(row): return not row.passed).size()
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"limitation":"Unicode事件测试，未验证Windows输入法候选窗口"},"\t"))
	screen.queue_free()
	await get_tree().process_frame
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	get_tree().quit(1 if failures else 0)
