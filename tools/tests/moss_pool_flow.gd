extends "res://tools/tests/combat_07_flow.gd"
const Moss = preload("res://data/maze/moss_pool_roads.gd")
const MossProjection = preload("res://data/maze/moss_pool_projection.gd")

func _combat_scene() -> void:
	await _new_scene()
	_check(sm.set_yufeng_salia_state("done").success,"区域验收使用御风剧情完成前置")
	maze.capture_flow.set_process(false)
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode = "idle"
	for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key] = []
	maze.travel_region("fenshui",Moss.FENSHUI_RETURN)
	await get_tree().create_timer(1.5).timeout
	maze = get_tree().current_scene
	_check(maze.region_id == "fenshui","先进入分水庭")
	maze.capture_flow.set_process(false)
	maze.camera.snap_to_target()
	maze._update_prompts()
	_check(maze.fenshui_gate_prompts["青苔池"].visible,"青苔池入口提示可见")
	await _click(maze.fenshui_gate_prompts["青苔池"].button)
	_check(maze.confirmation.visible,"实际点击打开入口确认")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked,"取消恢复输入")
	await _click(maze.fenshui_gate_prompts["青苔池"].button)
	var prior: Dictionary = sm.data.duplicate(true)
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	maze._confirm_destination()
	_check(maze.region_id == "fenshui" and sm.data == prior,"保存失败回滚")
	sm._active_save_path = path
	await _click(maze.fenshui_gate_prompts["青苔池"].button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.5).timeout
	maze = get_tree().current_scene
	_check(maze.region_id == "moss_pool" and maze._entry_ready,"通过真实入口进入青苔池")
	if maze.region_id != "moss_pool": return
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused = true
	maze.camera.snap_to_target()
	_check(maze.player.position.distance_to(Moss.SPAWN)<0.1,"右下道路出生")
	_check(maze.task_tracker.visible and maze.map_ui.visible and maze.capture_flow.skill_bar.visible,"任务小地图技能UI保留")
	_check(maze.player.water_ripples == null,"不可涉水区域不生成涉水效果")
	for key in ["members","satiety","bag","monsters"]:
		_check(Run.snapshot(sm)[key] == prior[Run.KEY][key],"换区保留"+key)
	_check(sm.stamina_snapshot().value == prior.stamina.value,"换区不额外扣体力")
	_check(Run.combat_tick(sm,maze.player.position,0.1).success,"新区探索状态可正常推进")
	await _capture_image("01_moss_spawn")
	var before: Vector2 = maze.player.position
	Input.action_press("ui_up")
	await get_tree().create_timer(0.35).timeout
	Input.action_release("ui_up")
	_check(maze.player.position.y < before.y-20,"真实方向输入沿路移动")
	Input.action_press("ui_left")
	await get_tree().create_timer(0.7).timeout
	Input.action_release("ui_left")
	_check(Moss.is_walkable(maze.player.position),"持续横向输入不能穿入作物或水池")
	for p in [Vector2(530,210),Vector2(820,430),Vector2(480,535),Vector2(1000,650),Vector2(770,800),Vector2(950,530),Vector2(15,15)]:
		_check(not Moss.is_walkable(p),"水池瀑布与背景阻挡"+str(p))
	for road in Moss.roads():
		for i in range(road.points.size()-1):
			var a: Vector2 = road.points[i]
			var b: Vector2 = road.points[i+1]
			if not Moss.is_walkable(a) or not Moss.is_walkable(b): continue
			_check(Moss.move_on_road(a,b-a).distance_to(b)<0.1,"道路内分步移动"+str(a))
	var projection := MossProjection.new()
	var atlas: Image = load("res://assets/maps/shallow_floor.png").get_image()
	var anchor: Vector2 = preload("res://data/maze/fenshui_projection.gd").new().project(Moss.FENSHUI_PORTAL)
	_check(projection.project(Moss.ENTRANCE).distance_to(anchor)<0.01,"跨场景入口映射共用锚点")
	for p in [Vector2(384,422),Vector2(727,534),Vector2(1371,628),Vector2(1100,738),Vector2(680,960)]:
		var mapped: Vector2 = projection.project(p)
		_check(mapped.x<700 and mapped.y<400,"五段路映射在总图青苔池区域"+str(mapped))
		var color := atlas.get_pixelv(Vector2i(mapped))
		_check(color.r>0.48 and color.g>0.44 and color.r>color.b*1.12,"总图实际道路像素"+str(mapped),{"color":str(color)})
	maze.map_ui.open_map()
	_check(maze.map_ui.expanded and maze.player.input_locked,"展开地图锁定移动")
	_check(maze.map_ui.full_view._image.texture.resource_path.ends_with("shallow_floor.png"),"保留原总地图底图")
	_check(maze.map_ui.full_view._fog.get_shader_parameter("moss_pool_view"),"青苔池局部揭示")
	await _capture_image("02_moss_full_map")
	maze.map_ui.close_map()
	_check(not maze.player.input_locked and maze.capture_flow.skill_bar.visible,"关闭地图恢复输入和技能UI")
	maze.player.position = Vector2(1101,827)
	maze.camera.snap_to_target()
	_check(sm.record_maze_location("moss_pool",maze.player.position).success,"保存青苔池合法站位")
	sm.load_data()
	_check(sm.resume_scene_path()=="res://scenes/maze_moss_pool.tscn","读档恢复青苔池场景")
	_check(Vector2(sm.maze_exploration_state().position[0],sm.maze_exploration_state().position[1]).distance_to(maze.player.position)<0.1,"读档保留位置")
	_check(not sm.record_maze_location("moss_pool",Vector2(770,800)).success,"拒绝保存水中站位")
	sm.data[sm.MAZE_STATE_KEY].position = [770,800]
	_check(sm.maze_exploration_state().position == [Moss.SPAWN.x,Moss.SPAWN.y],"损坏站位回退出生道路")
	maze.player.position = Moss.SPAWN
	maze._update_prompts()
	maze.camera.snap_to_target()
	await _capture_image("03_moss_return")
	await _click(maze.entrance_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.5).timeout
	maze = get_tree().current_scene
	_check(maze.region_id=="fenshui" and maze.player.position.distance_to(Moss.FENSHUI_RETURN)<0.1,"实际返回分水庭原路口")
	maze.capture_flow.set_process(false)
	await _capture_image("04_fenshui_return")
	maze.travel_region("salt_pool",preload("res://data/maze/salt_pool_roads.gd").SPAWN)
	await get_tree().create_timer(1.5).timeout
	maze = get_tree().current_scene
	_check(maze.region_id=="salt_pool" and maze._entry_ready,"既有盐池切换回归")
	maze.capture_flow.set_process(false)
	maze.map_ui.open_map()
	_check(maze.map_ui.expanded,"盐池地图UI仍可打开")
	maze.map_ui.close_map()
	_check(not maze.player.input_locked,"盐池地图关闭恢复输入")
	await _capture_image("05_salt_regression")
	maze.player.position = Moss.SALT_SIDE_ARRIVAL
	maze.camera.snap_to_target()
	maze._update_prompts()
	_check(maze.has_node("SaltMossPortal") and maze.salt_moss_prompt.visible,"盐池最左道路紫色路标可交互")
	await _capture_image("06_salt_left_portal")
	await _click(maze.salt_moss_prompt.button)
	_check(maze.confirmation.visible,"盐池路标打开原有确认")
	await _send_key(KEY_ESCAPE)
	_check(not maze.player.input_locked,"盐池新路标取消恢复输入")
	await _click(maze.salt_moss_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.5).timeout
	maze = get_tree().current_scene
	_check(maze.region_id=="moss_pool" and maze.player.position.distance_to(Moss.SALT_ARRIVAL)<0.1,"盐池左路实际传送到青苔池右路")
	maze.capture_flow.set_process(false)
	maze.camera.snap_to_target()
	maze._update_prompts()
	_check(maze.salt_moss_prompt.visible,"青苔池右路返回盐池提示")
	var salt_projection = preload("res://data/maze/salt_pool_projection.gd").new()
	_check(salt_projection.project(Moss.SALT_SIDE_MARKER).distance_to(projection.project(Moss.SALT_MARKER))<0.01,"连接两端小地图锚点重合")
	maze.map_ui.refresh_resources()
	var links: Array = maze.map_ui.visible_resources.filter(func(row): return row.id=="salt_moss_pool")
	_check(links.size()==1 and links[0].position==Moss.SALT_LINK_ATLAS,"小地图连接标记只登记一次")
	await _capture_image("07_moss_right_portal")
	maze.map_ui.open_map()
	await _capture_image("08_salt_moss_map")
	maze.map_ui.close_map()
	await _click(maze.salt_moss_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.5).timeout
	maze = get_tree().current_scene
	_check(maze.region_id=="salt_pool" and maze.player.position.distance_to(Moss.SALT_SIDE_ARRIVAL)<0.1,"原紫色路标逻辑实际往返盐池左路")
	maze.capture_flow.set_process(false)
	await _close_scene()
