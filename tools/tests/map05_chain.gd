extends "res://tools/tests/map05_flow.gd"
const Frog=preload("res://data/maze/fenshui_boss.gd")
const Rock=preload("res://data/maze/salt_boss.gd")
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"整链隔离正式档")
	var resolution:=Vector2i(1152,648) if OS.get_environment("MAP05_CHAIN_SIZE")=="1152" else Vector2i(1280,720)
	get_window().size=resolution
	suffix="_%dx%d"%[resolution.x,resolution.y]
	if failures==0: await _combat_scene()
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir(),"active_save_path":sm._active_save_path},"\t"))
	get_tree().quit(1 if failures else 0)
func prepare_trip() -> void:
	var helper=preload("res://tools/tests/map05_yf_helper.gd").new()
	add_child(helper)
	helper.sm=sm
	helper.tm=tm
	helper.suffix=suffix
	await helper.encounter_flow()
	checks+=helper.checks
	failures+=helper.failures
	results.append_array(helper.results)
	helper.queue_free()
	# 从真实御风战后奖励存档接续，不重置探索。
	maze=load("res://scenes/maze_fenshui.tscn").instantiate()
	get_tree().root.add_child(maze)
	get_tree().current_scene=maze
	await get_tree().create_timer(0.4).timeout
	var e=maze.yf_encounter
	_check(e.phase=="gift_reward","整链接续真实御风奖励")
	await _click(e.gift_modal._confirm_button)
	await get_tree().create_timer(0.2).timeout
	await _send_key(KEY_E)
	await get_tree().create_timer(0.9).timeout
	for i in 2:
		await get_tree().create_timer(2.6).timeout
		await _send_key(KEY_E)
	await get_tree().create_timer(1.0).timeout
	_check(sm.yufeng_salia_state()=="done" and not maze.player.input_locked,"御风完整告别后才解锁区域战斗")
	maze.capture_flow.set_process(false)
	for slot in Bento.GIFTS: _check(Bento.discard(sm,slot).success,"明确丢弃赠礼腾出本次装配格")
	await _capture_image("chain_yufeng_done")
func region_encounters(region: String) -> void:
	if region=="fenshui":
		await kill_capture(Catalog.Fenshui.all()[0].id,false)
		calm()
		maze.player.position=Frog.HOME+Vector2(45,0)
		for i in 30: Run.combat_tick(sm,maze.player.position,0.05)
		_check(sm.data[Run.KEY].combat.actors[Frog.ID].frog_phase in ["warning","airborne","landing","active"],"御风完成后真实踏水启动巨蛙跳跃追击")
		await _capture_image("chain_frog_emerged")
		await kill_capture(Frog.ID,true)
	else:
		await kill_capture(Catalog.Salt.all()[0].id,true)
		await kill_capture(Catalog.Salt.all()[3].id,true)
		await kill_capture(Rock.ID,true)
		calm()
		maze.player.position=Vector2(505,430)
		maze.camera.snap_to_target()
		var flow=maze.capture_flow
		flow.window_focused=true
		flow._process(0)
		await _send_key(KEY_2)
		sm.data[Run.KEY].combat.cooldown=0.0
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=maze.get_viewport().get_canvas_transform()*Vector2(522,365)
		event.pressed=true
		get_viewport().push_input(event)
		await get_tree().process_frame
		event=event.duplicate(); event.pressed=false
		get_viewport().push_input(event)
		flow._process(0.25)
		_check(sm.data[Run.KEY].bag.get("rock_salt",0)==1,"整链真实数字键鼠标土普攻采盐")
		await _capture_image("chain_salt_mined")
	calm()
func kill_capture(id: String,capture: bool) -> void:
	calm()
	var row:=Run.monster_for(Run.snapshot(sm),id)
	var point: Vector2=row.position+Vector2(0,30)
	if id==Frog.ID: point=Frog.HOME+Vector2(45,0)
	maze.player.position=point
	maze.camera.snap_to_target()
	# 有界战斗夹具仅提高攻击和补满当前队伍饱腹；不注入原料或捕获结果。
	var food:=Run.Progression.satiety_snapshot(sm)
	for member in sm.data[Run.KEY].members: food.values[member.id]=float(Run.Progression.record(sm,member.id).satiety_max)
	Run.Progression.store_satiety(sm,food,true)
	sm.data[Run.KEY].satiety=Run._party_food(food,sm.data[Run.KEY].members)
	sm.data[Run.KEY].combat.attack=300
	sm.data[Run.KEY].combat.cooldown=0.0
	sm.data[Run.KEY].monsters[id].capture_roll=0.0
	sm.data[Run.KEY].monsters[id].copy_roll=0.0 if id==Frog.ID else 0.99
	_check(Run.combat_attack(sm,point,point.direction_to(row.position)).success,"正式攻击入口："+id)
	for i in 15: Run.combat_tick(sm,point,0.05)
	_check(sm.data[Run.KEY].combat.actors[id].hp==0,"真实弹道/近战击败："+id)
	var flow=maze.capture_flow
	flow.window_focused=true
	flow._process(0)
	await get_tree().create_timer(0.9).timeout
	flow._process(0)
	await get_tree().create_timer(0.5).timeout
	_check(flow.dialog.visible,"真实倒地捕获入口："+id)
	await _capture_image("chain_defeat_"+id)
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	flow._process(0)
	if capture:
		await _click(flow.attempt.yes_button)
		await get_tree().create_timer(2.7).timeout
		for i in 180:
			await _send_key(KEY_J)
			await get_tree().create_timer(0.06).timeout
			if flow.reward.visible: break
		await get_tree().create_timer(0.8).timeout
		_check(flow.reward.visible and sm.data[Run.KEY].monsters[id].status=="captured","真实按键捕获成功："+id)
		await _click(flow.reward._confirm_button)
	else:
		await _click(flow.attempt.no_button)
		_check(sm.data[Run.KEY].monsters[id].status=="skipped","普通鱼战斗后真实放弃捕获")
	_check(not maze.player.input_locked,"捕获关闭恢复输入："+id)
	calm()
func capture_checks() -> void:
	for id in ["frog_soup","wind_frog_bread","mimic_crab_gratin","scorpion_lotus_fritters"]:
		_check(id in sm.unlocked_recipe_ids(),"整链真实捕获已解锁："+id)
