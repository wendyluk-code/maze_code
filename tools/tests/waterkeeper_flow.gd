extends "res://tools/tests/combat_07_flow.gd"
## 隔离存档验收：往返、道路碰撞、输入恢复、保存失败与跨进程恢复。
var cottage
const COTTAGE_SCENE := "res://scenes/maze_waterkeeper_cottage.tscn"

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	_check(_verify_isolation(), "隔离正式存档")
	_check(get_window().current_screen != DisplayServer.get_primary_screen(), "交互验收窗口位于副屏", {"screen":get_window().current_screen,"position":str(get_window().position),"primary":DisplayServer.get_primary_screen()})
	_check(ResourceLoader.exists(COTTAGE_SCENE), "小屋生产场景存在")
	if failures == 0:
		cottage = load("res://data/maze/waterkeeper_cottage_roads.gd")
		_terrain_checks()
		if OS.get_environment("MAZE_WATERKEEPER_RESTORE") == "1":
			await _restore_checks()
		else:
			for resolution in [Vector2i(1152,648), Vector2i(1280,720)]:
				get_window().size = resolution
				suffix = "_%dx%d" % [resolution.x,resolution.y]
				await _cottage_flow()
	var file := FileAccess.open(_arg("--report="), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()}, "\t"))
	get_tree().quit(1 if failures else 0)

func _terrain_checks() -> void:
	for point in [Vector2(1550,163),Vector2(1370,180),Vector2(1270,260),Vector2(1190,312),Vector2(1090,340),Vector2(990,370),Vector2(840,370),Vector2(700,350),Vector2(780,450),Vector2(750,510),Vector2(670,580),Vector2(570,650),Vector2(450,710),Vector2(350,760)]:
		_check(cottage.is_walkable(point), "图片道路与院落可走"+str(point))
	for point in [Vector2(660,250),Vector2(940,280),Vector2(1100,440),Vector2(390,340),Vector2(480,395),Vector2(400,520),Vector2(220,900),Vector2(40,40)]:
		_check(not cottage.is_walkable(point), "屋内溪水菜畦背景和未开放南端阻挡"+str(point))
	_check(not cottage.is_walkable(Vector2(NAN,1)), "非法坐标拒绝")
	_check(not cottage.is_walkable(Vector2(700,350),-1), "非法脚底半径拒绝")
	var path := [Vector2(1550,163),Vector2(1450,143),Vector2(1370,180),Vector2(1270,260),Vector2(1190,312),Vector2(1090,340),Vector2(990,370),Vector2(840,370),Vector2(700,350)]
	for i in range(path.size()-1):
		_check(cottage.move_on_road(path[i],path[i+1]-path[i]).distance_to(path[i+1])<0.2, "石桥至院落连续可达"+str(i))
	var projection = load("res://data/maze/waterkeeper_cottage_projection.gd").new()
	var moss_projection = load("res://data/maze/moss_pool_projection.gd").new()
	_check(projection.project(cottage.ENTRANCE).distance_to(moss_projection.project(cottage.MOSS_MARKER))<0.01, "连接两端共用总图锚点")
	_check(moss_projection.project(cottage.MOSS_RETURN).distance_to(cottage.LINK_ATLAS)<65.0, "青苔池实际可站立入口位置靠近连接标记")
	var atlas: Image = load("res://assets/maps/shallow_floor.png").get_image()
	for point in [cottage.ENTRANCE,Vector2(700,350),Vector2(300,795)]:
		var mapped: Vector2 = projection.project(point)
		var color := atlas.get_pixelv(Vector2i(mapped))
		_check(color.r>0.48 and color.g>0.44 and color.r>color.b*1.12, "独立总图道路像素核对"+str(point), {"mapped":str(mapped),"color":str(color)})

func _settled() -> void:
	await get_tree().create_timer(1.4).timeout
	maze = get_tree().current_scene
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused = true
	maze.camera.snap_to_target()
	maze._update_prompts()

func _walk_cottage_path(point: Vector2) -> void:
	for i in 360:
		# 受控后台验收：不抢用户焦点，允许其继续使用主屏。
		maze.capture_flow.window_focused = true
		var delta: Vector2 = point-maze.player.position
		if delta.length()<3.0: break
		for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
		if absf(delta.x)>1: Input.action_press("ui_right" if delta.x>0 else "ui_left", minf(1,absf(delta.x)/4))
		if absf(delta.y)>1: Input.action_press("ui_down" if delta.y>0 else "ui_up", minf(1,absf(delta.y)/4))
		await get_tree().physics_frame
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
	_check(maze.player.position.distance_to(point)<6, "真实方向输入抵达"+str(point), {"actual":str(maze.player.position)})

