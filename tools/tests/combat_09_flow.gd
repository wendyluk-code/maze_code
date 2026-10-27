extends "res://tools/tests/combat_08_mouse_regression.gd"

var entry_layouts: Array = []

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _entry_cycle()
			if is_instance_valid(get_tree().current_scene):
				get_tree().current_scene.queue_free()
				await get_tree().process_frame
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"entry_layouts":entry_layouts,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _restaurant_entry() -> bool:
	scene=get_tree().current_scene
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	if not is_instance_valid(hud):
		_check(false,"餐厅入口场景存在")
		return false
	# 餐厅首次来客对白是现有入口前置，使用真实E关闭，不绕过输入锁。
	for press in range(8):
		if not hud.customer_flow._arrival_tutorial_busy: break
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
	var entrance: Node2D
	for node in get_tree().get_nodes_in_group("interactable"):
		if str(node.get("display_name"))=="迷宫入口": entrance=node
	_check(is_instance_valid(entrance),"真实餐厅迷宫交互点存在")
	if not is_instance_valid(entrance): return false
	hud._player.global_position=_stand(entrance)
	hud._player.last_valid=hud._player.global_position
	await get_tree().create_timer(0.2).timeout
	await _send_key(KEY_E)
	await get_tree().create_timer(0.25).timeout
	_check(hud.confirmation.visible,"真实E打开探索准备",{"locked":hud._player.input_locked,"tutorial":tm.active,"arrival":hud.customer_flow._arrival_tutorial_busy,"position":str(hud._player.position)})
	if not hud.confirmation.visible: return false
	hud.confirmation.selected=["yaya","tieshan"]
	hud.confirmation._refresh()
	await _click(hud.confirmation.confirm_button)
	var deadline:=Time.get_ticks_msec()+8000
	while not is_instance_valid(get_tree().get_first_node_in_group("maze_entry")) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	maze=get_tree().get_first_node_in_group("maze_entry")
	_check(is_instance_valid(maze),"确认后真实转场迷宫")
	if not is_instance_valid(maze): return false
	await get_tree().create_timer(0.8).timeout
	maze.toast_label.dismiss()
	_check(maze._entry_ready and Run.snapshot(sm).monsters.size()==10,"入场成功且十槽位")
	entry_layouts.append(Run.snapshot(sm).layout)
	return maze._entry_ready

func _walk_first(label: String) -> bool:
	var first: Array=[]
	var shown: Array=[]
	var run:=Run.snapshot(sm)
	_check(run.layout[0].position==[860.0,295.0],"首段史莱姆使用生产布局："+label)
	_check(run.combat.actors.slime_1.mode=="idle" and Combat.select_target(run,maze.player.position).is_empty(),"出生无贴脸激活或攻击目标："+label)
	await _capture_image(label+"_entry")
	var deadline:=Time.get_ticks_msec()+7000
	var waypoint:=0
	var points: Array[Vector2]=[Vector2(1061,188),Vector2(995,225),Vector2(933,269)]
	while first.is_empty() and Time.get_ticks_msec()<deadline:
		var goal: Vector2=points[waypoint]
		if maze.player.position.distance_to(goal)<8 and waypoint<points.size()-1: waypoint+=1
		var dir: Vector2=maze.player.position.direction_to(points[waypoint])
		Input.action_press("ui_left",maxf(0,-dir.x))
		Input.action_press("ui_right",maxf(0,dir.x))
		Input.action_press("ui_up",maxf(0,-dir.y))
		Input.action_press("ui_down",maxf(0,dir.y))
		await get_tree().process_frame
		run=Run.snapshot(sm)
		for id in run.combat.actors:
			if run.combat.actors[id].mode!="idle": first.append(id)
		if shown.is_empty():
			for id in maze.capture_flow.monsters:
				if maze.capture_flow.monsters[id].label.is_visible_in_tree(): shown.append(id)
	for action in ["ui_left","ui_right","ui_up","ui_down"]: Input.action_release(action)
	_check(first==["slime_1"] and shown==["slime_1"],"真实道路移动首激活与首显示均史莱姆："+label,{"first":first,"shown":shown,"hero":str(maze.player.position)})
	await _capture_image(label+"_first_slime")
	return first==["slime_1"]

