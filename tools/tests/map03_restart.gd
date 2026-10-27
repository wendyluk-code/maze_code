extends "res://tools/tests/maze_capture.gd"
const F = preload("res://data/maze/salt_pool_encounters.gd")
const FS = preload("res://data/maze/salt_pool_roads.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"独立进程隔离档")
	var phase := OS.get_environment("MAP03_PHASE")
	var crab := F.all()[0]
	if phase=="seed":
		_completed()
		sm.cancel_maze_entry()
		_check(Run.begin(sm,Roads.SPAWN).success,"建立仅首区旧结构")
		var initial := Run.snapshot(sm)
		_check(not initial.combat.has("salt_encounters"),"未到访不增加区域怪物")
		_check(sm.record_maze_location("salt_pool",FS.SPAWN).success,"模拟旧版盐池静区存档")
		var previous: Dictionary=sm.data.duplicate(true)
		var path: String=sm._active_save_path
		sm._active_save_path=""
		_check(not Run.begin(sm,FS.SPAWN,"salt_pool").success and sm.data==previous,"迁移保存失败不留下半套演员或随机数")
		sm._active_save_path=path
		_check(Run.begin(sm,FS.SPAWN,"salt_pool").success,"旧盐池档原子补入六怪")
		for id in initial.monsters:
			_check(sm.data[Run.KEY].monsters[id]==initial.monsters[id],"迁移不改原区结果"+id)
		var run: Dictionary=sm.data[Run.KEY]
		var scorpion: Dictionary=run.combat.actors[F.all()[4].id]
		scorpion.hp=13
		scorpion.mode="windup"
		scorpion.windup=0.3
		scorpion["attack_aim"]=[0.6,0.8]
		run.combat.actors[crab.id].hp=0
		run.monsters[crab.id].capture_roll=0.12
		_check(Run.defeat(sm,crab.id,FS.SPAWN).success,"保存待捕获")
		_check(Run.start_capture(sm,crab.id).success,"保存已付费阶段")
		run=sm.data[Run.KEY]
		sm.data["map03_test_food"]=run.satiety
		_check(sm.save(),"进程退出前持久化")
	elif phase=="restore":
		sm._active_save_path="user://chapter-ending-test.json"
		sm.load_data()
		var run := Run.snapshot(sm)
		_check(Run.valid(run) and run.combat.region=="salt_pool","新进程恢复区域战斗")
		_check(run.pending==crab.id and run.monsters[crab.id].has("attempt"),"新进程恢复已付费待捕获")
		_check(is_equal_approx(float(run.monsters[crab.id].capture_roll),0.12),"不重抽捕获随机数")
		var scorpion: Dictionary=run.combat.actors[F.all()[4].id]
		_check(scorpion.hp==13 and scorpion.mode=="windup" and is_equal_approx(scorpion.windup,0.3) and scorpion.attack_aim==[0.6,0.8],"蝎血量前摇锁向跨进程恢复")
		_check(Run.start_capture(sm,crab.id).success and sm.data[Run.KEY].satiety==sm.data.map03_test_food,"跨进程不再次扣费")
		var safe: Dictionary=sm.data.duplicate(true)
		sm.data[Run.KEY].monsters.erase(crab.id)
		_check(not Run.begin(sm,FS.SPAWN,"salt_pool").success,"缺区域记录恢复时拒绝，不崩溃或重建")
		sm.data=safe.duplicate(true)
		sm.data[Run.KEY].combat.erase("salt_encounters")
		_check(not Run.begin(sm,FS.SPAWN,"salt_pool").success,"区域标记缺失不能重抽随机数")
		sm.data=safe
		_check(Run.finish_capture(sm,crab.id,false).success,"恢复后操作失败可以结算")
		_check(not Run.resolve(sm,crab.id,true).get("caught",true),"普通蟹没有隐藏成功保底")
		_check(sm.data[Run.KEY].bag.is_empty() and sm.data[Run.KEY].monsters[crab.id].status=="failed","失败不发肉且本趟终结")
	else:
		sm._active_save_path="user://chapter-ending-test.json"
		sm.load_data()
		var run := Run.snapshot(sm)
		_check(Run.valid(run) and run.monsters[crab.id].status=="failed","第三进程恢复已终结结果")
		_check(run.bag.is_empty() and run.satiety==sm.data.map03_test_food,"第三进程不重扣不发肉")
		_check(not Run.resolve(sm,crab.id,true).success,"第三进程拒绝重复奖励")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path},"\t"))
	get_tree().quit(1 if failures else 0)
