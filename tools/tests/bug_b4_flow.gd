extends "res://tools/tests/combat_02_flow.gd"
const Portal := preload("res://scripts/maze/settlement_portal.gd")
var unavailable_sides: Array = []

func _old_position_escape(portal: Node2D, label: String) -> void:
	var origin: Vector2 = maze.SettlementExit.FRONT if label == "entry" else portal.position
	_check(maze.player.terrain.is_walkable(origin),label+"旧站位夹具合法")
	var escaped := false
	for key in [KEY_D,KEY_A,KEY_S,KEY_W]:
		maze.player.position = origin
		await _hold(key,0.4)
		var relative: Vector2 = maze.player.position-portal.position
		if absf(relative.x)>=58 or absf(relative.y)>=20:
			escaped = true
			break
	_check(escaped,label+"旧阻挡内站位实按可以退出")

func _combat_scene() -> void:
	await _new_scene()
	_quiet()
	await _inspect("entry", maze.settlement_portal, Vector2(130,714), maze.settlement_prompt)
	await _travel(maze.settlement_prompt, "fenshui", maze.Fenshui.SPAWN, true)
	await _inspect("fenshui_back", maze.get_node("SpawnPortal"), Vector2(1632,190), maze.entrance_prompt)
	await _travel(maze.entrance_prompt, "maze_entry", maze.SettlementExit.ARRIVAL, false)
	maze.player.position = Vector2(130,714)
	maze._update_prompts()
	await _travel(maze.settlement_prompt, "fenshui", maze.Fenshui.SPAWN, false)
	var portal: Node2D
	for child in maze.get_children():
		if child.get_script() == Portal: portal = child
	await _inspect("fenshui_next", portal, Vector2(867,115), maze.settlement_prompt)
	await _travel(maze.settlement_prompt, "salt_pool", maze.SaltPool.SPAWN, true)
	await _inspect("salt_back", maze.get_node("SpawnPortal"), maze.SaltPool.SPAWN, maze.entrance_prompt)
	await _travel(maze.entrance_prompt, "fenshui", maze.SaltPool.FENSHUI_RETURN, false)
	var bag := {"slime_gel": 2}
	sm.data[Run.KEY].bag = bag.duplicate()
	var stock: Dictionary = sm.warehouse_snapshot()
	maze._update_prompts()
	await _click(maze.settlement_prompt.button)
	await _click(maze.confirmation.cancel_button)
	await get_tree().create_timer(1.2).timeout
	_check(not Run.snapshot(sm).active and sm.maze_exploration_state().region == "restaurant", "结束探索实际回餐厅")
	_check(sm.warehouse_snapshot().get("slime_gel",0) == stock.get("slime_gel",0)+2,"结束探索携物入库一次")
	maze = get_tree().current_scene
	await _close_scene()
	await _new_scene()
	_quiet()
	maze.player.position = Vector2(142,714)
	await _hold(KEY_A,0.3)
	_check(maze.settlement_prompt.visible,"横向实走靠近可结算")
	sm.data[Run.KEY].bag = {"slime_gel":2}
	stock = sm.warehouse_snapshot()
	maze.camera.snap_to_target()
	await _send_key(KEY_E)
	await _capture_image("entry_horizontal_finish")
	await _click(maze.confirmation.cancel_button)
	await get_tree().create_timer(1.2).timeout
	_check(not Run.snapshot(sm).active and sm.maze_exploration_state().region == "restaurant","横向安全站位实际结束探索")
	_check(sm.warehouse_snapshot().get("slime_gel",0)==stock.get("slime_gel",0)+2,"横向结算携物入库一次")
	maze = get_tree().current_scene
	await _close_scene()
	print("B4_UNREACHABLE_SIDES ",JSON.stringify(unavailable_sides))

func _quiet() -> void:
	maze.capture_flow.set_process(false)
	maze.capture_flow.window_focused = true
	for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode = "idle"
	for key in ["shots", "enemy_shots"]: sm.data[Run.KEY].combat[key] = []
	maze.toast_label.dismiss()

func _travel(prompt: Control, region: String, point: Vector2, keyboard: bool) -> void:
	maze.camera.snap_to_target()
	maze._update_prompts()
	await get_tree().process_frame
	var prior: Dictionary = Run.snapshot(sm)
	var stamina: int = sm.stamina()
	if keyboard:
		await _send_key(KEY_E)
		await _send_key(KEY_E)
	else:
		await _click(prompt.button)
		await _click(maze.confirmation.confirm_button)
	await get_tree().create_timer(1.2).timeout
	maze = get_tree().current_scene
	_check(maze.region_id == region and maze._entry_ready,"实际跨区"+region)
	_check(maze.player.position.distance_to(point)<0.1,"原落点保留"+region,{"actual":str(maze.player.position),"expected":str(point)})
	for key in ["members","satiety","bag"]:
		_check(Run.snapshot(sm)[key] == prior[key],"跨区保留"+key,{"before":prior[key],"after":Run.snapshot(sm)[key]})
	_check(sm.stamina() == stamina,"跨区不重复扣体力")
	if region == "maze_entry":
		for monster in Run.snapshot(sm).monsters.values(): _check(monster.status == "skipped", "返回枯水渠保留既有怪物隐藏规则")
	else: _check(Run.snapshot(sm).monsters == prior.monsters,"前往新区保留原区怪物")
	_check(not maze.player.input_locked and maze.player.is_physics_processing(),"转场结束恢复输入")
	_quiet()

