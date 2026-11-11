extends "res://tools/tests/restaurant_rest05b.gd"
## 只在预览场景替换显示，不修改生产营业牌或共用确认组件。
class PauseIcon extends Button:
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus"]:
			add_theme_stylebox_override(state,StyleBoxEmpty.new())
	func _draw() -> void:
		for x in [11,20]: draw_rect(Rect2(x,10,4,14),Color("607e43"))

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_fresh()
		_open({A:3})
		var hud = await _open_restaurant()
		await get_tree().create_timer(0.6).timeout
		var sign = hud.find_child("RestaurantDaySign",true,false)
		sign.set_process(false)
		sign.end_button.hide()
		var icon := PauseIcon.new()
		icon.position = sign.get_node("OpenMenu").position
		icon.size = sign.get_node("OpenMenu").size
		sign.add_child(icon)
		icon.pressed.connect(sign._request_end)
		await _shot("pause_icon_preview")
		await _click(icon)
		var modal = sign.end_confirmation
		modal.question.text = "确定结束今日营业？"
		modal.confirm_button.get_parent().alignment = BoxContainer.ALIGNMENT_CENTER
		await get_tree().process_frame
		await get_tree().process_frame
		_check(modal.visible and modal.question.text=="确定结束今日营业？","预览仅保留确认问句")
		await _shot("pause_confirmation_preview")
		await _click(modal.cancel_button)
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
