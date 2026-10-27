extends "res://tools/tests/combat_07_flow.gd"

# 固定站位来自修复前真实场景复现；只隔离随机怪物布局与玩家存档。
const CASES = [
	{"label":"south_east", "origin":Vector2(983,1132), "target":Vector2(999,1171), "monster":"beetle_2"},
	{"label":"south_chest", "origin":Vector2(795,1170), "target":Vector2(824,1159), "monster":"snail_3"},
	{"label":"east_chest", "origin":Vector2(1081,678), "target":Vector2(1099,663), "monster":"beetle_1"}
]

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	_local_geometry()
	await _new_scene()
	maze.capture_flow.set_process(false)
	for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status = "skipped"
	for test in CASES:
		await _case(test)
	await _loot_checks()
	await _close_scene()
	var f = FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _walk(target: Vector2) -> void:
	var frames := 0
	while maze.player.position.distance_to(target)>2.5 and frames<240:
		maze.capture_flow.window_focused = true
		var direction: Vector2 = maze.player.position.direction_to(target)
		Input.action_press("ui_left", maxf(0,-direction.x))
		Input.action_press("ui_right", maxf(0,direction.x))
		Input.action_press("ui_up", maxf(0,-direction.y))
		Input.action_press("ui_down", maxf(0,direction.y))
		await get_tree().physics_frame
		frames += 1
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
	_check(maze.player.position.distance_to(target)<3, "真实输入进入/退出目标点", {"target":str(target),"actual":str(maze.player.position),"frames":frames})

func _case(test: Dictionary) -> void:
	maze.player.position = test.origin
	await _walk(test.target)
	_check(Roads.is_walkable(maze.player.position), "脚底仍在已有可走区")
	maze.camera.snap_to_target()
	await _capture_image(test.label+"_enter")
	var run: Dictionary = sm.data[Run.KEY]
	var kind: String = Catalog.find(test.monster).kind
	# 场景初始化可能迁移随机布局；同时固定出生点，避免夹具触发离家返航。
	var rows := Catalog.all(Catalog.BALANCE_VERSION, run.layout)
	for i in rows.size():
		if rows[i].id == test.monster:
			run.layout[i].position = Combat.pack(test.origin)
			run.combat.layout[i].position = Combat.pack(test.origin)
			run.monsters[test.monster].spawn_position = Combat.pack(test.origin)
	run.monsters[test.monster].status = "alive"
	run.combat.actors[test.monster] = Combat.fresh_actor(kind, test.origin)
	run.combat.hp = run.combat.max_hp
	Combat.clear_hit(run.combat)
	run.combat.hero = Combat.pack(maze.player.position)
	var hp: int = run.combat.hp
	maze.capture_flow.set_process(true)
	var samples: Array = []
	for i in 100:
		maze.capture_flow.window_focused = true
		await get_tree().create_timer(0.05).timeout
		if i%10==0: samples.append(sm.data[Run.KEY].combat.actors[test.monster].position.duplicate())
	_check(sm.data[Run.KEY].combat.hp < hp, "边缘站位追击能造成伤害："+test.label, {"target":str(test.target),"hp_before":hp,"hp_after":sm.data[Run.KEY].combat.hp,"samples":samples})
	await _capture_image(test.label+"_hit")
	maze.capture_flow.set_process(false)
	sm.data[Run.KEY].monsters[test.monster].status = "skipped"
	Combat.clear_hit(sm.data[Run.KEY].combat)
	await _walk(test.origin)
	await _capture_image(test.label+"_exit")

func _local_geometry() -> void:
	# 只回归本票相邻环路、内支路和栅栏；旧测试的地图边缘出口已被石阵替代。
	for index in [1,3,4]:
		var points: PackedVector2Array = Roads.roads()[index].points
		for i in range(points.size()-1):
			var actual := Roads.move_on_road(points[i],points[i+1]-points[i])
			_check(actual.distance_to(points[i+1])<0.1, "相邻道路连续可走", {"from":str(points[i]),"to":str(points[i+1]),"actual":str(actual)})
	for point in [Vector2(960,817),Vector2(727,791),Vector2(450,902),Vector2(654,1110),Vector2(622,1100),Vector2(682,1103)]:
		_check(not Roads.is_walkable(point) and not Combat.walkable(point), "沟壑树林与栅栏仍阻挡", {"point":str(point)})
	for pair in [[Vector2(527,544),Vector2(1086,755)],[Vector2(633,851),Vector2(1134,869)],[Vector2(653,1064),Vector2(650,1160)]]:
		_check(not Combat.clear_line(pair[0],pair[1],Roads.FOOT_RADIUS), "追击不能直穿障碍")

func _loot_checks() -> void:
	# 从已复现拐角沿相邻道路走到南侧挖掘点，并通过真实 E 领取。
	maze.player.position = Vector2(999,1171)
	for point in [Vector2(965,1181),Vector2(923,1208)]: await _walk(point)
	await get_tree().process_frame
	var wood: int = sm.inventory_quantity("wood")
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.is_dig_site_claimed("entry_dig_south_bend") and sm.inventory_quantity("wood")==wood+3, "南侧道具E可交互并领取木材3")
	await _capture_image("south_dig_reward")
	if maze.loot_modal.visible: await _click(maze.loot_modal._confirm_button)
	_check(not maze.player.input_locked, "奖励关闭恢复输入")
	await _walk(Vector2(965,1181))
	maze.player.position = Vector2(824,1159)
	await get_tree().process_frame
	var gold: int = sm.gold_balance()
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.is_chest_claimed("entry_south_rim") and sm.gold_balance()==gold+100, "南侧宝箱E交互保持金币奖励")
	await _capture_image("south_chest_reward")
	if maze.loot_modal.visible: await _click(maze.loot_modal._confirm_button)
	await _walk(Vector2(795,1170))
	maze.player.position = Vector2(1099,663)
	await get_tree().process_frame
	gold = sm.gold_balance()
	await _send_key(KEY_E)
	_check(maze.loot_modal.visible and sm.is_chest_claimed("entry_east_rim") and sm.gold_balance()==gold+100, "东侧宝箱E交互保持金币奖励")
	if maze.loot_modal.visible: await _click(maze.loot_modal._confirm_button)
	await _walk(Vector2(1081,678))