func _inspect(label: String, portal: Node2D, stand: Vector2, prompt: Control) -> void:
	_check(portal.sprite.texture in Portal.FRAMES, label+"紫色素材")
	_check(portal in maze.player.portal_obstacles,label+"局部阻挡已注册")
	for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var start := _side_start(portal.position, side)
		if start == Vector2.INF:
			unavailable_sides.append({"portal":label,"side":str(side),"reason":"原地形边界不可达；未改terrain"})
			continue
		maze.player.position = start
		maze.camera.snap_to_target()
		var key := KEY_D if side.x<0 else (KEY_A if side.x>0 else (KEY_S if side.y<0 else KEY_W))
		await _hold(key,0.48)
		var relative: Vector2 = maze.player.position-portal.position
		_check(absf(relative.x)>=58 or absf(relative.y)>=20,label+"实按靠近受阻"+str(side),{"relative":str(relative)})
		_check(maze.player.position.distance_to(start)>0.1,label+"按键实际产生移动"+str(side))
		_check(maze.player.terrain.is_walkable(maze.player.position),label+"仍在原地形内"+str(side))
		_check(portal.z_index>maze.player.z_index if relative.y<0 else portal.z_index==maze.player.z_index,label+"前后遮挡顺序"+str(side))
		if relative.y>=0: _check(portal.get_index()<maze.player.get_index(),label+"人物在下绘于路标后")
		await _capture_image(label+"_side_"+str(side))
		if label == "entry" and side == Vector2.RIGHT:
			_check(maze.settlement_prompt.visible and maze.SettlementExit.can_bank(maze.player.position),"枯水渠横向安全站位可提示并结算",{"stand":str(maze.player.position),"radius":maze.SettlementExit.INTERACT_RADIUS})
		var away := KEY_A if side.x<0 else (KEY_D if side.x>0 else (KEY_W if side.y<0 else KEY_S))
		var before: Vector2 = maze.player.position
		await _hold(away,0.12)
		_check(maze.player.position.distance_to(before)>0.1,label+"离开阻挡恢复移动"+str(side))
	await _old_position_escape(portal,label)
	# 靠近/远离、确认取消、失败与战斗锁共用真实场景路径。
	maze.player.position = stand
	maze.camera.snap_to_target()
	maze._update_prompts()
	await get_tree().process_frame
	_check(maze.player.terrain.is_walkable(stand),label+"业务测试站位属于原地形")
	_check(prompt.visible,label+"靠近提示")
	_check(prompt.button.get_node("Content/ActionLabel").text.begins_with("前往"),label+"提示统一前往")
	await _send_key(KEY_E)
	_check(maze.confirmation.visible and maze.confirmation.question.text.begins_with("是否前往") and maze.confirmation.confirm_button.text=="前往",label+"E打开前往确认")
	_check(maze.player.input_locked and not maze.player.is_physics_processing() and not prompt.visible,label+"模态锁定与提示隐藏")
	await _capture_image(label+"_confirm")
	await _send_key(KEY_ESCAPE)
	_check(not maze.confirmation.visible and not maze.player.input_locked and maze.player.is_physics_processing(),label+"Esc取消恢复")
	await _click(prompt.button)
	_check(maze.confirmation.visible,label+"点击提示打开")
	var saved_path: String = sm._active_save_path
	var prior: Dictionary = sm.data.duplicate(true)
	sm._active_save_path = ""
	await _click(maze.confirmation.confirm_button)
	_check(sm.data==prior and not maze.player.input_locked and not maze._busy,label+"切区保存失败完整回滚")
	sm._active_save_path = saved_path
	await _click(prompt.button)
	prior = sm.data.duplicate(true)
	sm._active_save_path = ""
	await _click(maze.confirmation.cancel_button)
	_check(sm.data==prior and not maze.player.input_locked and Run.snapshot(sm).active,label+"结束探索保存失败回滚")
	sm._active_save_path = saved_path
	sm.data[Run.KEY].combat.action_left = 0.2
	await _send_key(KEY_E)
	_check(not maze.confirmation.visible and maze.last_message.contains("战斗中"),label+"战斗禁止路标")
	sm.data[Run.KEY].combat.action_left = 0.0
	maze.player.position = stand + Vector2(180,180)
	maze._update_prompts()
	_check(not prompt.visible,label+"远离隐藏")
	maze.player.position = stand
	maze._update_prompts()
	maze.toast_label.dismiss()
	_check(sm.record_maze_location(maze.region_id,stand).success,label+"交互站位保存")
	sm.load_data()
	var saved: Dictionary = sm.maze_exploration_state()
	_check(Vector2(saved.position[0],saved.position[1]).distance_to(stand)<0.1,label+"交互站位读档保留")

func _side_start(center: Vector2, side: Vector2) -> Vector2:
	var tangent := Vector2(-side.y,side.x)
	var distance := 72.0 if side.x != 0 else 36.0
	for offset in [0.0,8.0,-8.0,16.0,-16.0,28.0,-28.0,40.0,-40.0]:
		if side.x != 0 and absf(offset)>=20: continue
		var point: Vector2 = center + side*distance + tangent*offset
		if maze.player.terrain.is_walkable(point) and maze.player.terrain.is_walkable(point-side*6): return point
	return Vector2.INF

func _hold(key: Key, seconds: float) -> void:
	maze.capture_flow.window_focused = true
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(seconds).timeout
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
