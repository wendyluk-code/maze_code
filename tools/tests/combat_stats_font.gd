extends "res://tools/tests/combat_07_flow.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size=resolution
		suffix="_%dx%d" % [resolution.x,resolution.y]
		await _new_scene()
		var flow=maze.capture_flow
		flow.set_process(false)
		maze.player.position=Vector2(888,288)
		sm.data[Run.KEY].combat.actors.slime_1.position=[836,310]
		flow._process(0)
		maze.camera.snap_to_target()
		var labels: Array=[flow.power_label,flow.hp_label]
		for monster in flow.monsters.values(): labels.append_array([monster.label,monster.hp_label])
		for label in labels:
			_check(label.get_theme_font("font")==load("res://assets/ui/combat_stats_font.tres"),"头顶属性使用独立无衬线字体")
			_check(label.get_theme_font_size("font_size")==9 and label.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT,"字号与左对齐保持")
		_check(flow.health_bar.size.x==60,"血条尺寸保持")
		await _capture_image("stats_font")
		await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
