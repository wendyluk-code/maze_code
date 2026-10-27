extends "res://tools/tests/combat_07_flow.gd"
const FS = preload("res://data/maze/fenshui_roads.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	if failures == 0:
		_completed()
		sm.cancel_maze_entry()
		sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
		_check(Run.begin(sm,Roads.SPAWN).success,"新探索")
		var initial := Run.snapshot(sm)
		for kind in ["slime","snail","beetle","lizard"]:
			for status in ["captured","failed","skipped"]:
				var run := initial.duplicate(true)
				var id: String = kind + "_1"
				run.monsters[id].status = status
				run.monsters[id].respawn_at = Run.respawn_delay(kind)
				run.combat.actors[id].hp = 0
				run.maze_elapsed = 600.0
				var before := run.duplicate(true)
				_check(not Run.refresh_due(run,Roads.SPAWN,Rect2(850,0,370,300)) and run == before,"到期不刷新且不改随机/布局："+kind+"/"+status)
		_state_b2(initial)
		if DisplayServer.get_name() != "headless": await _visual_b2()
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("B2 ",checks," checks ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _state_b2(initial: Dictionary) -> void:
	sm.data[Run.KEY] = initial.duplicate(true)
	for pair in [["slime_1",true,true],["snail_1",true,false],["beetle_1",false,false]]:
		var id: String = pair[0]
		sm.data[Run.KEY].combat.actors[id].hp = 0
		var before: Dictionary = sm.data.duplicate(true)
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		_check(not Run.defeat(sm,id,Roads.SPAWN).success and sm.data==before,"击败保存失败回滚："+id)
		sm._active_save_path = path
		_check(Run.defeat(sm,id,Roads.SPAWN).success,"击败："+id)
		if pair[1]:
			sm.data[Run.KEY].monsters[id].capture_roll = 0.0
			_check(Run.start_capture(sm,id).success,"开始付费捕获")
			_check(Run.finish_capture(sm,id,pair[2]).success,"保存捕获结果")
		before = sm.data.duplicate(true)
		sm._active_save_path = ""
		_check(not Run.resolve(sm,id,pair[1]).success and sm.data==before,"结算保存失败回滚："+id)
		sm._active_save_path = path
		_check(Run.resolve(sm,id,pair[1]).success,"捕获/失败/放弃结算："+id)
		before = sm.data.duplicate(true)
		_check(not Run.resolve(sm,id,pair[1]).success and sm.data==before,"结算幂等："+id)
	var settled := Run.snapshot(sm)
	_check(settled.monsters.slime_1.status=="captured" and settled.monsters.snail_1.status=="failed" and settled.monsters.beetle_1.status=="skipped","三种结算结果")
	# 只推进生产时钟；怪物已死亡，玩家停在出生点。
	for i in 362:
		var result := Run.combat_tick(sm,Roads.SPAWN,0.5,Rect2(850,0,370,300))
		if not result.success:
			_check(false,"生产时钟推进",result)
			break
	_check(Run.snapshot(sm).monsters==settled.monsters,"等待181秒超过全部旧期限仍不刷新")
	var before: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	_check(not Run.combat_tick(sm,Roads.SPAWN,0.5).success and sm.data==before,"时钟保存失败回滚")
	_check(not Run.change_region(sm,"fenshui",FS.SPAWN).success and sm.data==before,"跨区保存失败回滚")
	sm._active_save_path = path
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"前往分水庭")
	_check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"返回枯水渠")
	_check(Run.snapshot(sm).monsters.values().all(func(m): return m.status!="alive"),"跨区往返已死不复活，保留返回清区规则")
	settled = Run.snapshot(sm)
	_check(sm.save(),"存盘")
	sm.load_data()
	_check(Run.begin(sm,Roads.SPAWN).success,"同趟恢复")
	_check(_same_saved(Run.snapshot(sm).monsters,settled.monsters),"同趟读档保留结果")
	for monster in sm.data[Run.KEY].monsters.values(): monster.erase("respawn_at")
	_check(Run.begin(sm,Roads.SPAWN).success,"旧档缺时钟可恢复")
	_check(Run.snapshot(sm).monsters.slime_1.status!="alive","旧档死亡保留")
	for bank in [false,true]:
		_check(Run.finish(sm,bank,preload("res://data/maze/settlement_exit.gd").FRONT).success,"结束探索 bank="+str(bank))
		_check(Run.begin(sm,Roads.SPAWN).success,"开始下一趟")
		var run := Run.snapshot(sm)
		_check(run.monsters.values().all(func(m): return m.status=="alive" and m.refresh_count==0),"新趟重新生成所有怪物")

func _visual_b2() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	var id := "slime_1"
	sm.data[Run.KEY].combat.actors[id].hp = 1
	await _capture_image("b2_before_kill")
	sm.data[Run.KEY].combat.cooldown = 0.0
	var target := Run.Combat.vec(sm.data[Run.KEY].combat.actors[id].position)
	_check(Run.combat_attack(sm,Roads.SPAWN,target-Roads.SPAWN).success,"实际场景生产攻击")
	for i in 20: Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(850,0,370,300))
	_check(sm.data[Run.KEY].combat.actors[id].hp==0,"生产弹道实际击杀")
	_check(Run.defeat(sm,id,Roads.SPAWN).success and Run.resolve(sm,id,false).success,"实际场景死亡结算")
	sm.data[Run.KEY].maze_elapsed = 600.0
	_check(Run.combat_tick(sm,Roads.SPAWN,0.5,Rect2(850,0,370,300)).success,"实际场景越过旧期限")
	maze.capture_flow._process(0.0)
	await _capture_image("b2_dead_after_deadline")
	_check(not maze.capture_flow.monsters[id].visible,"实际怪物节点保持隐藏")
	# 复用实际场景节点检查跨区读档显示。
	_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"图形流程跨区")
	_check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"图形流程返回")
	_check(sm.save(),"图形流程存盘")
	sm.load_data()
	_check(Run.begin(sm,Roads.SPAWN).success,"图形流程恢复")
	maze.capture_flow._process(0.0)
	await _capture_image("b2_return_and_reload")
	_check(not maze.capture_flow.monsters[id].visible and Run.snapshot(sm).combat.actors[id].hp==0,"跨区读档实际节点仍死亡")
	await _close_scene()
