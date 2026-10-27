extends "res://tools/tests/maze_capture.gd"
const F = preload("res://data/maze/fenshui_encounters.gd")
const FS = preload("res://data/maze/fenshui_roads.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"独立进程隔离档")
	var phase := OS.get_environment("MAP01_PHASE")
	var fish := F.all()[0]
	if phase=="seed":
		_completed()
		sm.cancel_maze_entry()
		_check(Run.begin(sm,Roads.SPAWN).success,"建立仅首区旧结构")
		var initial := Run.snapshot(sm)
		_check(not initial.combat.has("fenshui_encounters"),"未到访不增加区域怪物")
		_check(sm.record_maze_location("fenshui",FS.SPAWN).success,"模拟旧版分水庭静区存档")
		_check(Run.begin(sm,FS.SPAWN,"fenshui").success,"旧分水庭档原子补入六怪")
		for id in initial.monsters:
			_check(sm.data[Run.KEY].monsters[id]==initial.monsters[id],"迁移不改原区结果"+id)
		var run: Dictionary=sm.data[Run.KEY]
		run.combat.actors[fish.id].hp=0
		run.monsters[fish.id].capture_roll=0.12
		_check(Run.defeat(sm,fish.id,FS.SPAWN).success,"保存待捕获")
		_check(Run.start_capture(sm,fish.id).success,"保存已付费阶段")
		run=sm.data[Run.KEY]
		sm.data["map01_test_food"]=run.satiety
		_check(sm.save(),"进程退出前持久化")
	else:
		sm._active_save_path="user://chapter-ending-test.json"
		sm.load_data()
		var run := Run.snapshot(sm)
		_check(Run.valid(run) and run.combat.region=="fenshui","新进程恢复区域战斗")
		_check(run.pending==fish.id and run.monsters[fish.id].has("attempt"),"新进程恢复已付费待捕获")
		_check(is_equal_approx(float(run.monsters[fish.id].capture_roll),0.12),"不重抽捕获随机数")
		_check(Run.start_capture(sm,fish.id).success and sm.data[Run.KEY].satiety==sm.data.map01_test_food,"跨进程不再次扣费")
		var safe: Dictionary=sm.data.duplicate(true)
		sm.data[Run.KEY].monsters.erase(fish.id)
		_check(not Run.begin(sm,FS.SPAWN,"fenshui").success,"缺区域记录恢复时拒绝，不崩溃或重建")
		sm.data=safe.duplicate(true)
		sm.data[Run.KEY].combat.erase("fenshui_encounters")
		_check(not Run.begin(sm,FS.SPAWN,"fenshui").success,"区域标记缺失不能重抽随机数")
		sm.data=safe
		_check(Run.finish_capture(sm,fish.id,false).success,"恢复后操作失败可以结算")
		_check(not Run.resolve(sm,fish.id,true).get("caught",true),"普通鱼没有隐藏成功保底")
		_check(sm.data[Run.KEY].bag.is_empty() and sm.data[Run.KEY].monsters[fish.id].status=="failed","失败不发肉且本趟终结")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path},"\t"))
	get_tree().quit(1 if failures else 0)
