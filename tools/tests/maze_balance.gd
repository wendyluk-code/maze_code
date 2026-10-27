extends "res://tools/tests/maze_capture.gd"
const Progression := preload("res://scripts/characters/character_progression.gd")

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离存档")
	if failures == 0:
		_balance_state()
		await _legacy_scene()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _balanced_route()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("MAZE_BALANCE ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _balance_state() -> void:
	_completed()
	_check(Catalog.all().size() == 10, "新版10只怪物")
	for row in Catalog.all(): _check(Roads.is_walkable(row.position), "配置在道路上："+row.id)
	for level in [1,4,5,6,9,10,14,15,19,20,24,25,29,30]:
		for id in ["yaya","tieshan"]:
			sm.data[Progression.KEY] = {id:{"level":level,"exp":0,"rank":1,"breakthroughs":mini(5,floori((level-1)/5.0))}}
			var row := Progression.record(sm,id)
			_check(row.valid and row.satiety_max == (2 if id == "yaya" else 1)+floori(level/5.0), "%s等级%d饱腹边界" % [id,level])
	sm.data.erase(Progression.KEY)
	_check(Run.begin(sm,Roads.SPAWN).success, "新探索建立")
	_check(Run.snapshot(sm).base_power == 7 and Run.snapshot(sm).satiety == 3, "初始战力7饱腹3")
	var order := ["slime_1","slime_2","snail_1","slime_3","beetle_1","snail_2","beetle_3","snail_3","beetle_2","lizard_1"]
	for i in order.size():
		var row := Catalog.find(order[i])
		_check(Run.defeat(sm,row.id,row.position).success, "状态路线可胜："+row.id)
		# 强制失败也必须消耗捕获机会，验证3次是尝试数而非成功数。
		sm.data[Run.KEY].monsters[row.id].capture_roll = 0.99
		if i < 3:
			_check(Run.resolve(sm,row.id,true).success and Run.snapshot(sm).satiety == 2-i, "第%d次捕获消耗1" % [i+1])
		else:
			var before: Dictionary = sm.data.duplicate(true)
			var denied := Run.resolve(sm,row.id,true)
			_check(not denied.success and denied.reason == "hungry" and sm.data == before, "第4次起捕获拒绝且无副作用")
			_check(Run.resolve(sm,row.id,false).success, "无饱腹仍可放弃捕获前进")
	_check(sm.save(), "保存新版探索")
	sm.load_data()
	_check(Run.valid(Run.snapshot(sm)) and Run.snapshot(sm).satiety == 0 and Run.catalog_version(Run.snapshot(sm)) == 2, "读档保留新版及消耗")
	_check(Run.finish(sm,true,Roads.EXIT).success, "捕获资源出口入库")
	_check(sm.inventory_snapshot().get("slime_shell",0) >= 1, "首次保底产物未丢失")

func _legacy_scene() -> void:
	_completed()
	Run.begin(sm,Roads.SPAWN)
	var old: Dictionary = sm.data[Run.KEY]
	old.erase("catalog_version")
	old.base_power = 32
	old.satiety = 67
	old.satiety_max = 70
	old.absorbed = 8
	old.bag = {"slime_gel":2}
	old.monsters = {}
	for row in Catalog.all(1):
		old.monsters[row.id] = {"status":"alive","capture_roll":0.2,"drop_roll":0.2,"copy_roll":0.99,"extra_roll":0.99,"guaranteed":false}
	old.monsters.slime_1.status = "captured"
	sm.save()
	sm.load_data()
	var expected: Dictionary = Run.snapshot(sm)
	_check(Run.begin(sm,Roads.SPAWN).success and _same_saved(expected,Run.snapshot(sm)), "旧探索重入不重置战力饱腹暂存")
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.4).timeout
	_check(maze.capture_flow.monsters.size() == 13 and maze.capture_flow.monsters.slime_2.position == Vector2(860,295), "旧场景13只且位置不变")
	_check(maze.capture_flow.monsters.snail_1.config.power == 24 and not maze.capture_flow.monsters.slime_1.visible, "旧战力及已击败状态保留")
	_check(maze.capture_flow.hud.text.contains("67/70"), "旧饱腹显示保留")
	await _capture_image("legacy_preserved")
	maze.queue_free()
	await get_tree().process_frame
	_check(Run.finish(sm,true,Roads.EXIT).success and sm.inventory_snapshot().get("slime_gel",0) == 2, "旧探索出口入库不丢暂存")
	_check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).monsters.size() == 10 and Run.snapshot(sm).base_power == 7 and Run.snapshot(sm).satiety == 3, "旧探索结束下一趟启用新版")

