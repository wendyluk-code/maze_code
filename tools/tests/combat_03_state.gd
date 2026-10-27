extends "res://tools/tests/maze_capture.gd"
const Combat = preload("res://scripts/maze/combat_simulation.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_completed(); sm.cancel_maze_entry()
		sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
		_check(Run.begin(sm,Roads.SPAWN).success,"生产随机状态")
		var initial:=Run.snapshot(sm)
		for kind in ["slime","snail","beetle","lizard"]:
			var id: String=kind+"_1"
			var run: Dictionary=initial.duplicate(true)
			for other in run.monsters:
				run.monsters[other].status="skipped"
				run.monsters[other].respawn_at=100000.0
			run.monsters[id].status="captured"
			run.monsters[id].respawn_at=Run.respawn_delay(kind)
			run.monsters[id].guaranteed=true
			run.maze_elapsed=Run.respawn_delay(kind)-0.1
			run.combat.actors[id].hp=0
			run.combat.cooldown=100.0
			sm.data[Run.KEY]=run
			var visible:=Rect2(850,0,370,300)
			_check(Run.combat_tick(sm,Roads.SPAWN,0.05,visible).success and Run.snapshot(sm).monsters[id].status=="captured","冷却前不刷新："+kind)
			_check(Run.combat_tick(sm,Roads.SPAWN,0.1,Rect2(Vector2.ZERO,Roads.SIZE)).success and Run.snapshot(sm).monsters[id].status=="captured","到期但全图可见仍延后："+kind)
			var rng_before: String=Run.snapshot(sm).spawn_rng_state
			_check(Run.combat_tick(sm,Roads.SPAWN,0.05,Rect2(Vector2.ZERO,Roads.SIZE)).success and Run.snapshot(sm).spawn_rng_state==rng_before,"无安全点不消耗随机："+kind)
			run=Run.snapshot(sm)
			var probe:=run.duplicate(true)
			_check(Run.refresh_due(probe,Roads.SPAWN,visible),"存在安全候选："+kind)
			var spawn: Vector2=Run.monster_for(probe,id).position
			# 有意把上一生命弹道的轨迹落点设为下一出生点，验证生命编号隔离。
			run.combat.shots=[{"origin":Combat.pack(spawn),"target":Combat.pack(spawn),"position":Combat.pack(spawn),"time":0.0,"lives":Combat.life_ids(run)}]
			sm.data[Run.KEY]=run
			_check(Run.combat_tick(sm,Roads.SPAWN,0.05,visible).success,"镜头移开后刷新："+kind)
			run=Run.snapshot(sm)
			_check(run.monsters[id].refresh_count==1 and run.combat.actors[id].hp==Combat.STATS[kind].hp,"旧弹道不能伤害新生命："+kind)
			_check(run.combat.actors.size()==10 and run.monsters.size()==10 and run.layout.size()==10,"刷新维持十槽位："+kind)
			for generation in range(2,5):
				run.monsters[id].status="failed"
				run.monsters[id].respawn_at=run.maze_elapsed
				run.combat.actors[id].hp=0
				sm.data[Run.KEY]=run
				_check(Run.combat_tick(sm,Roads.SPAWN,0.05,visible).success,"连续生命周期刷新："+kind)
				run=Run.snapshot(sm)
				_check(run.monsters[id].refresh_count==generation and run.combat.actors[id].hp==Combat.STATS[kind].hp and Run.valid(run),"连续刷新保持合法满血十槽位："+kind)
		var damaged:=initial.duplicate(true)
		damaged.layout[0].position=["bad",0]
		_check(not Run.valid(damaged),"损坏布局字段拒绝")
		damaged=initial.duplicate(true); damaged.spawn_rng_state="bad"
		_check(not Run.valid(damaged),"损坏随机源拒绝")
		damaged=initial.duplicate(true); damaged.maze_elapsed=-1
		_check(not Run.valid(damaged),"损坏运行时间拒绝")
		damaged=initial.duplicate(true); damaged.combat.actors.erase("slime_1")
		_check(not Run.valid(damaged),"缺actor拒绝而非隐藏节点")
		sm.data[Run.KEY]=initial
		var before: Dictionary=sm.data.duplicate(true)
		_check(not Run.combat_tick(sm,Roads.SPAWN,-1.0).success and sm.data==before,"负计时拒绝")
		_check(not Run.combat_tick(sm,Roads.SPAWN,100.0).success and sm.data==before,"大跨度计时拒绝")
		# 缺少run及combat布局的COMBAT-02档使用原固定顺序；已有状态完整保留。
		var fixed:=initial.duplicate(true)
		fixed.erase("layout"); fixed.combat=Combat.create(3,36,Roads.SPAWN)
		fixed.combat.erase("layout"); fixed.monsters={}
		for row in Catalog.all():
			fixed.monsters[row.id]={"status":"alive","capture_roll":0.1,"drop_roll":0.2,"copy_roll":0.3,"extra_roll":0.4,"guaranteed":false}
		fixed.monsters.slime_1.status="captured"
		fixed.combat.actors.slime_1.hp=0
		sm.data[Run.KEY]=fixed
		_check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).layout.size()==10,"旧新战斗档双缺布局补固定现状")
		_check(Run.snapshot(sm).monsters.slime_1.status=="captured" and Run.snapshot(sm).monsters.slime_1.respawn_at==float(fixed.maze_elapsed)+60.0,"旧战斗档已结算生命补完整冷却而非立即复活")
		var legacy:=fixed.duplicate(true); legacy.erase("combat")
		sm.data[Run.KEY]=legacy
		before=sm.data.duplicate(true)
		_check(Run.begin(sm,Roads.SPAWN).get("reason","")=="unsupported_combat_version" and sm.data==before,"旧战力档明确拒绝且不删除")
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