func _entry_cycle() -> void:
	_completed()
	sm.cancel_maze_entry()
	sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
	sm.save()
	scene=RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().create_timer(0.5).timeout
	if not await _restaurant_entry(): return
	if not await _walk_first("first"): return
	var flow=maze.capture_flow
	# 不改生产布局、怪物生命、伤害或捕获随机值；真实鼠标逐次攻击满血首怪。
	var deadline:=Time.get_ticks_msec()+12000
	while not flow.dialog.visible and Time.get_ticks_msec()<deadline:
		await _attack_click()
		await get_tree().create_timer(0.95).timeout
	_check(flow.dialog.visible and flow.dialog.victory and Run.snapshot(sm).pending=="slime_1","生产满血首怪真实鼠标击杀")
	if not flow.dialog.visible or not flow.dialog.victory: return
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	await _click(flow.attempt.yes_button)
	await get_tree().create_timer(2.6).timeout
	for i in 80:
		await _send_key(KEY_J)
		await get_tree().create_timer(0.07).timeout
		if flow.reward.visible: break
	await get_tree().create_timer(0.6).timeout
	_check(flow.reward.visible and Run.snapshot(sm).monsters.slime_1.status=="captured","真实首怪捕获与奖励窗口")
	await _capture_image("captured")
	if not flow.reward.visible: return
	flow.set_process(false)
	var captured:=Run.snapshot(sm)
	_check(not Run.resolve(sm,"slime_1",true).success and Run.snapshot(sm)==captured,"重复捕获不发奖")
	await _click(flow.reward._confirm_button)
	# 读盘、重复入场使用原布局/随机值/生命；也覆盖已完成首遇后的恢复。
	_check(sm.save(),"进行中探索保存")
	sm.load_data()
	_check(_same_saved(Run.snapshot(sm),captured),"读盘保留进行中探索全状态")
	var point: Vector2=maze.player.position
	_check(Run.begin(sm,point).success and _same_saved(Run.snapshot(sm),captured),"重复入场不补怪不重抽不发奖")
	# 仅推进冷却时钟到边界，实际刷新仍走原事务及视口安全筛选。
	var run:=Run.snapshot(sm)
	run.maze_elapsed=run.monsters.slime_1.respawn_at-0.1
	sm.data[Run.KEY]=run
	maze.player.position=Roads.SPAWN
	maze.camera.snap_to_target()
	await get_tree().process_frame
	var visible: Rect2=flow.visible_world_rect()
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05,visible).success and Run.snapshot(sm).monsters.slime_1.status=="captured","首怪冷却前不刷新")
	var path: String=sm._active_save_path
	var previous: Dictionary=sm.data.duplicate(true)
	sm._active_save_path=""
	_check(not Run.combat_tick(sm,Roads.SPAWN,0.1,visible).success and sm.data==previous,"首怪刷新保存失败完整回滚")
	sm._active_save_path=path
	_check(Run.combat_tick(sm,Roads.SPAWN,0.1,visible).success,"首怪冷却后安全随机刷新")
	run=Run.snapshot(sm)
	_check(run.monsters.slime_1.refresh_count==1 and run.monsters.slime_1.status=="alive" and Run.monster_for(run,"slime_1").position!=Vector2(860,295) and _same_saved(run.bag,captured.bag),"首遇规则不固定后续刷新或增加奖励",{"monster":run.monsters.slime_1,"layout":run.layout,"bag":run.bag,"captured_bag":captured.bag,"elapsed":run.maze_elapsed})
	_check(Run.safe_spawn(run,"slime_1",Vector2(995,225),Vector2(270,720),Rect2(0,600,300,300)),"首遇后首段仍可成为正常冷却候选")
	# 结束探索的两个正式场景入口均回到餐厅，再用实际餐厅入口建立新趟。
	for bank in [true,false]:
		var old_layout: Array=Run.snapshot(sm).layout.duplicate(true)
		maze.player.position=Vector2(116,724) if bank else Roads.SPAWN
		maze.return_to_restaurant(bank)
		var deadline_return:=Time.get_ticks_msec()+8000
		while not is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")) and Time.get_ticks_msec()<deadline_return:
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		_check(sm.maze_exploration_state().region=="restaurant" and not Run.snapshot(sm).active,"正常/放弃返回餐厅："+str(bank))
		if not await _restaurant_entry(): return
		_check(Run.snapshot(sm).layout!=old_layout and Run.snapshot(sm).bag.is_empty(),"再次新入场重抽其余布局且空背包："+str(bank))
		if not await _walk_first("reentry_"+str(bank)): return
		maze.capture_flow.set_process(false)
	await _close_scene()
