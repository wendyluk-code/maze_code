extends "res://tools/tests/combat_08_mouse_regression.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_completed()
		sm.cancel_maze_entry()
		sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
		var path: String=sm._active_save_path
		var before: Dictionary=sm.data.duplicate(true)
		sm._active_save_path=""
		_check(not Run.begin(sm,Roads.SPAWN).success and sm.data==before,"新入场保存失败不留下布局/生命/奖励标志")
		sm._active_save_path=path
		_check(Run.begin(sm,Roads.SPAWN).success,"新入场保存恢复后成功")
		var fresh:=Run.snapshot(sm)
		_check(fresh.layout[0].position==[860.0,295.0] and fresh.monsters.size()==10,"失败重试应用首遇规则且只有十只")
		_check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm)==fresh,"重复begin不重抽布局或随机值")
		# 旧固定布局夹具保持原点995,225；新规则不得追溯改写已有进行中探索。
		var old:=fresh.duplicate(true)
		old.layout=[]
		old.monsters={}
		for row in Catalog.all():
			old.layout.append({"kind":row.kind,"position":Combat.pack(row.position)})
			old.monsters[row.id]={"status":"alive","capture_roll":0.17,"drop_roll":0.28,"copy_roll":0.39,"extra_roll":0.41,"guaranteed":false,"respawn_at":0.0,"spawn_position":Combat.pack(row.position),"refresh_count":0}
		old.combat=Combat.create(3,36,Roads.SPAWN,Catalog.all())
		old.combat.actors.slime_1.hp=7
		sm.data[Run.KEY]=old
		_check(sm.save(),"旧进行中固定布局写盘")
		sm.load_data()
		_check(Run.begin(sm,Roads.SPAWN).success and _same_saved(Run.snapshot(sm),old),"旧档读盘恢复保留全部布局/残血/随机值")
		var missing:=old.duplicate(true)
		missing.erase("layout")
		missing.combat.erase("layout")
		sm.data[Run.KEY]=missing
		_check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).layout==old.layout and Run.snapshot(sm).combat.actors==old.combat.actors,"旧档双缺布局仍补原固定点不插入首怪")
		_check(Run.finish(sm,false,Roads.SPAWN).success and Run.begin(sm,Roads.SPAWN).success,"旧趟结束后真正新入场")
		_check(Run.snapshot(sm).layout[0].position==[860.0,295.0],"旧趟下次新入场才应用首遇规则")
		# 捕获经验契约保持：模拟弹道造成真实致死，再由同一事务授予一次经验。
		var run:=Run.snapshot(sm)
		var point:=Vector2(933,269)
		run.combat.hero=Combat.pack(point)
		run.combat.actors.slime_1.position=Combat.pack(point)
		run.combat.actors.slime_1.hp=3
		run.combat.shots=[{"origin":Combat.pack(point),"target":Combat.pack(point),"position":Combat.pack(point),"time":0.0,"lives":Combat.life_ids(run)}]
		sm.data[Run.KEY]=run
		before=sm.data.duplicate(true)
		sm._active_save_path=""
		_check(not Run.combat_tick(sm,point,0.05).success and sm.data==before,"致死经验保存失败回滚弹道/生命/经验")
		sm._active_save_path=path
		_check(Run.combat_tick(sm,point,0.05).success and Run.snapshot(sm).combat.actors.slime_1.hp==0,"真实弹道致死事务成功")
		var growth: Dictionary=Run.Progression.record(sm,"yaya")
		_check(Run.snapshot(sm).monsters.slime_1.experience_generation==0,"首怪生命经验回执")
		_check(Run.combat_tick(sm,point,0.05).success and Run.Progression.record(sm,"yaya")==growth,"已死生命不重复发经验")
		_check(Run.defeat(sm,"slime_1",point).success,"首怪进入原捕获事务")
		_check(Run.resolve(sm,"slime_1",false).success,"可正常放弃首怪捕获")
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
