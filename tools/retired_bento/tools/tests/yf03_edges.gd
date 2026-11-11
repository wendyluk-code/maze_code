extends "res://tools/tests/maze_capture.gd"
const Bento=preload("res://scripts/restaurant/bento_store.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"正式存档隔离")
	if failures==0: await _edges_bento()
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _edges_bento() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"建立实际探索")
	_check(Bento.snapshot(sm)==Bento.empty() and not Bento.unlocked(sm),"旧档无字段只读空便当")
	sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0})
	var before: Dictionary=sm.data.duplicate(true)
	var path: String=sm._active_save_path
	sm._active_save_path="user://nonexistent_parent/save.json"
	_check(not Bento.grant(sm).success and sm.data==before,"真实文件写失败赠礼食谱阶段全量回滚")
	sm._active_save_path=path
	_check(Bento.grant(sm).success,"赠礼一次提交")
	_check(Bento.snapshot(sm).slots.size()==3,"每维度一份三星")
	var given: Dictionary=sm.data.duplicate(true)
	_check(Bento.grant(sm).success and sm.data==given,"重复赠礼无额外保存及发奖")
	sm.set_yufeng_salia_record({"version":2,"phase":"bento_unlock","line":0})
	before=sm.data.duplicate(true)
	sm._active_save_path="user://nonexistent_parent/save.json"
	_check(not Bento.reveal(sm).success and sm.data==before,"解锁保存失败回滚入口资格")
	sm._active_save_path=path
	_check(Bento.reveal(sm).success,"持久化解锁资格")
	sm.set_yufeng_salia_record({"version":2,"phase":"done","line":0})
	before=sm.data.duplicate(true)
	sm.data[sm.MAZE_STATE_KEY].region="restaurant"
	_check(not Bento.eat(sm).success,"餐厅拒绝食用")
	sm.data=before.duplicate(true)
	sm.data[Run.KEY].combat.actors.slime_1.mode="chase"
	_check(not Bento.eat(sm).success,"真实追逐战斗拒绝食用")
	sm.data=before.duplicate(true)
	sm._active_save_path="user://nonexistent_parent/save.json"
	_check(not Bento.eat(sm).success and sm.data==before,"全部食用保存失败所有格与效果回滚")
	sm._active_save_path=path
	var base: Dictionary=sm.data.duplicate(true)
	# 真实模拟的近战与弹丸各一次；小数生命不得在受击时被截掉。
	var fractional: Dictionary=Run.snapshot(sm)
	for monster in fractional.monsters.values(): monster.status="skipped"
	var target: Dictionary=Run.monsters_for(fractional)[0]
	var point: Vector2=target.position
	fractional.monsters[target.id].status="alive"
	fractional.combat.actors[target.id].position=Run.Combat.pack(point)
	fractional.combat.actors[target.id].mode="windup"
	fractional.combat.actors[target.id].windup=0.001
	fractional.combat.hp=10.375
	var expected: float=10.375-Run.Combat.Skills.incoming_damage(fractional,int(Run.Combat.STATS[target.kind].attack))
	Run.Combat.advance(fractional,point,0.01,false)
	_check(absf(fractional.combat.hp-expected)<0.000001,"实际近战扣血保留0.375小数")
	for monster in fractional.monsters.values(): monster.status="skipped"
	fractional.combat.hp=10.375
	fractional.combat.enemy_shots=[{"position":Run.Combat.pack(point-Vector2(1,0)),"direction":[1.0,0.0],"distance":0.0,"source":"slime_1"}]
	expected=10.375-Run.Combat.Skills.incoming_damage(fractional,3)
	Run.Combat.Skills.advance(fractional,point,0.01)
	_check(absf(fractional.combat.hp-expected)<0.000001,"实际弹丸扣血保留0.375小数")
	for star in [1,2,3]:
		sm.data=base.duplicate(true)
		for slot in sm.data[Bento.KEY].slots: sm.data[Bento.KEY].slots[slot].stars=star
		sm.data[Run.KEY].combat.hp=1.0
		var attack: float=sm.data[Run.KEY].combat.attack
		var defense: int=Run.Combat.Skills.defense(sm.data[Run.KEY])
		_check(Bento.eat(sm).success,"一事务全吃星级%d"%star)
		var run: Dictionary=Run.snapshot(sm)
		_check(run.combat.attack==attack+star,"团队攻击只加一次星级%d"%star)
		_check(Run.Combat.Skills.incoming_damage(run,20)==maxi(0,20-defense-(2 if star==3 else 1)),"实际受伤公式防御星级%d"%star)
		run.combat.cooldown=0
		_check(Run.Combat.Skills.attack(run,Roads.SPAWN,Vector2.RIGHT),"实际发射技能")
		_check(run.combat.shots.back().damage==roundi(attack+star),"实际弹道攻击伤害")
		var impact: Dictionary=run.duplicate(true)
		for monster in impact.monsters.values(): monster.status="skipped"
		impact.monsters.slime_1.status="alive"
		var hit_point: Vector2=Run.monster_for(impact,"slime_1").position
		impact.combat.actors.slime_1.position=Run.Combat.pack(hit_point)
		impact.combat.shots.clear()
		impact.combat.cooldown=0.0
		impact.combat.action_left=0.0
		var enemy_hp: float=impact.combat.actors.slime_1.hp
		Run.Combat.Skills.attack(impact,hit_point,Vector2.RIGHT)
		Run.Combat.advance(impact,hit_point,0.05,false)
		_check(impact.combat.actors.slime_1.hp==maxf(0,enemy_hp-roundi(attack+star)),"真实弹道命中按加成后伤害扣敌血")
		var total: float=run.combat.max_hp*float(star)/10.0
		for i in 400: Bento.advance(run,0.05)
		_check(absf(run.combat.hp-minf(run.combat.max_hp,1.0+total))<0.000001,"20秒累计百分比不丢小数星级%d"%star)
		var hp: float=run.combat.hp
		Bento.advance(run,100)
		_check(run.combat.hp==hp,"完成不重复回血")
		var capped: Dictionary=Run.snapshot(sm)
		capped.combat.hp=capped.combat.max_hp-0.1
		Bento.advance(capped,20.0)
		_check(capped.combat.hp==capped.combat.max_hp,"百分比回血不超过团队上限")
	sm.data=base.duplicate(true)
	sm.data[Run.KEY].combat.hp=1.0
	_check(Bento.eat(sm,"health").success,"单份生命料理")
	var run: Dictionary=Run.snapshot(sm)
	_check(not Bento.discard(sm,"health").success,"已食格不可清空")
	_check(Bento.discard(sm,"defense").success and not Bento.snapshot(sm).slots.has("defense"),"未食用丢弃真实保存")
	_check(Run.change_region(sm,"fenshui",Vector2(1300,325)).success,"同趟换图")
	for i in 33: _check(Run.combat_tick(sm,Vector2(1300,325),0.1).success,"有效游戏时间推进")
	var paid: Dictionary=Run.snapshot(sm).bento.duplicate(true)
	var saved_hp: float=Run.snapshot(sm).combat.hp
	_check(sm.save(),"回血中保存")
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm).bento,paid) and absf(Run.snapshot(sm).combat.hp-saved_hp)<0.000001,"读档保留剩余秒数与累计量，无离线恢复")
	before=sm.data.duplicate(true)
	sm._active_save_path="user://nonexistent_parent/save.json"
	_check(not Run.combat_tick(sm,Vector2(1300,325),0.1).success and sm.data==before,"回血保存失败同时回滚时间和生命")
	sm._active_save_path=path
	_check(Run.finish(sm,true,sm.maze_terrain("fenshui").ENTRANCE).success,"真实结束探索")
	_check(Bento.snapshot(sm).slots.has("attack") and not Bento.snapshot(sm).slots.has("health"),"结束保留未食用清空已食用")
	for corrupt in [{"bento":{}},{"bento":{},"combat":false},{"bento":{},"combat":{}},{"bento":{"attack":0,"defense":0,"heal_total":0,"heal_elapsed":0,"heal_paid":0},"combat":{"max_hp":"broken"}}]:
		_check(not Run.valid(corrupt),"坏run结构安全拒绝，无脚本异常")
	for corrupt in [false,{}, {"version":1,"granted":true,"unlocked":true,"slots":{"health":{"id":"cool_slime_jelly","stars":99,"eaten":false}}}]:
		sm.data[Bento.KEY]=corrupt
		_check(Bento.snapshot(sm).is_empty() and not Bento.grant(sm).success,"坏便当拒绝补发")
	sm.data=base.duplicate(true)
	sm.data[Bento.KEY]=false
	sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"gift_reward","line":0}
	sm.record_maze_location("fenshui",Vector2(1300,325))
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	_check(maze.yf_encounter._gift_invalid and not maze.yf_encounter.gift_modal.visible and maze.yf_encounter.phase=="gift_reward","已领奖阶段坏记录不假弹窗不提前done")
	maze.queue_free()
	await get_tree().process_frame
