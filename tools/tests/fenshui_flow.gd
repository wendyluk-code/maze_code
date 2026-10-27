extends "res://tools/tests/combat_07_flow.gd"
const FS = preload("res://data/maze/fenshui_roads.gd")
const FSProjection = preload("res://data/maze/fenshui_projection.gd")

func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	maze.player.position = maze.SettlementExit.FRONT
	maze.camera.snap_to_target()
	maze._update_prompts()
	await _capture_image("01_kushui_sign")
	await _click(maze.settlement_prompt.button)
	_check(maze.confirmation.visible,"枯水渠路标打开确认")
	await _capture_image("02_confirm")
	var prior: Dictionary = sm.data.duplicate(true)
	var saved_path: String = sm._active_save_path
	sm._active_save_path = ""
	maze._confirm_destination()
	_check(maze.region_id == "maze_entry" and sm.data == prior and not maze.player.input_locked,"切区保存失败回滚并恢复输入")
	sm._active_save_path = saved_path
	await _click(maze.settlement_prompt.button)
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	maze = get_tree().current_scene
	_check(maze.region_id == "fenshui" and maze._entry_ready,"确认后实际切入分水庭")
	if maze.region_id != "fenshui": return
	maze.capture_flow.window_focused = true
	_check(maze.player.position.distance_to(FS.SPAWN)<0.1,"右上路面出生")
	_check(maze.capture_flow.monsters.is_empty() and maze.chests.is_empty() and maze.dig_sites.is_empty() and not is_instance_valid(maze.elder),"不携带枯水渠怪物宝箱采集或NPC")
	var now := Run.snapshot(sm)
	for key in ["members","satiety","bag","monsters"]:
		_check(now[key] == prior[Run.KEY][key],"换区保留"+key)
	_check(now.combat.hp == prior[Run.KEY].combat.hp,"换区保留生命")
	_check(sm.stamina_snapshot().value == prior.stamina.value,"切区不重新扣体力")
	await _capture_image("03_fenshui_spawn")
	maze.capture_flow.set_process(false)
	maze.player.set_physics_process(false)
	maze.player.input_locked = false
	maze.capture_flow.combat_paused() # 后续手动测量仍让原暂停判断看到正常处理状态。
	maze.player.set_physics_process(true)
	var normal := _measure(Vector2(1590,203),Vector2.RIGHT,false)
	var water := _measure(Vector2(920,440),Vector2.RIGHT,false)
	var fast := _measure(Vector2(920,440),Vector2.RIGHT,true)
	var restored := _measure(Vector2(1590,203),Vector2.RIGHT,false)
	_check(absf(water/normal-0.65)<0.01,"实际玩家水速65%",{"road":normal,"water":water})
	_check(absf(fast/water-1.5)<0.01,"水速与冲刺1.5叠乘",{"fast":fast,"water":water})
	_check(absf(restored-normal)<0.01,"回到路面立即恢复且倍率不累积")
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1).normalized(),Vector2(-1,-1).normalized()]:
		_check(_measure(Vector2(920,440),direction,false)>0.1,"浅水各方向实际移动"+str(direction))
	for obstacle in [Vector2(650,245),Vector2(1000,337),Vector2(560,481),Vector2(1138,528),Vector2(1355,484),Vector2(300,50),Vector2(1550,800),Vector2(-1,400)]:
		_check(not FS.is_walkable(obstacle),"植被岛或外围不可走"+str(obstacle))
	var blocked := FS.move_on_road(Vector2(1000,440),Vector2(0,-150))
	_check(FS.is_walkable(blocked) and blocked.distance_to(Vector2(1000,290))>5,"大步移动不穿过植被岛")
	var projection := FSProjection.new()
	for i in projection.WORLD.size():
		_check(projection.project(projection.WORLD[i]).distance_to(projection.ATLAS[i])<0.1,"地标映射"+str(i))
	maze.player.position = Vector2(920,440)
	maze.player.facing = Vector2.LEFT
	maze.camera.snap_to_target()
	maze.map_ui._process(0.2)
	_check(maze.map_ui.mini_view.atlas_position.distance_to(projection.project(maze.player.position))<0.1,"小地图位置按区域投影")
	_check(maze.map_ui.mini_view.facing.dot(projection.project_direction(maze.player.position,Vector2.LEFT))>0.999,"小地图方向经地标变换")
	await _capture_image("04_water_hud")
	maze.capture_flow.set_process(true)
	maze.map_ui.open_map()
	_check(maze.map_ui.expanded and maze.player.input_locked,"总图打开锁输入")
	_check(maze.map_ui.full_view.atlas_position == maze.map_ui.mini_view.atlas_position,"大小地图一致")
	await _capture_image("05_full_map")
	await _send_key(KEY_ESCAPE)
	_check(not maze.map_ui.expanded and not maze.player.input_locked and maze.player.is_physics_processing(),"Esc关闭总图恢复输入")
	maze._open_backpack()
	_check(maze._busy and maze.player.input_locked,"背包沿用原入口")
	await _capture_image("06_backpack")
	maze.backpack_warehouse._on_cancel_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	maze.capture_flow.window_focused = true
	_check(not maze.player.input_locked and not maze._busy,"关闭背包恢复输入")
	maze.capture_flow._process(0)
	_check(maze.capture_flow.skill_bar.visible and maze.backpack_entry.visible and maze.task_tracker.is_visible_in_tree(),"技能栏背包任务UI保留",{"skill":maze.capture_flow.skill_bar.visible,"bag":maze.backpack_entry.visible,"task":maze.task_tracker.is_visible_in_tree(),"locked":maze.player.input_locked,"busy":maze._busy})
	await _send_key(KEY_1)
	_check(Run.snapshot(sm).combat.selected == 1,"原技能快捷键保留")
	await _click(maze.task_tracker._task_button)
	_check(maze.task_tracker._expanded,"真实点击展开当前任务")
	await _capture_image("06b_tasks")
	await _click(maze.task_tracker._task_button)
	_check(not maze.task_tracker._expanded and not maze.player.input_locked,"收起任务保留移动输入")
	var monsters: Dictionary = Run.snapshot(sm).monsters
	var actors: Dictionary = Run.snapshot(sm).combat.actors
	for i in 12: _check(Run.combat_tick(sm,maze.player.position,0.05,Rect2(),true).success,"分水庭探索时钟")
	_check(Run.snapshot(sm).monsters == monsters and Run.snapshot(sm).combat.actors == actors,"分水庭不推进原区怪物")
	_check(Run.snapshot(sm).combat.sprint<1.0,"分水庭冲刺正常消耗")
	_check(maze._save_position(),"保存水中位置")
	var point: Vector2 = maze.player.position
	await _close_scene()
	sm.load_data()
	_check(sm.resume_scene_path() == "res://scenes/maze_fenshui.tscn","读档选择分水庭场景")
	maze = load(sm.resume_scene_path()).instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene = maze
	await get_tree().create_timer(0.3).timeout
	_check(maze.region_id == "fenshui" and maze.player.position.distance_to(point)<0.1,"场景重载恢复水中位置")
	maze.capture_flow.window_focused = true
	await _capture_image("07_restored")
	maze.player.position = FS.SPAWN
	maze.camera.snap_to_target()
	maze._update_prompts()
	await _click(maze.entrance_prompt.button)
	_check(maze.confirmation.visible,"右上返回枯水渠确认")
	await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	maze = get_tree().current_scene
	_check(maze.region_id == "maze_entry" and maze._entry_ready and maze.capture_flow.monsters.size()==10,"返回旧区域恢复原怪物与UI")
	_check(maze.player.position.distance_to(maze.SettlementExit.FRONT)<1.0,"返回路标位置")
	await _capture_image("08_return_kushui")
	await _close_scene()

func _measure(point: Vector2, direction: Vector2, sprint: bool) -> float:
	maze.player.position = point
	maze.player.clear_combat_input()
	maze.player.sprint_held = sprint
	Input.action_press("ui_right",maxf(direction.x,0))
	Input.action_press("ui_left",maxf(-direction.x,0))
	Input.action_press("ui_down",maxf(direction.y,0))
	Input.action_press("ui_up",maxf(-direction.y,0))
	maze.player._physics_process(0.05)
	for action in ["ui_right","ui_left","ui_down","ui_up"]: Input.action_release(action)
	maze.player.clear_combat_input()
	return maze.player.position.distance_to(point)
