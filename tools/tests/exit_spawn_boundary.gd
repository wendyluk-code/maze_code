extends "res://tools/tests/combat_08_mouse_regression.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离存档")
	var bad := 0
	for seed_value in range(1,301):
		for row in Run.Catalog.random_layout(seed_value):
			if float(row.position[0])<270.0: bad+=1
	_check(bad==0,"300种子出生点不能在蜥蜴后侧",{"bad":bad})
	for p in Run.Catalog.spawn_points():
		_check(p.x>=270.0,"刷新候选不在蜥蜴后侧",{"point":str(p)})
	await _new_scene()
	var run := Run.snapshot(sm)
	_check(not Run.safe_spawn(run,"slime_1",Vector2(191,720),Roads.SPAWN,Rect2(850,0,370,300)),"刷新守卫拒绝蜥蜴与出口间道路")
	_check(Run.Catalog.spawn_inside_exit(Vector2(270,720)),"保留蜥蜴固定点")
	var refresh_bad := 0
	for seed_value in range(1,301):
		var sample: Dictionary = run.duplicate(true)
		sample.spawn_rng_state = str(seed_value)
		for monster in sample.monsters.values():
			monster.status="skipped"
			monster.respawn_at=0.0
		Run.refresh_due(sample,Roads.SPAWN,Rect2(850,0,370,300))
		if sample.monsters.size()!=10: refresh_bad+=1
		for row in sample.layout:
			if float(row.position[0])<270.0: refresh_bad+=1
	_check(refresh_bad==0,"300次实际刷新保持10只且不越过蜥蜴",{"bad":refresh_bad})
	_check(not Run.safe_spawn(run,"slime_1",Vector2(57,711),Roads.SPAWN,Rect2(850,0,370,300)),"刷新守卫拒绝路标后方")
	# 实机展示新布局出口区域，禁止旧布局夹具覆盖随机生成结果。
	var layout := Run.Catalog.random_layout(4)
	sm.data[Run.KEY].layout=layout
	sm.data[Run.KEY].combat=Combat.create(3,36,Vector2(230,710),Run.Catalog.all(2,layout))
	maze.player.position=Vector2(230,710)
	maze.capture_flow.set_process(false)
	maze.capture_flow._process(0.0)
	maze.camera.snap_to_target()
	await _capture_image("exit_spawn_area")
	await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)


