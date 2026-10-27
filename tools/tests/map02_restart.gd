extends "res://tools/tests/maze_capture.gd"
const B = preload("res://data/maze/fenshui_boss.gd")
const FS = preload("res://data/maze/fenshui_roads.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"跨进程隔离档")
	var phase := OS.get_environment("MAP02_PHASE")
	if phase=="seed":
		_completed()
		sm.cancel_maze_entry()
		sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
		_check(Run.begin(sm,Roads.SPAWN).success,"新探索")
		_check(Run.change_region(sm,"fenshui",FS.SPAWN).success,"分水庭建立")
		_check(sm.set_yufeng_salia_state("done").success,"已完成御风")
		_check(Run.combat_tick(sm,B.HOME,0.05).success,"入水跳跃提交")
		_check(Run.combat_tick(sm,B.HOME,0.25).success,"跳跃预警推进")
		sm.data.map02_roll=sm.data[Run.KEY].monsters[B.ID].capture_roll
		_check(sm.save(),"跳跃预警中进程退出")
	else:
		sm._active_save_path="user://chapter-ending-test.json"
		sm.load_data()
		var run := Run.snapshot(sm)
		_check(Run.valid(run),"新进程恢复合法")
		_check(is_equal_approx(run.monsters[B.ID].capture_roll,sm.data.map02_roll),"随机数跨进程不重抽")
		if phase=="paid":
			_check(run.combat.actors[B.ID].frog_phase=="warning" and is_equal_approx(run.combat.actors[B.ID].frog_left,0.75),"跳跃预警剩余时间跨进程恢复")
			for i in 16: _check(Run.combat_tick(sm,B.HOME,0.05).success,"续完出场")
			_check(sm.data[Run.KEY].combat.actors[B.ID].frog_phase=="airborne","预警不重播，接续腾空")
			sm.data[Run.KEY].combat.actors[B.ID].hp=0
			_check(Run.defeat(sm,B.ID,B.HOME).success,"保存待捕获")
			_check(Run.start_capture(sm,B.ID).success,"保存付费")
			sm.data.map02_food=sm.data[Run.KEY].satiety
			_check(sm.save(),"付费进程退出")
		else:
			_check(run.pending==B.ID and run.monsters[B.ID].has("attempt"),"恢复付费待捕获")
			_check(Run.start_capture(sm,B.ID).success and sm.data[Run.KEY].satiety==sm.data.map02_food,"跨进程不重扣")
			_check(Run.finish_capture(sm,B.ID,false).success,"操作失败持久化")
			var result := Run.resolve(sm,B.ID,true)
			_check(result.success and not result.caught and sm.data[Run.KEY].bag.is_empty(),"首次巨蛙操作失败无必成保底")
			sm.load_data()
			_check(sm.data[Run.KEY].monsters[B.ID].status=="failed" and not Run.resolve(sm,B.ID,true).success,"结算读档不复活不重试")
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path},"\t"))
	get_tree().quit(1 if failures else 0)
