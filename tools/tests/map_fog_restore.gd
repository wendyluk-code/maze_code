extends "res://tools/tests/combat_07_flow.gd"
const FogProjection=preload("res://data/maze/entry_map_projection.gd")
const FS=preload("res://data/maze/fenshui_roads.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	await _new_scene()
	maze.capture_flow.set_process(false)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
	maze.travel_region("fenshui",FS.SPAWN)
	await get_tree().create_timer(1.2).timeout
	maze=get_tree().current_scene
	maze.capture_flow.set_process(false)
	var before: Dictionary=sm.data.duplicate(true)
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size=resolution
		await get_tree().process_frame
		maze.map_ui._process(0.2)
		for view in [maze.map_ui.mini_view,maze.map_ui.full_view]:
			var mask: Texture2D=view._fog.get_shader_parameter("road_reveal")
			_check(mask.get_image().get_data()==FogProjection.road_texture().get_image().get_data(),"区域切换不扩张原迷雾遮罩"+str(view.compact))
			_check(view._fog.shader==load("res://scripts/ui/shallow_map_fog.gdshader"),"沿用原雾霾着色器")
		await _capture_image("minimap_"+str(resolution.x))
		maze.map_ui.open_map()
		_check(maze.map_ui.expanded and maze.player.input_locked,"展开地图锁输入")
		await _capture_image("full_map_"+str(resolution.x))
		await _send_key(KEY_ESCAPE)
		_check(not maze.map_ui.expanded and not maze.player.input_locked,"关闭恢复输入")
	_check(sm.data==before,"查看地图不改探索存档")
	var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
