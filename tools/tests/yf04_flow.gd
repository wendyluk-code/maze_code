extends "res://tools/tests/yf03_flow.gd"
const Sim = preload("res://scripts/maze/yf_sparring.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"正式存档隔离")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size=resolution
		suffix="_%dx%d" % [resolution.x,resolution.y]
		await encounter_flow()
		await _bento_flow()
	await legacy_phases()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func setup_trip(hp: float) -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	_check(Run.begin(sm,Roads.SPAWN).success,"真实出征")
	sm._state[Run.KEY].combat.hp=hp
	sm.record_maze_location("fenshui",Sim.Terrain.SPAWN)
	sm.save()

func open_map() -> void:
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	maze.capture_flow.window_focused=true
	maze.yf_encounter._sync_visuals()

func encounter_flow() -> void:
	setup_trip(18.0)
	await open_map()
	var e=maze.yf_encounter
	_check(e.phase=="unseen" and e.idle.visible and e.idle.is_playing() and not e.actors.yufeng.visible and not e.actors.salia.visible,"初次播放双人聊天而非独立待机")
	await _capture_image("before_approach")
	maze.player.position=Vector2(1514,241)
	await get_tree().create_timer(0.2).timeout
	_check(e.phase=="intro" and not e.idle.visible and e.actors.salia.visible,"靠近停止密谋改独立待机")
	_check(e.actors.yufeng.scale.y*e.actors.yufeng.region_rect.size.y<90,"角色与白虎爷爷同量级")
	await _capture_image("dialog_salia")
	await _send_key(KEY_E)
	await _send_key(KEY_E)
	await _capture_image("dialog_yufeng")
	for i in 7:
		await _send_key(KEY_E)
		await _send_key(KEY_E)
	_check(e.phase=="battle","八句对白直接战斗，无吃料理及疑问")
	if e.phase!="battle":
		maze.queue_free()
		await get_tree().process_frame
		return
	_check(e.run.combat.start_hp==18 and is_equal_approx(e.run.combat.stop_hp,3.6),"当前剩余生命20%，开战不回血")
	# 核验对手半血不结束；低血开场也绝不被超额伤害打死。
	for health in [1.0,5.0,18.0]:
		var source: Dictionary=Run.snapshot(sm)
		source.combat.hp=health
		var sample := Sim.create(source)
		Sim.hurt(sample,"yufeng",10000)
		_check(sample.combat.lock_left==-1 and sample.combat.actors.yufeng.hp==1,"对手生命不触发剧情")
		var point := Vector2(1295,317)
		sample.combat.enemy_shots=[{"position":Sim.Skills.pack(point),"direction":[1.0,0.0],"distance":0.0,"source":"salia"}]
		sample.combat.actors.salia.attack=10000
		Sim.advance(sample,point,0.01,false)
		_check(is_equal_approx(sample.combat.hp,health*0.2) and sample.combat.lock_left==0,"低血/越阈值一击精确停止在20%")
		_check(not Sim.attack(sample,point,Vector2.RIGHT),"结束后不能继续攻击")
	# 实际追击并绕过岛边；不是移动显示替身。
	maze.player.position=Vector2(1640,180)
	var origin := Sim.Skills.vec(e.run.combat.actors.yufeng.position)
	await get_tree().create_timer(1.5).timeout
	var moved := Sim.Skills.vec(e.run.combat.actors.yufeng.position)
	_check(moved.distance_to(origin)>20 and Sim.Terrain.is_walkable(moved),"御风真实追击且不穿障碍")
	_check(Sim.Skills.vec(e.run.combat.actors.salia.position).distance_to(Sim.POSITIONS.salia)>10,"萨莉亚真实追击")
	await _capture_image("chase")
	# 退出重进恢复开战前剩余血基准。
	maze.queue_free()
	await get_tree().process_frame
	sm.load_data()
	await open_map()
	e=maze.yf_encounter
	_check(e.phase=="battle" and e.run.combat.start_hp==18,"切磋退出重进保留开战血基准")
	var deadline := Time.get_ticks_msec()+25000
	var saw_black := false
	while e.phase=="battle" and Time.get_ticks_msec()<deadline:
		if e.curtain.color.a>0.8: saw_black=true
		await get_tree().process_frame
	_check(e.phase=="post" and (saw_black or e.curtain.color.a>0.8),"真实追击弹道打至20%黑屏进入战后")
	_check(is_equal_approx(e.run.combat.hp,3.6),"实际停战生命为3.6，未先回满")
	_check(Run.snapshot(sm).combat.hp==18,"切磋结束恢复开战前生命")
	await get_tree().create_timer(0.4).timeout
	await _capture_image("post")
	if e.phase=="post":
		var actual_position: Vector2=maze.player.position
		for side in [-1,1]:
			maze.player.position=Vector2(1100 if side<0 else 1750,actual_position.y)
			e.attention=Vector2(1750 if side<0 else 1100,actual_position.y)
			e._sync_visuals()
			for id in ["yufeng","salia"]:
				_check(e.actors[id].flip_h==(maze.player.position.x<e.actors[id].position.x),"战后"+id+"面向主角当前位置，不使用开战旧位置")
		maze.player.position=actual_position
		e._sync_visuals()
		sm.save()
		maze.queue_free()
		await get_tree().process_frame
		sm.load_data()
		await open_map()
		e=maze.yf_encounter
		_check(e.phase=="post" and e.dialog.visible,"战后读档恢复对白")
		for id in ["yufeng","salia"]:
			_check(e.actors[id].flip_h==(maze.player.position.x<e.actors[id].position.x),"战后读档"+id+"面向主角")
		await _capture_image("post_reloaded_facing")
	if e.phase=="post":
		for i in 3:
			await _send_key(KEY_E)
			await _send_key(KEY_E)
		await get_tree().create_timer(0.2).timeout
		_check(e.phase=="gift_reward" and e.gift_modal.item_row_height==106,"战后接同白虎奖励弹窗")
		_check(e.gift_modal.item_views.all(func(v): return not v.name.text.contains("星")),"奖励不显示星级")
		_check(Bento.snapshot(sm).slots.values().all(func(v): return v.stars==3),"奖励数据仍为三星")
		await _capture_image("reward_no_stars")
	maze.queue_free()
	await get_tree().process_frame

func legacy_phases() -> void:
	for old_phase in ["eat","question"]:
		setup_trip(5.0)
		sm.set_yufeng_salia_record({"version":2,"phase":old_phase,"line":0})
		await open_map()
		_check(maze.yf_encounter.phase=="battle" and maze.yf_encounter.run.combat.start_hp==5,"旧阶段安全进入切磋："+old_phase)
		maze.queue_free()
		await get_tree().process_frame
