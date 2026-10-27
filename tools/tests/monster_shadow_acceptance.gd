extends "res://tools/tests/maze_capture.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	_completed()
	_check(sm.request_maze_entry().success, "建立真实迷宫")
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.6).timeout
	maze.capture_flow.set_process(false)
	for id in ["lizard_1","snail_1","snail_2","snail_3"]:
		var monster = maze.capture_flow.monsters[id]
		monster.set_process(false)
		maze.player.position = monster.position
		maze.player.hide()
		await get_tree().create_timer(0.6).timeout
		for frame in 4:
			monster._draw_frame(frame)
			var image: Image = monster.body.texture.get_image()
			var bottom := 0
			for y in image.get_height():
				for x in image.get_width():
					if image.get_pixel(x,y).a >= 0.5: bottom = maxi(bottom,y+1)
			var feet_y: float = (monster.body.offset.y+bottom)*monster.body.scale.y
			_check(absf(monster.shadow.position.y-(feet_y-2))<0.1, id+"帧"+str(frame)+"投影贴合可见脚底")
			_check(monster.position == monster.config.position, "魔物世界位置保持不变")
			await _capture_image(id+"_frame_"+str(frame))
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
