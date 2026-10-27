extends "res://tools/tests/combat_06_flow.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	await _new_scene()
	maze.capture_flow.set_process(false)
	maze.player.set_physics_process(false)
	var c: Dictionary=sm.data[Run.KEY].combat
	c.erase("sprint")
	c.erase("sprint_rest")
	_check(Run.valid(Run.snapshot(sm)),"旧档缺加速字段仍有效")
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05).success,"旧档首次推进成功")
	_check(Run.snapshot(sm).combat.sprint==1.0,"旧档加速初始化满条")
	sm.data[Run.KEY].combat.sprint=0.37
	sm.data[Run.KEY].combat.sprint_rest=0.42
	_check(sm.save(),"部分加速与恢复等待写盘")
	sm.load_data()
	_check(is_equal_approx(Run.snapshot(sm).combat.sprint,0.37) and is_equal_approx(Run.snapshot(sm).combat.sprint_rest,0.42),"读档恢复资源与等待时钟")
	_check(not maze.player.sprint_held,"读档不恢复按键")
	var run: Dictionary=Run.snapshot(sm)
	for id in run.monsters: run.monsters[id].status="skipped"
	run.monsters.slime_1.status="alive"
	run.monsters.slime_2.status="alive"
	run.combat.cooldown=0.0
	run.combat.actors.slime_1.position=Combat.pack(Roads.SPAWN+Vector2(-90,30))
	run.combat.actors.slime_2.position=Combat.pack(Roads.SPAWN+Vector2(-40,15))
	run.combat.actors.slime_1.velocity=[0,0]
	run.combat.actors.slime_2.velocity=[0,0]
	_check(Combat.attack(run,Roads.SPAWN,Vector2.LEFT) and Combat.vec(run.combat.shots.back().target)==Roads.SPAWN+Vector2.LEFT*210,"锅铲按给定方向发射")
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	run.combat.actors.slime_2.mode="return"
	_check(Combat.attack(run,Roads.SPAWN,Vector2.UP) and Combat.vec(run.combat.shots.back().target)==Roads.SPAWN+Vector2.UP*210,"附近魔物不改变攻击方向")
	run.combat.cooldown=0.0
	run.combat.action_left=0.0
	run.combat.actors.slime_1.position=Combat.pack(Roads.SPAWN+Vector2(-181,0))
	_check(not Combat.attack(run,Roads.SPAWN,Vector2.ZERO),"零方向拒绝")
	run.combat.actors.slime_1.position=Combat.pack(Roads.SPAWN+Vector2(-180,0))
	_check(Combat.attack(run,Roads.SPAWN,Vector2.RIGHT),"无正面目标也允许发射")
	c=sm.data[Run.KEY].combat
	c.cooldown=0.0
	c.shots=[]
	c.actors.slime_1.position=Combat.pack(Roads.SPAWN+Vector2(-40,15))
	var path: String=sm._active_save_path
	sm._active_save_path=""
	var original: Dictionary=sm.data.duplicate(true)
	_check(not Run.combat_attack(sm,Roads.SPAWN).success and sm.data==original,"攻击保存失败还原冷却弹道次数全状态")
	sm.data[Run.KEY].combat.checkpoint=0.5
	original=sm.data.duplicate(true)
	_check(not Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(),true).success and sm.data==original,"加速保存失败恢复耗条与战斗全状态")
	sm._active_save_path=path
	var corrupt: Dictionary=Run.snapshot(sm).combat
	corrupt.sprint=-0.1
	_check(not Combat.valid(corrupt),"非法加速量拒绝")
	await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
