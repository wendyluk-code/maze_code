extends "res://tools/tests/combat_04_state.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d"%[resolution.x,resolution.y]
			await _cycle()
	_report()

func _cycle() -> void:
	_setup()
	sm.data[Progression.KEY]={"yaya":{"level":1,"exp":490,"rank":1,"breakthroughs":0},"tieshan":{"level":1,"exp":490,"rank":1,"breakthroughs":0}}
	var run: Dictionary=sm.data[Run.KEY]
	for other in run.monsters:
		if other!="slime_1":
			run.monsters[other].status="skipped"; run.monsters[other].respawn_at=99999.0
	sm.save()
	maze=load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(maze); get_tree().current_scene=maze
	await get_tree().create_timer(0.3).timeout
	var flow=maze.capture_flow
	flow.set_process(false)
	var members: Array=Run.snapshot(sm).members.duplicate(true)
	await _fight("first")
	_check(Progression.record(sm,"yaya").level==2 and _exp("yaya")==10 and Progression.record(sm,"tieshan").level==2 and _exp("tieshan")==10,"真实击杀双方获得20经验并立即升级")
	_check(Run.snapshot(sm).combat.attack==3 and Run.snapshot(sm).combat.max_hp==36 and Run.snapshot(sm).members==members,"升级不修改本趟攻击生命与成员快照")
	var killed_hp: int=Run.snapshot(sm).combat.hp
	sm.load_data()
	_check(_exp("yaya")==10 and Run.snapshot(sm).combat.hp==killed_hp,"击杀经验与受伤生命立即落盘")
	await _click(flow.dialog._cancel_button)
	await get_tree().create_timer(0.4).timeout
	flow.set_process(false)
	_check(_exp("yaya")==10 and Run.snapshot(sm).monsters.slime_1.status=="skipped","不捕获保留经验")
	maze.player.position=Roads.SPAWN; maze.camera.snap_to_target()
	await get_tree().create_timer(0.1).timeout
	await _click(flow.member_buttons.yaya)
	await get_tree().create_timer(0.15).timeout
	var details=flow.character_details
	_check(details.visible and details._record.level==2 and details.attribute_values[0].text=="2" and details.attribute_values[1].text=="14" and details.active_skill.is_visible_in_tree(),"迷宫头像打开同组件最新攻血和角色技能")
	var frozen: Dictionary=Run.snapshot(sm).combat.duplicate(true)
	await _capture_image("maze_details")
	await _click(details._close_button)
	_check(not maze.player.input_locked and maze.player.is_physics_processing() and Run.snapshot(sm).combat==frozen,"详情关闭恢复输入且不治疗或刷新战斗数值")
	run=Run.snapshot(sm)
	run.maze_elapsed=float(run.monsters.slime_1.respawn_at)
	sm.data[Run.KEY]=run
	_check(Run.combat_tick(sm,Roads.SPAWN,0.05,flow.visible_world_rect()).success and Run.snapshot(sm).monsters.slime_1.refresh_count==1,"冷却到期安全刷新下一生命")
	await _fight("second")
	_check(_exp("yaya")==30 and _exp("tieshan")==30,"刷新后真实第二次击杀再次各获20")
	# 第二生命明确捕获失败，仍支付原有一份饱腹，不影响已得经验。
	sm.data[Run.KEY].monsters.slime_1.capture_roll=1.0
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(0.5).timeout
	await _click(flow.attempt.yes_button)
	await get_tree().create_timer(13.5).timeout
	_check(Run.snapshot(sm).monsters.slime_1.status=="failed" and _exp("yaya")==30 and Run.snapshot(sm).satiety==2,"实际零J捕获失败保留经验并只扣一次饱腹")
	if flow.dialog.visible: await _click(flow.dialog._confirm_button)
	if flow.reward.visible: await _click(flow.reward._confirm_button)
	if flow.attempt.visible: await _click(flow.attempt.close_button)
	await get_tree().create_timer(0.3).timeout
	flow.set_process(false)
	# 已确认经验后受控最后一击，走真实失败窗和返回餐厅。
	run=Run.snapshot(sm)
	var death_point: Vector2=Run.monster_for(run,"snail_1").position
	maze.player.position=death_point; maze.camera.snap_to_target()
	run.combat.hp=1; run.monsters.snail_1.status="alive"
	run.combat.actors.snail_1.position=Combat.pack(death_point)
	run.combat.actors.snail_1.mode="windup"; run.combat.actors.snail_1.windup=0.01
	sm.data[Run.KEY]=run; sm.save(); flow.set_process(true)
	await get_tree().create_timer(0.5).timeout
	_check(flow.dialog.visible and flow.dialog._title_label.text=="探索失败","受伤归零打开真实失败窗")
	await _capture_image("death_keeps_experience")
	await _click(flow.dialog._confirm_button)
	await get_tree().create_timer(1.3).timeout
	_check(sm.maze_exploration_state().region=="restaurant" and _exp("yaya")==30 and _exp("tieshan")==30,"探索死亡实际回餐厅经验保留")
	sm.load_data()
	_check(_exp("yaya")==30,"死亡离场后读档经验保留")
	await _restaurant_pages()
	if is_instance_valid(get_tree().current_scene): get_tree().current_scene.queue_free()
	await get_tree().process_frame

