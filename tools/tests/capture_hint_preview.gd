extends "res://tools/tests/maze_capture.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_fresh()
		sm.data.ch2_guide_01={"revision":2,"step":"done","seen":{},"banked":{}}
		maze=load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene=maze
		await get_tree().create_timer(0.7).timeout
		maze.player.input_locked=true
		maze._busy=true
		var row: Dictionary=preload("res://data/maze/fenshui_encounters.gd").TYPES.silverfish.duplicate(true)
		row.merge({"id":"preview_silverfish","kind":"silverfish","direction":0})
		var run:=Run.snapshot(sm)
		run.monsters[row.id]={"guaranteed":false}
		var ui=maze.capture_flow.attempt
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d"%[resolution.x,resolution.y]
			ui.present(row,run,true,3)
			ui.start(2.6)
			ui.set_process(false)
			ui.intro_time=2.0
			ui._process(0.02)
			await get_tree().process_frame
			await _capture_image("capture_hint_16")
			_check(ui.status.get_theme_font_size("font_size")==16,"16字号实际场景预览")
		maze.queue_free()
		await get_tree().process_frame
	var f:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
