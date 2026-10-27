extends "res://tools/tests/combat_02_flow.gd"

var routes: Array = []

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	for pair in [[Vector2(790,326),Vector2(270,720)],[Vector2(790,326),Vector2(933,269)],[Vector2(933,269),Vector2(790,326)],[Vector2(270,720),Vector2(477,766)],[Vector2(477,766),Vector2(270,720)],[Vector2(270,720),Vector2(552,455)],[Vector2(552,455),Vector2(270,720)]]:
		var p: Vector2=pair[0]
		var target: Vector2=pair[1]
		var safe := true
		var stopped := 0
		var waypoint := p
		for i in 1000:
			waypoint=Combat.next_waypoint(p,target)
			var next := Roads.move_on_road(p,p.direction_to(waypoint)*minf(5.0,p.distance_to(waypoint)))
			safe=safe and Combat.clear_line(p,next,Roads.FOOT_RADIUS)
			stopped=stopped+1 if next.distance_to(p)<0.001 else 0
			p=next
			if p.distance_to(target)<2 or stopped>=20: break
		var evidence := {"origin":Combat.pack(pair[0]),"target":Combat.pack(target),"last":Combat.pack(p),"waypoint":Combat.pack(waypoint),"stopped":stopped}
		routes.append(evidence)
		_check(p.distance_to(target)<2,"道路双向绕弯抵达",evidence)
		_check(safe,"每步保持道路且不穿墙",evidence)
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"routes":routes,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
