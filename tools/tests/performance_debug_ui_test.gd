extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var debug := root.get_node_or_null("LocalDebug")
	if not is_instance_valid(debug):
		printerr("调试单例不可用")
		quit(1)
		return
	debug.open_panel()
	assert(debug.tabs.tab_count == 4)
	assert(debug.tabs.get_tab_title(2) == "补充食材")
	debug.tabs.current_tab = 2
	assert(debug.ingredient_page.visible and not debug.performance_page.visible)
	debug.tabs.current_tab = 3
	assert(debug.performance_page.visible)
	debug.performance_detail.button_pressed = true
	debug.performance_start.pressed.emit()
	assert(debug.performance_recorder.active)
	debug.close_panel()
	assert(not paused)
	var event := InputEventKey.new()
	event.keycode = KEY_F9
	event.ctrl_pressed = true
	event.pressed = true
	debug._input(event)
	assert(debug.performance_recorder.model.markers.size() == 1)
	debug.open_panel()
	debug.performance_stop.pressed.emit()
	assert(not debug.performance_recorder.active)
	debug.close_panel()
	print("性能调试面板检查通过：开始、继续运行、快捷键标记和停止")
	quit()