func _gate(id: String, power: int) -> void:
	await get_tree().create_timer(0.3).timeout
	var flow = maze.capture_flow
	_check(flow.dialog.visible and not flow.dialog.victory and flow.current == id, "实际阻路："+id)
	_check(int(Run.snapshot(sm).base_power)+int(Run.snapshot(sm).absorbed) == power, "阻路时战力%d" % power)
	await _capture_image("blocked_"+id)
	if flow.dialog.visible:
		await _click(flow.dialog._confirm_button)
		await get_tree().process_frame

func _path(points: PackedVector2Array) -> bool:
	for point in points:
		if not await _walk_to(point): return false
	return true

func _balanced_route() -> void:
	_completed()
	sm.cancel_maze_entry()
	maze = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.4).timeout
	_check(maze.capture_flow.monsters.size() == 10, "实际场景10只")
	await _capture_image("start_7_power_3_food")
	var corridor: PackedVector2Array = Roads.roads()[0].points
	var ring: PackedVector2Array = Roads.roads()[1].points
	for i in range(2,corridor.size()):
		if not await _walk_to(corridor[i]): return
	# 第一次分叉：直接去东路会被30战力拦截。
	if not await _path(PackedVector2Array([Vector2(741,414),Vector2(755,448),Vector2(786,481)])): return
	await _gate("slime_3",13)
	if not await _path(PackedVector2Array([Vector2(755,448),Vector2(741,414),Vector2(688,396)])): return
	# 西路清两只后45战力，被80拦截。
	for i in range(1,12):
		if not await _walk_to(ring[i]): return
	await _gate("snail_2",45)
	for i in range(10,-1,-1):
		if not await _walk_to(ring[i]): return
	# 返东北打30、60，135战力遇180再次受阻。
	for i in range(ring.size()-2,23,-1):
		if not await _walk_to(ring[i]): return
	await _gate("beetle_2",135)
	for i in range(25,ring.size()):
		if not await _walk_to(ring[i]): return
	# 再回西侧，沿南路打80和90，初次可以选择跳过内环。
	for i in range(1,26):
		if not await _walk_to(ring[i]): return
	_check(Run.snapshot(sm).absorbed+7 == 485, "主环路线形成485战力")
	for i in range(24,14,-1):
		if not await _walk_to(ring[i]): return
	var inner: PackedVector2Array = Roads.roads()[3].points
	for point in inner:
		if not await _walk_to(point): return
	_check(Run.snapshot(sm).absorbed+7 == 605, "可选内环使战力达到605")
	for i in range(inner.size()-2,-1,-1):
		if not await _walk_to(inner[i]): return
	for i in range(14,7,-1):
		if not await _walk_to(ring[i]): return
	for point in Roads.roads()[2].points:
		if not await _walk_to(Roads.EXIT if point.x == 0 else point): return
	_check(Run.snapshot(sm).monsters.lizard_1.status == "skipped", "路线积累后击败450出口怪")
	_check(Run.snapshot(sm).satiety == 3, "仅战斗不捕获不扣饱腹")
	await _capture_image("balanced_exit")
	await _click(maze.exit_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	_check(sm.maze_exploration_state().region == "restaurant", "真实出口返回餐厅")
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
