extends "res://tools/tests/yufeng_sitting_flow.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离目录")
	if failures == 0:
		DirAccess.make_dir_recursive_absolute(_arg("--output-dir="))
		_prepare_trip()
		await _open_map()
		var e = maze.yf_encounter
		e.set_process(false)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,512)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.material = e.idle.material
		viewport.add_child(sprite)
		var baseline: Image
		var moving_pixels := 0
		for i in 4:
			sprite.material.set_shader_parameter("left_eye_source",e.EYE_ANCHORS[i][0])
			sprite.material.set_shader_parameter("right_eye_source",e.EYE_ANCHORS[i][1])
			sprite.texture = load("res://assets/characters/yufeng_salia_sitting/frame_%02d.png" % i)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var frame := viewport.get_texture().get_image()
			frame.save_png(_arg("--output-dir=")+"/fixed_%d.png" % i)
			if i == 0:
				baseline = frame
				continue
			var stone_changes := 0
			for y in 512:
				for x in 512:
					if frame.get_pixel(x,y) != baseline.get_pixel(x,y):
						if not Rect2i(250,178,76,43).has_point(Vector2i(x,y)): stone_changes += 1
						else: moving_pixels += 1
			_check(stone_changes == 0,"眼部之外脸部石头及身体像素完全固定：帧%d" % i)
		_check(moving_pixels > 0,"面部仍有眨眼动画")
		await _capture_image("scene_fixed")
		viewport.queue_free()
		await _close_map()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
