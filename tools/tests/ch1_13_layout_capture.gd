extends Node

const GUIDE_SCENE := preload("res://scenes/ui/tutorial_guide.tscn")

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var requested_size := _argument("--capture-size=")
	if not requested_size.is_empty():
		var parts := requested_size.split("x")
		if parts.size() == 2:
			get_viewport().size = Vector2i(int(parts[0]), int(parts[1]))
	var guide := GUIDE_SCENE.instantiate()
	add_child(guide)
	await get_tree().process_frame
	guide.visible = true
	guide.chapter_title.visible = true
	guide.chapter_stage.visible = true
	guide.hint_panel.visible = true
	guide.hint_label.text = "靠近前台后，按 E 接下订单，并确认提示完整显示"
	guide.show_toast("订单已接下")
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "res://tools/tests/artifacts/ch1_13/layout-%sx%s.txt" % [get_viewport().size.x, get_viewport().size.y]
	var report := FileAccess.open(path, FileAccess.WRITE)
	report.store_string("viewport=%s\nhint=%s\ntoast=%s\ntitle=%s\nstage=%s\n" % [get_viewport().size, guide.hint_panel.get_global_rect(), guide.toast.get_global_rect(), guide.chapter_title.get_global_rect(), guide.chapter_stage.get_global_rect()])
	report.close()
	print("CH1_13 layout=", path,
		" hint=", guide.hint_panel.get_global_rect(),
		" toast=", guide.toast.get_global_rect(),
		" title=", guide.chapter_title.get_global_rect(),
		" stage=", guide.chapter_stage.get_global_rect())
	get_tree().quit(0)

func _argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""
