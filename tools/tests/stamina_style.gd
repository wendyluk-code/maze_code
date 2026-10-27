extends "res://tools/tests/stamina_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%d" % resolution.x
			_completed()
			var completed: Dictionary = sm.data.duplicate(true)
			sm.data = sm._defaults()
			sm.data.prologue_done = true
			await _open_scene()
			var energy = get_tree().get_first_node_in_group("stamina_counter")
			_check(not energy.visible and not energy.hint_panel.visible, "第一章开始时隐藏整组体力")
			await _shot("style_before_chapter")
			tm._cancel_current_run()
			sm.data = completed
			sm.data.chapter_1_outro = "title"
			await get_tree().process_frame
			_check(not energy.visible, "第一章结束蒙层尚未关闭时隐藏")
			sm.data.chapter_1_outro = "done"
			await get_tree().process_frame
			_check(energy.visible, "第一章完整结束后显示")
			await _hover_check(energy, "style_restaurant")
			var hud = get_tree().get_first_node_in_group("restaurant_hud")
			hud._player.input_locked = false
			hud._open_confirmation("迷宫")
			await _click_control(hud.confirm_button)
			await get_tree().create_timer(1.5).timeout
			energy = get_tree().get_first_node_in_group("stamina_counter")
			_check(energy.visible and energy.counter.value_label.text == "80/100", "迷宫体力显示与消耗保持")
			await _hover_check(energy, "style_maze")
			scene = get_tree().current_scene
			await _close_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "results": results, "user_dir": ProjectSettings.globalize_path("user://")}, "\t"))
	print("STAMINA_STYLE ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _hover_check(energy: Control, label: String) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = energy.info.get_global_rect().get_center()
	get_viewport().warp_mouse(motion.position)
	get_viewport().push_input(motion)
	await get_tree().create_timer(0.2).timeout
	_check(energy.info.size == Vector2(18,18), "感叹号18像素")
	_check(energy.hint_panel.visible, "实际鼠标悬停显示提示")
	var hint: Rect2 = energy.hint_panel.get_global_rect()
	_check(absf(hint.end.x - energy.info.get_global_rect().end.x) < 1, "提示框与感叹号右对齐")
	_check(hint.position.y >= energy.get_global_rect().end.y + 7, "提示框位于数字下方且无覆盖")
	var style: StyleBoxFlat = energy.hint_panel.get_theme_stylebox("panel")
	_check(style.bg_color.a < 1 and style.bg_color.r == style.bg_color.g, "半透明灰色提示框")
	await _shot(label)
	motion.position = Vector2(600,400)
	get_viewport().warp_mouse(motion.position)
	get_viewport().push_input(motion)
	await get_tree().process_frame
	_check(not energy.hint_panel.visible, "鼠标移开关闭提示")