func _hold_direction(action: String, seconds: float) -> void:
	Input.action_press(action)
	for i in ceili(seconds*Engine.physics_ticks_per_second):
		maze.capture_flow.window_focused = true
		await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame

func _cottage_flow() -> void:
	await _new_scene()
	sm.set_yufeng_salia_state("done")
	maze.capture_flow.set_process(false)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode = "idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key] = []
	while preload("res://scripts/ui/components/scene_transition.gd").is_active(get_tree()): await get_tree().process_frame
	maze.travel_region("fenshui",preload("res://data/maze/moss_pool_roads.gd").FENSHUI_RETURN)
	await _settled()
	_check(maze.region_id=="fenshui", "青苔池前置进入分水庭")
	if maze.region_id!="fenshui":
		await _close_scene()
		return
	await _click(maze.fenshui_gate_prompts["青苔池"].button)
	await _click(maze.confirmation.confirm_button)
	await _settled()
	_check(maze.region_id=="moss_pool", "从分水庭原入口进入青苔池")
	for point in [Vector2(1075,1000),Vector2(1060,970),Vector2(1050,950),Vector2(1030,910),Vector2(1005,870),Vector2(985,840),Vector2(974,824)]: await _walk_cottage_path(point)
	maze.camera.snap_to_target()
	maze._update_prompts()
	_check(maze.cottage_prompt.visible, "从青苔出生点步行可达小屋入口")
	await _capture_image("01_moss_cottage_gate")
	await _click(maze.cottage_prompt.button)
	_check(maze.confirmation.visible, "实际点击小屋路标打开确认")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked and not maze.confirmation.visible, "取消确认恢复输入")
	sm.data[Run.KEY].combat.axe_pending = true
	await _click(maze.cottage_prompt.button)
	_check(not maze.confirmation.visible and not maze.player.input_locked and maze.last_message.contains("战斗中"), "攻击尚未结束时路标拒绝换区且不锁输入")
	sm.data[Run.KEY].combat.axe_pending = false
	_check(maze._save_position(), "失败实验前固定当前合法位置")
	var before: Dictionary = sm.data.duplicate(true)
	var save_path: String = sm._active_save_path
	sm._active_save_path = ""
	await _click(maze.cottage_prompt.button)
	await _click(maze.confirmation.confirm_button)
	_check(maze.region_id=="moss_pool" and sm.data[Run.KEY]==before[Run.KEY] and sm.data[sm.MAZE_STATE_KEY]==before[sm.MAZE_STATE_KEY] and not maze.player.input_locked, "换区保存失败探索与位置回滚并恢复输入")
	sm._active_save_path = save_path
	await _click(maze.cottage_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await _settled()
	_check(maze.region_id=="waterkeeper_cottage" and maze._entry_ready, "确认进入真实小屋场景")
	if maze.region_id!="waterkeeper_cottage": return
	_check(maze.player.position.distance_to(cottage.SPAWN)<0.1, "小屋落点安全")
	for key in ["members","satiety","bag","monsters"]: _check(Run.snapshot(sm)[key]==before[Run.KEY][key], "新区域保留本趟"+key)
	_check(sm.stamina_snapshot().value==before.stamina.value, "换区不再扣体力")
	_check(maze.chests.is_empty() and maze.dig_sites.is_empty() and maze.capture_flow.monsters.is_empty(), "小屋不增加怪物采集或宝箱")
	_check(Run.combat_tick(sm,maze.player.position,0.1).success, "新区域战斗状态合法且可推进")
	await _capture_image("02_cottage_entry")
	for point in [Vector2(1450,143),Vector2(1370,180),Vector2(1270,260),Vector2(1190,312),Vector2(1090,340),Vector2(990,370),Vector2(840,370),Vector2(700,350)]: await _walk_cottage_path(point)
	maze.camera.snap_to_target()
	await _capture_image("03_cottage_courtyard")
	await _hold_direction("ui_up",0.8)
	_check(maze.player.position.y>295 and cottage.is_walkable(maze.player.position), "真实上行输入不能穿入房屋")
	await _walk_cottage_path(Vector2(700,350))
	for point in [Vector2(780,408),Vector2(780,450),Vector2(750,510),Vector2(670,580),Vector2(570,650),Vector2(450,710),Vector2(350,760),Vector2(300,795)]: await _walk_cottage_path(point)
	await _hold_direction("ui_down",1.0)
	_check(maze.player.position.y<830 and maze._near_destination().is_empty() and cottage.is_walkable(maze.player.position), "南侧止步不能进入树根庭院")
	maze.camera.snap_to_target()
	await _capture_image("03b_south_closed")
	for point in [Vector2(300,795),Vector2(350,760),Vector2(450,710),Vector2(570,650),Vector2(670,580),Vector2(750,510),Vector2(780,450),Vector2(780,408),Vector2(840,370),Vector2(990,370)]: await _walk_cottage_path(point)
	await _hold_direction("ui_up",0.8)
	_check(maze.player.position.y>340 and cottage.is_walkable(maze.player.position), "真实输入不能从桥岸穿入溪流")
	for point in [Vector2(990,370),Vector2(840,370),Vector2(620,344)]: await _walk_cottage_path(point)
	await _hold_direction("ui_down",0.8)
	_check(maze.player.position.y<410 and cottage.is_walkable(maze.player.position), "真实输入不能穿入菜畦围栏")
	await _walk_cottage_path(Vector2(700,350))
	maze.camera.snap_to_target()
	maze.map_ui.open_map()
	_check(maze.map_ui.expanded and maze.player.input_locked, "小屋总图锁定输入")
	_check(maze.map_ui.full_view._fog.get_shader_parameter("waterkeeper_view"), "小屋地图局部揭示")
	await _capture_image("04_cottage_map")
	maze.map_ui.close_map()
	_check(not maze.player.input_locked, "地图关闭恢复输入")
	var position_before: Vector2 = maze.player.position
	_check(maze._save_position(), "保存小屋院落位置")
	sm.load_data()
	_check(sm.resume_scene_path()==COTTAGE_SCENE and Vector2(sm.maze_exploration_state().position[0],sm.maze_exploration_state().position[1]).distance_to(position_before)<0.1, "小屋读档场景和位置正确")
	_check(not sm.record_maze_location("waterkeeper_cottage",Vector2(1100,440)).success, "拒绝保存水中位置")
	var previous: Dictionary = sm.data[sm.MAZE_STATE_KEY].duplicate(true)
	sm.data[sm.MAZE_STATE_KEY].position=[1100,440]
	_check(sm.maze_exploration_state().position==[cottage.SPAWN.x,cottage.SPAWN.y], "损坏位置回退小屋安全点")
	sm.data[sm.MAZE_STATE_KEY]=previous
	maze.player.position=cottage.SPAWN
	maze.camera.snap_to_target()
	maze._update_prompts()
	await _send_key(KEY_E)
	_check(maze.confirmation.visible, "小屋来源路标支持键盘E")
	await _send_key(KEY_ESCAPE)
	await _click(maze.entrance_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await _settled()
	_check(maze.region_id=="moss_pool" and maze.player.position.distance_to(cottage.MOSS_RETURN)<0.1, "小屋返回青苔池安全落点")
	var bank_before: Dictionary = sm.data.duplicate(true)
	var warehouse_before: Dictionary = sm.warehouse_snapshot()
	_check(Run.finish(sm,true,maze.player.position).success, "青苔池新路标允许使用原结束探索事务")
	_check(not Run.snapshot(sm).active and sm.warehouse_snapshot()==warehouse_before, "空袋结算不凭空生成奖励")
	sm.data=bank_before
	sm.save()
	await _click(maze.cottage_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await _settled()
	_check(maze.region_id=="waterkeeper_cottage", "同趟可再次进入小屋")
	maze.player.position=Vector2(700,350)
	_check(maze._save_position(), "留下跨进程恢复样例")
	await _close_scene()

func _restore_checks() -> void:
	sm._active_save_path="user://chapter-ending-test.json"
	sm.load_data()
	_check(sm.resume_scene_path()==COTTAGE_SCENE, "新进程恢复小屋场景")
	maze=load(sm.resume_scene_path()).instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await _settled()
	_check(maze._entry_ready and maze.player.position.distance_to(Vector2(700,350))<0.1, "新进程恢复院落位置和活动探索")
	await _capture_image("05_restart_courtyard")
	var previous: Dictionary = sm.data.duplicate(true)
	var warehouse_before: Dictionary = sm.warehouse_snapshot()
	maze.player.position=cottage.SPAWN
	maze.camera.snap_to_target()
	maze._update_prompts()
	await _click(maze.entrance_prompt.button)
	await _click(maze.confirmation.cancel_button)
	await get_tree().create_timer(1.5).timeout
	_check(get_tree().current_scene.scene_file_path==sm.RESTAURANT_SCENE and not Run.snapshot(sm).active, "恢复后从小屋选择结束探索实际返回餐厅")
	_check(sm.warehouse_snapshot()==warehouse_before, "小屋结束探索不产生额外奖励")
	# 恢复隔离样例，便于独立预览；从不写回正式存档。
	sm.data=previous
	sm.save()
	await _close_scene()
