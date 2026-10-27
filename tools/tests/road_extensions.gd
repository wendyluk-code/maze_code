extends "res://tools/tests/combat_07_flow.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	await _new_scene()
	maze.capture_flow.set_process(false)
	for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status="skipped"
	for polygon in Roads.extra_walkable_areas():
		var triangles := Geometry2D.triangulate_polygon(polygon)
		var center: Vector2=(polygon[triangles[0]]+polygon[triangles[1]]+polygon[triangles[2]])/3.0
		var nearest := Vector2.ZERO
		var distance := INF
		for road in Roads.roads():
			for i in range(road.points.size()-1):
				var point := Geometry2D.get_closest_point_to_segment(center,road.points[i],road.points[i+1])
				if point.distance_to(center)<distance:
					nearest=point
					distance=point.distance_to(center)
		var route := [nearest,center,nearest]
		maze.player.position=route[0]
		for target in route.slice(1):
			var frames:=0
			while maze.player.position.distance_to(target)>3 and frames<180:
				var d: Vector2=maze.player.position.direction_to(target)
				Input.action_press("ui_left",maxf(0,-d.x))
				Input.action_press("ui_right",maxf(0,d.x))
				Input.action_press("ui_up",maxf(0,-d.y))
				Input.action_press("ui_down",maxf(0,d.y))
				await get_tree().physics_frame
				frames+=1
			for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
			_check(maze.player.position.distance_to(target)<4,"实机输入走过校准弯道",{"target":str(target),"actual":str(maze.player.position)})
		maze.camera.snap_to_target()
		await _capture_image("corner_"+str(route[0].x))
	await _close_scene()
	var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)


