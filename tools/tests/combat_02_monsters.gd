extends "res://tools/tests/combat_02_flow.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		await _new_scene()
		var flow=maze.capture_flow
		for spec in [["slime_1",3,14,0.45],["snail_1",5,28,0.6],["beetle_1",4,21,0.35],["lizard_1",8,84,0.7]]:
			flow.set_process(false)
			var row := Catalog.find(spec[0])
			var pos := Roads.move_on_road(row.position,Vector2(20,0))
			var c := Combat.create(1,100,pos)
			c.cooldown=100.0
			for id in sm.data[Run.KEY].monsters:
				sm.data[Run.KEY].monsters[id].status="skipped"
				# 只测当前怪物伤害，其他槽位显式延后刷新，避免干扰固定布局夹具。
				sm.data[Run.KEY].monsters[id].respawn_at=100000.0
			sm.data[Run.KEY].monsters[spec[0]].status="alive"
			sm.data[Run.KEY].combat=c
			maze.player.position=pos
			sm.save()
			flow.set_process(true)
			await get_tree().create_timer(0.13).timeout
			_check(Run.snapshot(sm).combat.actors[spec[0]].mode=="windup" and Run.snapshot(sm).combat.hp==100,"真实怪物停步前摇不接触扣血："+spec[0])
			await _capture_image("windup_"+spec[0])
			await get_tree().create_timer(float(spec[3])+0.12).timeout
			_check(Run.snapshot(sm).combat.hp==100-spec[1],"真实怪物单次攻击伤害："+spec[0])
			_check(Run.snapshot(sm).combat.actors[spec[0]].hp==spec[2],"真实怪物生命上限："+spec[0])
			var health: int=Run.snapshot(sm).combat.hp
			await get_tree().create_timer(0.2).timeout
			_check(Run.snapshot(sm).combat.hp==health,"不会每帧持续接触扣血："+spec[0])
		await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
