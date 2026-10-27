extends "res://tools/tests/rec01_r2.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	_seed()
	for checkpoint in ["party","home","maze","title"]: sm.advance_chapter_1_outro(checkpoint)
	await _open_scene()
	HomePage.open_page(get_tree())
	await get_tree().process_frame
	var page = get_tree().get_first_node_in_group("adventurer_home")
	await _click(page.tabs[1])
	var view = page.recruit_results
	var sample := [{"id":"salia","rank":6,"kind":"stardust","stardust":200},{"id":"yufeng","rank":2,"kind":"upgrade","stardust":0}]
	var saved: Dictionary = sm.data.duplicate(true)
	for resolution in [Vector2i(1152,648),Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		await get_tree().process_frame
		view.present(sample)
		view._show_overview()
		await get_tree().process_frame
		_validate_spacing(view)
		_check(view.get_child(0).color == Color(0.08,0.06,0.04,0.86), "仅结果暖深棕蒙层0.86")
		await _shot("spacing_two")
		await _click(view.next_button)
		var many = preload("res://tools/tests/rec01_layout_view.gd").new()
		view.get_parent().add_child(many)
		many.amount = 10
		many.present(sample)
		many._show_overview()
		await get_tree().process_frame
		_validate_spacing(many)
		await _shot("spacing_ten")
		await _click(many.next_button)
		many.queue_free()
		view.present([sample[0]])
		await _wait_stage(view,"dust")
		_check(view.loot.visible and not view.loot._overlay.visible, "星尘弹窗不叠加第二蒙层")
		await _shot("spacing_dust")
		await _click(view.loot._confirm_button)
		await _click(view.next_button)
	_check(sm.data == saved, "展示未改变状态")
	await _click(page.back_button)
	await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _validate_spacing(view: Control) -> void:
	var all: Array = view.content.get_children()
	for child in all:
		_check(get_viewport().get_visible_rect().encloses(child.get_global_rect()) and not child.get_global_rect().intersects(view.next_button.get_global_rect()), "卡片与文字在屏内且避开按钮")
		if child is VBoxContainer:
			_check(child.get_theme_constant("separation") == 8, "文字行距8设计像素")
			for other in all:
				if other != child: _check(not child.get_global_rect().intersects(other.get_global_rect()), "文字块不与其他卡面或文字交叠")
