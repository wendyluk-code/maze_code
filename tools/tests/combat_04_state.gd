extends "res://tools/tests/maze_capture.gd"
const Progression = preload("res://scripts/characters/character_progression.gd")
const Combat = preload("res://scripts/maze/combat_simulation.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0: _cases()
	_report()

func _report() -> void:
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _setup(party: Array = ["yaya","tieshan"]) -> void:
	_completed(); sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(sm.request_maze_entry(party).success,"选择出战成员")
	_check(Run.begin(sm,Roads.SPAWN).success,"建立新趟")

# 受控致死弹道，仍调用正式模拟器与保存事务；真实自动战斗另由flow覆盖。
func _shot(id: String) -> void:
	var run: Dictionary=sm.data[Run.KEY]
	for other in run.monsters:
		if other!=id:
			run.monsters[other].status="skipped"; run.monsters[other].respawn_at=99999.0
	var point: Vector2=Run.monster_for(run,id).position
	var actor: Dictionary=run.combat.actors[id]
	actor.position=Combat.pack(point); actor.hp=1; actor.mode="idle"
	run.monsters[id].status="alive"
	run.combat.shots=[{"origin":Combat.pack(point),"target":Combat.pack(point),"position":Combat.pack(point),"time":0.0,"lives":Combat.life_ids(run)}]

func _exp(id: String) -> int: return int(Progression.record(sm,id).exp)

func _cases() -> void:
	for pair in [["slime_1",20],["snail_1",35],["beetle_1",35],["lizard_1",150]]:
		_setup(); _shot(pair[0])
		var before: Dictionary=sm.data.duplicate(true)
		var path: String=sm._active_save_path
		sm._active_save_path=""
		_check(not Run.combat_tick(sm,Roads.SPAWN,0.05).success and sm.data==before,"致死保存失败经验生命位置完整回滚："+pair[0])
		sm._active_save_path=path
		_check(Run.combat_tick(sm,Roads.SPAWN,0.05).success,"真正命中致死提交："+pair[0])
		_check(_exp("yaya")==pair[1] and _exp("tieshan")==pair[1],"每个出战成员全额经验："+pair[0])
		_check(Run.snapshot(sm).pending=="" and Run.snapshot(sm).monsters[pair[0]].experience_generation==0,"打开捕获前已有生命回执与经验")
		_check(Run.defeat(sm,pair[0],Roads.SPAWN).success and Run.resolve(sm,pair[0],false).success,"放弃捕获正常提交")
		sm.load_data()
		_check(_exp("yaya")==pair[1] and not Run.defeat(sm,pair[0],Roads.SPAWN).success,"读档重复结算不重发")
		_check(Run.finish(sm,false,Roads.SPAWN).success and _exp("yaya")==pair[1],"不带材料离场保留经验")
	_setup(["yaya"]); _shot("slime_1")
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05).success and _exp("yaya")==20 and _exp("tieshan")==0,"非出战者无经验")
	# 两条致死弹道同帧，不等待捕获队列打开。
	_setup(); _shot("slime_1")
	var run: Dictionary=sm.data[Run.KEY]
	var point: Vector2=Run.monster_for(run,"slime_2").position
	run.monsters.slime_2.status="alive"; run.combat.actors.slime_2.hp=1
	run.combat.shots.append({"origin":Combat.pack(point),"target":Combat.pack(point),"position":Combat.pack(point),"time":0.0,"lives":Combat.life_ids(run)})
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05).success and _exp("yaya")==40 and _exp("tieshan")==40,"同帧两怪各发全额经验")
	_check(Run.defeat(sm,"slime_1",Roads.SPAWN).success and _exp("yaya")==40,"第一只捕获窗口不改变第二只经验")
	Run.resolve(sm,"slime_1",false); Run.defeat(sm,"slime_2",Roads.SPAWN); Run.resolve(sm,"slime_2",false)
	_check(_exp("yaya")==40,"依次处理捕获不重复经验")
	_setup(); _shot("slime_1")
	run=sm.data[Run.KEY]
	run.combat.hp=1
	run.monsters.snail_1.status="alive"
	var death_point: Vector2=Run.monster_for(run,"snail_1").position
	run.combat.actors.snail_1.position=Combat.pack(death_point)
	run.combat.actors.snail_1.mode="windup"; run.combat.actors.snail_1.windup=0.01
	_check(Run.combat_tick(sm,death_point,0.05).success and Run.snapshot(sm).combat.hp==0 and _exp("yaya")==0 and Run.snapshot(sm).combat.actors.slime_1.hp==1,"主角死亡优先，不为未完成击杀发经验")
	_growth_cases()

func _growth_cases() -> void:
	_setup()
	sm.data[Progression.KEY]={}
	for id in ["yaya","tieshan"]:
		sm.data[Progression.KEY][id]={"level":1,"exp":499,"rank":1,"breakthroughs":0}
	_check(Progression.grant_experience(sm,["yaya","tieshan"],1).success,"精确升级阈值")
	_check(Progression.record(sm,"yaya").level==2 and _exp("yaya")==0 and Progression.record(sm,"yaya").attack==2 and Progression.record(sm,"tieshan").health==28,"升级公式复用唯一源")
	_check(Progression.grant_experience(sm,["yaya"],2100).success and Progression.record(sm,"yaya").level==5 and _exp("yaya")==0,"跨多级到突破丢弃剩余经验")
	for level in [5,10,15,20,25]:
		sm.data[Progression.KEY].yaya={"level":level,"exp":0,"rank":1,"breakthroughs":level/5-1}
		_check(Progression.grant_experience(sm,["yaya"],9999).success and Progression.record(sm,"yaya").valid and _exp("yaya")==0,"未突破门槛无经验银行：%d"%level)
		sm.data[sm.MAZE_STATE_KEY].region="restaurant"; sm.data.gold=10000
		var gold: int=sm.gold_balance()
		_check(Progression.breakthrough(sm,"yaya").success and sm.gold_balance()==gold-Progression.COSTS[level],"沿用金币突破：%d"%level)
		_check(Progression.grant_experience(sm,["yaya"],Progression.experience_required(level)).success and Progression.record(sm,"yaya").level==level+1,"突破后可升级：%d"%level)
	sm.data[Progression.KEY].yaya={"level":29,"exp":3290,"rank":1,"breakthroughs":5}
	_check(Progression.grant_experience(sm,["yaya"],150).success and Progression.record(sm,"yaya").level==30 and _exp("yaya")==0,"满级清零经验")
	_check(Progression.grant_experience(sm,["yaya"],150).success and _exp("yaya")==0,"满级不积累")
	_check(Run.team_power(100,[{"id":"tieshan","rank":6,"element":"earth"},{"id":"a","element":"earth"},{"id":"b","element":"earth"},{"id":"c","element":"earth"}])==128,"铁山六阶比例与取整保留")
	_setup(); _shot("slime_1")
	sm.data[Progression.KEY]="invalid"
	var corrupt: Dictionary=sm.data.duplicate(true)
	_check(not Run.combat_tick(sm,Roads.SPAWN,0.05).success and sm.data==corrupt,"损坏角色记录拒绝击杀事务且整体回滚")
