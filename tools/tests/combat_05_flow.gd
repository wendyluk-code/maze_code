extends "res://tools/tests/combat_02_flow.gd"

var traces: Array = []

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		get_window().size=Vector2i(1152,648)
		await _new_scene()
		maze.capture_flow.set_process(false)
		maze.player.set_physics_process(false)
		# 保存快照中的原始卡点；沿用生产出生点与脱战阈值。
		await _case("截图卡点返航",Vector2(790,326),Vector2(888.7483,287.625),"return",Vector2(270,720))
		await _case("截图路段向右追逐",Vector2(790,326),Vector2(933,269),"chase",Vector2(933,269),Vector2(790,326))
		await _case("截图路段向左追逐",Vector2(933,269),Vector2(790,326),"chase",Vector2(790,326),Vector2(790,326))
		await _case("多怪追逐",Vector2(725,369),Vector2(860,295),"chase",Vector2(860,295),Vector2(725,369),true)
		await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"traces":traces,"user_dir":OS.get_user_data_dir(),"save_path":ProjectSettings.globalize_path(sm._active_save_path)},"\t"))
	get_tree().quit(1 if failures else 0)

func _case(title: String, start: Vector2, hero: Vector2, mode: String, target: Vector2, home := Vector2(270,720), multi := false) -> void:
	var run: Dictionary=sm.data[Run.KEY]
	for row in run.layout:
		if row.kind=="lizard": row.position=Combat.pack(home)
	var rows := Catalog.all(Catalog.BALANCE_VERSION,run.layout)
	run.combat=Combat.create(3,36,hero,rows)
	run.combat.cooldown=10000.0
	for id in run.monsters:
		run.monsters[id].status="skipped"
		run.monsters[id].respawn_at=100000.0
	run.monsters.lizard_1.status="alive"
	run.combat.actors.lizard_1.position=Combat.pack(start)
	run.combat.actors.lizard_1.mode=mode
	run.combat.actors.lizard_1.hp=60
	if multi:
		for id in ["slime_1","beetle_1"]:
			run.monsters[id].status="alive"
			run.combat.actors[id].position=Combat.pack(start+Vector2(5,-3))
			run.combat.actors[id].mode="chase"
	maze.player.position=hero
	maze.camera.snap_to_target()
	_check(sm.save(),title+"：隔离夹具写盘")
	await _render_state()
	await _capture_image(title+"_before")
	var safe := true
	var committed := true
	var reached := false
	var trail: Array=[]
	for tick in 400:
		var before: Dictionary=Run.snapshot(sm).combat.actors
		committed=Run.combat_tick(sm,hero,0.05).success and committed
		var current: Dictionary=Run.snapshot(sm).combat
		for id in current.actors:
			if Run.snapshot(sm).monsters[id].status!="alive": continue
			safe=Combat.clear_line(Combat.vec(before[id].position),Combat.vec(current.actors[id].position),Roads.FOOT_RADIUS) and safe
		var actor: Dictionary=current.actors.lizard_1
		if tick%20==0: trail.append({"tick":tick,"position":actor.position,"mode":actor.mode})
		if mode=="return": reached=actor.mode=="idle" and Combat.vec(actor.position).distance_to(target)<2 and actor.hp==84
		else: reached=actor.mode=="windup" and Combat.vec(actor.position).distance_to(target)<=40
		if reached: break
	_check(committed,title+"：真实战斗事务推进成功")
	_check(reached,title+"：抵达/前摇或返家回血",{"trace":trail})
	_check(safe,title+"：所有活动怪物逐步不穿墙")
	traces.append({"case":title,"trace":trail})
	if multi:
		var actors: Dictionary=Run.snapshot(sm).combat.actors
		for id in ["slime_1","beetle_1"]:
			_check(Combat.vec(actors[id].position).distance_to(start)>20,title+"：独立移动 "+id)
	await _render_state()
	var monster=maze.capture_flow.monsters.lizard_1
	_check(not monster.body.flip_h,title+"：蜥蜴使用原方向帧，不再固定镜像")
	for frame in 4:
		monster._draw_frame(frame)
		var contact: Vector2=monster.ground_contacts[frame]
		_check(monster.shadow.position.distance_to((monster.body.offset+contact)*monster.body.scale+Vector2(0,-2))<0.01,title+"：方向帧脚底阴影帧%d" % frame)
	await _capture_image(title+"_after")
	var saved := Run.snapshot(sm)
	_check(sm.save(),title+"：结束状态保存")
	sm.load_data()
	var restored := Run.snapshot(sm)
	var differences := {}
	for key in saved:
		if not _same_saved(saved[key],restored.get(key)): differences[key]={"before":saved[key],"after":restored.get(key)}
	_check(differences.is_empty(),title+"：重载保持战斗状态",differences)

func _render_state() -> void:
	# 零增量同步真实场景显示；模拟仍只由上面的真实事务推进。
	maze.capture_flow._process(0.0)
	await get_tree().process_frame

func _same_saved(a: Variant, b: Variant) -> bool:
	# JSON 的十进制往返会舍入双精度尾数；位置/时钟允许百万分之一误差。
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not _same_saved(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not _same_saved(a[i],b[i]): return false
		return true
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:
		return absf(float(a)-float(b))<0.000001
	return a==b
