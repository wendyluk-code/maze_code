extends "res://tools/tests/maze_capture.gd"
const Sim = preload("res://scripts/maze/yf_sparring.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_completed()
		sm.cancel_maze_entry()
		sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
		_check(Run.begin(sm,Roads.SPAWN).success,"新探索真实队伍")
		sm.record_maze_location("fenshui",Vector2(1300,325))
		var original: Dictionary=Run.snapshot(sm)
		for old in ["unseen","intro_pending","awaiting_battle"]:
			sm.data[sm.YUFENG_SALIA_KEY]=old
			_check(sm.yufeng_salia_state()==("unseen" if old=="unseen" else "intro"),"旧状态不误作完成："+old)
		var prior: Dictionary=sm.data.duplicate(true)
		_check(not sm.set_yufeng_salia_record({"version":2,"phase":"intro","line":99}).success and sm.data==prior,"非法句号拒绝不改档")
		var path: String=sm._active_save_path
		sm._active_save_path=""
		_check(not sm.set_yufeng_salia_record({"version":2,"phase":"gift_pending","line":0}).success and sm.data==prior,"赠礼待处理保存失败回滚")
		sm._active_save_path=path
		for phase in ["intro","eat","question","battle","post","gift_pending"]:
			var record: Dictionary={"version":2,"phase":phase,"line":2 if phase in ["intro","post"] else 0}
			if phase=="battle":
				record.start_run=original
				record.start_position=[1300,325]
			_check(sm.set_yufeng_salia_record(record).success,"写入恢复检查点："+phase)
			sm.load_data()
			await _open_saved()
			var e=maze.yf_encounter
			_check(e.phase==phase,"真实场景恢复："+phase)
			if phase in ["intro","post"]: _check(e.record.line==2 and e.dialog.visible,"对白恢复当前句："+phase)
			if phase=="battle":
				_check(e.run.combat.hp==original.combat.hp and e.run.combat.actors.yufeng.hp==18,"退出战斗从开战前恢复双方")
				maze.capture_flow._open_character_details("yaya")
				var elapsed: float=e.run.combat.elapsed
				await get_tree().create_timer(0.15).timeout
				_check(e.run.combat.elapsed==elapsed,"角色详情弹窗暂停切磋")
				maze.capture_flow._close_character_details()
				e.run.combat.hp=1
				for a in e.run.combat.actors.values(): a.cooldown=10
				e.run.combat.enemy_shots=[{"source":"salia","position":[1300,325],"direction":[1,0],"distance":0}]
				await get_tree().create_timer(0.15).timeout
				_check(e.run.combat.hp==0 and not maze.capture_flow.death_presented and not maze.capture_flow.dialog.visible,"玩家先归零不走探索失败")
				await get_tree().create_timer(2.7).timeout
				sm._active_save_path=""
				await get_tree().create_timer(0.7).timeout
				_check(e.phase=="battle" and sm.yufeng_salia_state()=="battle","战后阶段保存失败保持切磋不假推进")
				sm._active_save_path=path
				await get_tree().create_timer(1.3).timeout
				_check(e.phase=="post" and Run.snapshot(sm).combat.hp==original.combat.hp,"玩家败北同样进入战后并恢复队伍生命")
			if phase=="gift_pending":
				_check(not maze.player.input_locked,"待赠礼正常探索输入")
				var point: Vector2=maze.player.position
				Input.action_press("ui_right")
				await get_tree().create_timer(0.2).timeout
				Input.action_release("ui_right")
				_check(maze.player.position.distance_to(point)>1,"待赠礼真实移动恢复")
			maze.queue_free()
			await get_tree().process_frame
		_rules(original)
	var f:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _open_saved() -> void:
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().process_frame
	maze.capture_flow.window_focused=true

func _rules(original: Dictionary) -> void:
	var run: Dictionary=Sim.create(original)
	var point:=Vector2(1000,450)
	var candidates: Dictionary={"hero":point,"a":point+Vector2(20,0),"b":point+Vector2(40,0),"c":point+Vector2(60,0),"d":point+Vector2(80,0),"far":point+Vector2(500,0)}
	var hits:=Sim.chain_hits(point,candidates,"hero",4)
	_check(hits.size()==3,"同水域最多额外三目标")
	for hit in hits: _check(hit.id!="hero" and hit.damage==2.4,"连锁60%且不重复主目标")
	_check(Sim.conduction(Vector2(1214,352),candidates,"hero").is_empty(),"岸上命中不传导")
	_check(Sim.conduction(point,{"blocked":Vector2(1000,300)},"hero").is_empty(),"不跨岛岸与超距离传导")
	# 跟踪弹转向目标；同帧风刃连击只触发一套控制，伤害仍可重复。
	run.combat.enemy_shots=[{"source":"salia","position":[1010,450],"direction":[1,0],"distance":0}]
	Sim.advance(run,Vector2(1040,470),0.01,false)
	_check(Sim.Skills.vec(run.combat.enemy_shots[0].direction).y>0,"雷球追踪改变飞行方向")
	run=Sim.create(original)
	run.combat.enemy_shots=[{"source":"yufeng","position":[1000,450],"direction":[1,0],"distance":0}]
	Sim.advance(run,point,0.01,false)
	_check(run.combat.control_left==0.3 and run.combat.control_reuse==2,"风刃命中触发三段控制与两秒免控")
	run.combat.control_left=0.1
	run.combat.enemy_shots=[{"source":"yufeng","position":[1000,450],"direction":[1,0],"distance":0}]
	Sim.advance(run,point,0.01,false)
	_check(run.combat.control_left<0.11,"两秒内命中不重置控制")
	var moves: Array=[]
	var pulses:=0
	var lit:=false
	run=Sim.create(original)
	run.combat.control_left=0.3
	run.combat.control_direction=[1,0]
	for i in 30:
		var previous_point := point
		point=Sim.advance(run,point,0.01,false)
		moves.append(point.distance_to(previous_point))
		var now: bool=run.combat.flash_remaining>0
		if now and not lit: pulses+=1
		lit=now
	_check(pulses==3,"三段实际三次白闪")
	for segment in 3:
		var distance := 0.0
		for index in range(segment*10,segment*10+10): distance+=moves[index]
		_check(absf(distance-12)<0.01 and moves[segment*10+7]<0.001 and moves[segment*10+8]<0.001,"第%d段独立12像素后可辨识停顿" % (segment+1))
	run=Sim.create(original)
	Sim.hurt(run,"yufeng",1000)
	var frozen: float=run.combat.actors.yufeng.hp
	_check(Sim.attack(run,Vector2(1300,325),Vector2.LEFT),"锁血三秒期间允许攻击")
	Sim.advance(run,Vector2(1300,325),0.05,false)
	_check(not run.combat.shots.is_empty() and run.combat.shots[0].time>0,"锁血期间真实弹道继续")
	Sim.hurt(run,"yufeng",100)
	_check(run.combat.actors.yufeng.hp==frozen,"继续对打但NPC生命锁住")

	run.combat.hp=0
	run.combat.enemy_shots=[{"source":"salia","position":[1000,450],"direction":[1,0],"distance":0}]
	Sim.advance(run,Vector2(1040,470),0.01,false)
	_check(run.combat.enemy_shots.is_empty(),"追踪目标失效后雷球消散")

	run=Sim.create(original)
	for i in 100: Sim.advance(run,Vector2(1000,450),0.01,true)
	_check(absf(run.combat.sprint-0.8)<0.001,"沿用普通加速5秒耗尽")
	for i in 100: Sim.advance(run,Vector2(1000,450),0.01,false)
	_check(absf(run.combat.sprint-0.8)<0.001,"停下1秒才恢复")
	for i in 100: Sim.advance(run,Vector2(1000,450),0.01,false)
	_check(absf(run.combat.sprint-0.925)<0.001,"沿用8秒恢复速率")
