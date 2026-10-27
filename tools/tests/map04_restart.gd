extends "res://tools/tests/maze_capture.gd"
const B=preload("res://data/maze/salt_boss.gd")
const SR=preload("res://data/maze/salt_pool_roads.gd")
const Crystal=preload("res://scripts/maze/salt_crystals.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"跨进程隔离正式档")
	var phase:=OS.get_environment("MAP04_PHASE")
	if phase=="seed":
		_completed()
		sm.cancel_maze_entry()
		_check(Run.begin(sm,Roads.SPAWN).success,"建立旧趟")
		_check(Run.change_region(sm,"salt_pool",SR.SPAWN).success,"首次建立盐池")
		# 模拟上一版盐池已有六怪、尚无Boss的合法存档。
		sm.data[Run.KEY].combat.erase("rock_encounter")
		sm.data[Run.KEY].combat.actors.erase(B.ID)
		sm.data[Run.KEY].monsters.erase(B.ID)
		var prior: Dictionary=sm.data.duplicate(true)
		var path: String=sm._active_save_path
		sm._active_save_path=""
		_check(not Run.begin(sm,SR.SPAWN,"salt_pool").success and sm.data==prior,"旧盐池补Boss保存失败回滚")
		sm._active_save_path=path
		_check(Run.begin(sm,SR.SPAWN,"salt_pool").success,"旧盐池原子补Boss一次")
		for id in prior[Run.KEY].monsters: _check(sm.data[Run.KEY].monsters[id]==prior[Run.KEY].monsters[id],"迁移保留已有怪"+id)
		var actor: Dictionary=sm.data[Run.KEY].combat.actors[B.ID]
		actor.hp=61
		actor.mode="chase"
		actor.rock_phase="charge"
		actor.rock_left=0.6
		actor.rock_aim=[0.6,0.8]
		actor.rock_reuse=5.5
		sm.data[Run.KEY].monsters[B.ID].capture_roll=0.99
		sm.data[Run.KEY].monsters[B.ID].copy_roll=0.99
		sm.data[Crystal.KEY]={"left":{"day":Crystal.day()-1,"used":3},"right":{"day":Crystal.day(),"used":2}}
		_check(sm.save(),"退出保存蓄力和昨日额度")
	else:
		sm._active_save_path="user://chapter-ending-test.json"
		sm.load_data()
		_check(Run.valid(Run.snapshot(sm)),"新进程恢复合法探索")
		var run:=Run.snapshot(sm)
		if phase=="paid":
			var actor: Dictionary=run.combat.actors[B.ID]
			_check(actor.hp==61 and actor.rock_phase=="charge" and is_equal_approx(actor.rock_left,0.6) and actor.rock_aim==[0.6,0.8],"进程重启恢复生命蓄力锁向不重置")
			_check(Crystal.used(sm.data[Crystal.KEY],"left",Crystal.day())==0 and Crystal.used(sm.data[Crystal.KEY],"right",Crystal.day())==2,"离线跨日左恢复三份同日右保留次数")
			var safe: Dictionary=sm.data.duplicate(true)
			sm.data[Run.KEY].combat.erase("rock_encounter")
			_check(not Run.begin(sm,SR.SPAWN,"salt_pool").success,"缺标记残存演员拒绝重抽")
			sm.data=safe.duplicate(true)
			sm.data[Run.KEY].monsters.erase(B.ID)
			_check(not Run.begin(sm,SR.SPAWN,"salt_pool").success,"已建立缺记录拒绝重建")
			sm.data=safe
			sm.data[Run.KEY].combat.actors[B.ID].hp=0
			_check(Run.defeat(sm,B.ID,B.HOME).success and sm.data[Run.ROCK_FIRST],"首次资格持久化绑定")
			_check(Run.start_capture(sm,B.ID).success,"跨进程阶段保存正常付费")
			sm.data.map04_food=sm.data[Run.KEY].satiety
			_check(sm.save(),"保存付费阶段退出")
		elif phase=="resolve":
			_check(run.pending==B.ID and run.monsters[B.ID].guaranteed and run.monsters[B.ID].has("attempt"),"恢复绑定同一只与已付费")
			_check(is_equal_approx(run.monsters[B.ID].capture_roll,0.99),"恢复保留随机数")
			_check(Run.start_capture(sm,B.ID).success and sm.data[Run.KEY].satiety==sm.data.map04_food,"重启不重扣")
			_check(Run.finish_capture(sm,B.ID,false).success and Run.resolve(sm,B.ID,true).get("caught",false),"恢复后不操作首捕成功")
			_check(sm.data[Run.KEY].bag.get("rockmane_meat",0)==1,"肉一次")
		else:
			_check(run.monsters[B.ID].status=="captured" and run.bag.get("rockmane_meat",0)==1,"第三次恢复不复活不重复发肉")
			_check(not Run.resolve(sm,B.ID,true).success,"跨进程重复奖励拒绝")
			for a in sm.data[Run.KEY].combat.actors.values(): a.mode="idle"
			_check(Run.finish(sm,false,SR.SPAWN).success,"放弃旧趟不退款资格")
			_check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"salt_pool",SR.SPAWN).success,"下一趟重建Boss")
			sm.data[Run.KEY].combat.actors[B.ID].hp=0
			sm.data[Run.KEY].monsters[B.ID].capture_roll=0.99
			_check(Run.defeat(sm,B.ID,B.HOME).success and not sm.data[Run.KEY].monsters[B.ID].guaranteed,"下趟没有首捕资格")
			_check(Run.start_capture(sm,B.ID).success and Run.finish_capture(sm,B.ID,false).success,"下趟实际支付与失败操作")
			_check(not Run.resolve(sm,B.ID,true).get("caught",true),"下一趟正常概率与操作失败")
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path},"\t"))
	get_tree().quit(1 if failures else 0)
