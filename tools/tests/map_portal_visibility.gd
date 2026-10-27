extends "res://scripts/maze/tests/map_hud_scene.gd"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _new_scene()
			for region in ["maze_entry", "fenshui", "salt_pool"]:
				if region != "maze_entry":
					if not _prepare_region_fixture(): break
					var spawn: Vector2 = preload("res://data/maze/fenshui_roads.gd").SPAWN if region == "fenshui" else preload("res://data/maze/salt_pool_roads.gd").SPAWN
					maze.travel_region(region, spawn)
					await get_tree().create_timer(1.3).timeout
					maze = get_tree().current_scene
				_check(maze.region_id == region, "真实区域 " + region)
				maze.capture_flow.set_process(false)
				var map = maze.map_ui
				map.refresh_resources()
				var portals: Array = map.visible_resources.filter(func(r): return r.kind == "settlement")
				_check(portals.size() == 2, "路标连接覆盖且两端去重 " + region)
				_check(map.mini_view._image.texture == map.mini_view.MAP and map.full_view._image.texture == map.full_view.MAP, "所有地区两种地图统一总览底图 " + region)
				if region == "salt_pool":
					var entrance: Vector2 = map._projection.project(preload("res://data/maze/salt_pool_roads.gd").ENTRANCE)
					_check(entrance.is_equal_approx(portals[1].position), "盐池入口与分水庭连接在总图上重合")
				var ids := {}
				for portal in portals: ids[portal.id] = true
				_check(ids.size() == portals.size(), "连接标记无重复 " + region)
				# 靠近当前区域路标，截图包含小地图。
				maze.player.position = preload("res://data/maze/settlement_exit.gd").FRONT if region == "maze_entry" else preload("res://data/maze/region_routes.gd").route(region).spawn
				maze.camera.snap_to_target()
				await get_tree().create_timer(0.2).timeout
				await RenderingServer.frame_post_draw
				await _capture_image(region + "_mini")
				map.open_map()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				_check(map.expanded, "展开地图 " + region)
				await _capture_image(region + "_full")
				map.close_map()
				_check(not maze.player.input_locked, "关闭恢复输入 " + region)
			await _close_scene()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results}, "\t"))
	get_tree().quit(1 if failures else 0)
