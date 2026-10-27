extends "res://tools/tests/combat_08_feedback.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	await _new_scene()
	_fixture()
	maze.capture_flow._process(0.2)
	_check(Run.snapshot(sm).combat.hp==33,"长帧真实近战扣血")
	_check(maze.player.body.material.get_shader_parameter("flash"),"长帧扣血后首个渲染帧必须闪白")
	maze.capture_flow._process(0.0)
	await _capture_image("long_frame_hit")
	maze.capture_flow._process(0.05)
	_check(maze.player.body.material.get_shader_parameter("flash"),"显示50毫秒仍闪白")
	maze.capture_flow._process(0.06)
	_check(not maze.player.body.material.get_shader_parameter("flash"),"显示110毫秒恢复原色")
	await _capture_image("long_frame_recovered")
	await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

