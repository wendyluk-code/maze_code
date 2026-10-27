extends "res://tools/tests/combat_07_flow.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	await _new_scene()
	maze.capture_flow.set_process(false)
	for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status="skipped"
	for route in [[Vector2(707,991),Vector2(721,1014),Vector2(724,1037),Vector2(728,1073),Vector2(741,1095),Vector2(762,1119)],[Vector2(1060,651),Vector2(1081,678),Vector2(1081,704),Vector2(1086,755)],[Vector2(813,686),Vector2(838,704),Vector2(853,732),Vector2(862,771)]]:
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
