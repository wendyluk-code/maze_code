extends "res://tools/tests/maze_capture.gd"
const MapProjection := preload("res://data/maze/entry_map_projection.gd")
const Stone := preload("res://data/maze/settlement_exit.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
		DisplayServer.window_set_size(resolution)
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_completed()
		_check(sm.request_maze_entry().success, "准备真实迷宫入口")
		maze = load("res://scenes/maze_entry.tscn").instantiate()
		get_tree().root.add_child(maze)
		get_tree().current_scene = maze
		await get_tree().create_timer(0.6).timeout
		var map = maze.map_ui
		map.refresh_resources()
		_check(map.visible_resources.any(func(r): return r.kind == "settlement"), "真实地图包含石阵")
		for position in [Stone.POSITION + Vector2(90,0), Stone.POSITION]:
			maze.player.position = position
			await get_tree().create_timer(0.3).timeout
			await _visible_marker(map.mini_view, "mini_" + str(int(position.x)))
			map.open_map()
			await get_tree().create_timer(0.2).timeout
			_check(map.expanded and maze.player.input_locked, "地图展开锁定移动")
			await _visible_marker(map.full_view, "full_" + str(int(position.x)))
			map.close_map()
			_check(not maze.player.input_locked, "关闭恢复移动")
		var chests: Array = map.visible_resources.filter(func(r): return r.kind == "chest")
		_check(not chests.is_empty(), "保留未领取宝箱")
		_check(map.mini_view._chests.material.shader == load("res://scripts/ui/components/maze_map_icon.gdshader"), "宝箱沿用金色着色器")
		map.visible_resources.clear()
		map._add_resource({"id":"claimed", "position":Stone.POSITION}, "chest", true)
		_check(map.visible_resources.is_empty(), "已领取宝箱不再显示")
		map._unlocked = false
		map._add_resource({"id":"settlement_portal", "position":Stone.POSITION}, "settlement", false)
		_check(map.visible_resources.is_empty(), "未解锁不提前显示石阵")
		maze.queue_free()
		await get_tree().process_frame
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)

func _visible_marker(view: Control, label: String) -> void:
	await RenderingServer.frame_post_draw
	var projected := MapProjection.new().project(Stone.POSITION)
	_check(projected.distance_to(Vector2(1200,398)) < 0.1, "石阵对应实际地图地标")
	var rect: Rect2 = view.landmark_rect(projected)
	_check((rect.position + Vector2(rect.size.x*0.5,rect.size.y)).distance_to(view.to_view(projected+Vector2(-22,-8))) < 0.1, "路标底部落在指定道路锚点")
	_check(is_equal_approx(rect.size.y,22.0 if view.compact else 36.0), "路标等比缩小")
	var center: Vector2 = view.global_position + rect.get_center()
	var shot := get_viewport().get_texture().get_image()
	var pixels := 0
	for y in range(maxi(0,int(center.y)-20),mini(shot.get_height(),int(center.y)+21)):
		for x in range(maxi(0,int(center.x)-20),mini(shot.get_width(),int(center.x)+21)):
			var color := shot.get_pixel(x,y)
			if color.b > color.g * 1.15 and color.r > color.g * 1.15 and color.b > 0.4: pixels += 1
	_check(pixels >= 20, "实际像素紫色可辨识：" + label, {"pixels":pixels})
	await _capture_image(label)