func _fight(label: String) -> void:
	var flow=maze.capture_flow
	flow.set_process(false)
	var run:=Run.snapshot(sm)
	var home: Vector2=Run.monster_for(run,"slime_1").position
	maze.player.position=Roads.move_on_road(home,Vector2(12,0)); maze.camera.snap_to_target()
	_check(run.combat.actors.slime_1.hp==14,"原14HP开始自动战斗："+label)
	var hits: int=run.combat.hits
	flow.set_process(true)
	var start:=Time.get_ticks_msec()
	while not flow.dialog.visible and Time.get_ticks_msec()-start<15000:
		await get_tree().create_timer(0.1).timeout
	_check(flow.dialog.visible and flow.dialog.victory and Run.snapshot(sm).combat.hits>=hits+5,"至少五次原攻击真实弹道击杀："+label)
	await get_tree().create_timer(0.65).timeout
	await _capture_image(label+"_kill")

func _restaurant_pages() -> void:
	var hud=get_tree().get_first_node_in_group("restaurant_hud")
	_check(is_instance_valid(hud),"实际餐厅HUD可用")
	if not is_instance_valid(hud): return
	# 首次顾客提示是既有餐厅流程，先真实按E结束再操作页面。
	for i in 6:
		await _send_key(KEY_E)
		await get_tree().create_timer(0.15).timeout
	hud._go_to_destination("冒险者之家")
	await get_tree().create_timer(0.25).timeout
	var home=get_tree().get_first_node_in_group("adventurer_home")
	await _click(home.character_buttons.yaya)
	await get_tree().create_timer(0.15).timeout
	_check(home.cards_modal.visible and home.cards_modal.attribute_values[1].text=="14" and home.cards_modal.active_skill.is_visible_in_tree(),"之家详情同组件显示升级后生命")
	await _capture_image("home_details")
	await _click(home.cards_modal._close_button)
	await _click(home.character_buttons.tieshan)
	await _click(home.cards_modal.tabs[1])
	_check(home.cards_modal.skill_bodies[0].text.contains("团队攻击力") and not home.cards_modal.skill_bodies[0].text.contains("基础战力"),"铁山技能文案改为团队攻击力")
	await _capture_image("tieshan_skills")
	await _send_key(KEY_ESCAPE)
	await _click(home.back_button)
	await get_tree().create_timer(0.1).timeout
	hud._open_confirmation("迷宫")
	await get_tree().create_timer(0.3).timeout
	var team=hud.confirmation
	_check(team.power_value.text=="6" and team.health_value.text=="42" and team.food_value.text=="2 / 3","出发汇总使用最新攻击生命和当前饱腹")
	_check(team.slot_names[0].text.contains("等级 2") and team.slot_stats[0].text.contains("生命 14"),"出发每角色显示最新等级攻血")
	await _capture_image("departure_team")
	await _click(team.slots[0])
	await get_tree().create_timer(0.2).timeout
	await _capture_image("departure_selector")
	await _click(team.name_buttons.yaya)
	_check(team.details.visible and team.color.a==0.0,"选队详情复用单层蒙层")
	await _click(team.details._close_button)
	await _click(team.selection_done)
	await _click(team.cancel_button)
	_check(not hud._player.input_locked and hud._player.is_physics_processing(),"队伍取消恢复餐厅输入")
	var food_before:=Progression.satiety_snapshot(sm)
	hud._open_confirmation("迷宫")
	await get_tree().create_timer(0.15).timeout
	await _click(team.confirm_button)
	await get_tree().create_timer(1.4).timeout
	var next:=Run.snapshot(sm)
	_check(sm.maze_exploration_state().region=="maze_entry" and next.combat.attack==6 and next.combat.max_hp==42 and next.combat.hp==42,"点击出发新趟采用新攻血且满生命")
	_check(next.satiety<3.0 and absf(next.satiety-float(food_before.values.yaya)-float(food_before.values.tieshan))<0.02,"新趟不补满饱腹")
