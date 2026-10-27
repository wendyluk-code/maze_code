extends "res://tools/tests/combat_04_state.gd"
const Team = preload("res://scripts/ui/components/team_entry_modal.gd")

func _run() -> void:
	sm=get_node("/root/SaveManager"); tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		_food()
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution; suffix="_%dx%d"%[resolution.x,resolution.y]
			await _ui()
	_report()

func _food() -> void:
	_setup()
	for index in 3:
		var id: String=["slime_1","snail_1","beetle_1"][index]
		_shot(id)
		_check(Run.combat_tick(sm,Roads.SPAWN,0.05).success and Run.defeat(sm,id,Roads.SPAWN).success,"扣费回归真实事务击杀")
		_check(Run.start_capture(sm,id).success and Run.finish_capture(sm,id,false).success and Run.resolve(sm,id,true).success,"捕获操作每次仅扣一份")
		var food:=Progression.satiety_snapshot(sm)
		_check(food.values.yaya==[1,1,0][index] and food.values.tieshan==[1,0,0][index],"沿用芽芽铁山轮流支付：%d"%index)
	var now:=Time.get_unix_time_from_system()
	_check(Progression.satiety_snapshot(sm,now+1000).values.yaya==0,"迷宫内不随时间恢复")
	_check(Run.finish(sm,false,Roads.SPAWN).success,"耗尽饱腹离场")
	var stored: Dictionary=sm.data[Progression.FOOD_KEY]
	var recovered:=Progression.satiety_snapshot(sm,float(stored.at)+1000)
	_check(is_equal_approx(float(recovered.values.yaya),0.4) and is_equal_approx(float(recovered.values.tieshan),0.1),"离场恢复效率沿用每秒上限百分比")
	_check(sm.save(),"离场零饱腹持久化")
	sm.load_data()
	var reloaded:=Progression.satiety_snapshot(sm,float(stored.at)+1000)
	_check(_same_saved(reloaded,recovered),"读档后离线时间投影一致")
	# 等级跨5使饱腹上限变大，但余额保持；本趟攻血与成员仍冻结。
	_setup()
	sm.data[Progression.KEY]={"yaya":{"level":4,"exp":790,"rank":1,"breakthroughs":0}}
	var before:=Run.snapshot(sm)
	var old_food:=Progression.satiety_snapshot(sm)
	_shot("slime_1"); Run.combat_tick(sm,Roads.SPAWN,0.05)
	_check(Progression.record(sm,"yaya").level==5 and Progression.record(sm,"yaya").satiety_max==3 and Progression.satiety_snapshot(sm).values.yaya==old_food.values.yaya,"升级增加饱腹上限但不补余额")
	_check(Run.snapshot(sm).members==before.members and Run.snapshot(sm).combat.attack==before.combat.attack and Run.snapshot(sm).combat.max_hp==before.combat.max_hp,"突破门槛升级仍冻结战斗快照")

func _ui() -> void:
	_setup()
	Run.finish(sm,false,Roads.SPAWN)
	sm.data[Progression.KEY]={"yaya":{"level":30,"exp":0,"rank":6,"breakthroughs":5},"tieshan":{"level":30,"exp":0,"rank":6,"breakthroughs":5}}
	sm.data[Progression.FOOD_KEY]={"values":{"yaya":0.0,"tieshan":0.0},"paused":true,"at":Time.get_unix_time_from_system()}
	var team:=Team.new()
	get_tree().root.add_child(team)
	team.open_exploration()
	await get_tree().create_timer(0.4).timeout
	_check(team.power_value.text=="90" and team.health_value.text=="210" and team.food_value.text=="0 / 15","满级双角色攻血与饱腹上限汇总")
	_check(team.warning.visible and not team.confirm_button.disabled,"零饱腹警示仍允许出发")
	_check(team.team_panel.get_global_rect().position.y>=0 and team.team_panel.get_global_rect().end.y<=get_viewport().get_visible_rect().size.y,"零饱腹长提示仍完整在屏内")
	_check(team.confirm_button.get_global_rect().end.y<=team.team_panel.get_global_rect().end.y,"确认按钮无裁切")
	await _capture_image("max_level_zero_food_team")
	await _click(team.slot_names[0])
	await get_tree().create_timer(0.1).timeout
	_check(team.details.experience_label.text=="已满级" and team.details.attribute_values[1].text=="70" and team.details.attribute_values[2].text=="0 / 8","满级详情与零饱腹显示")
	await _capture_image("max_level_details")
	await _send_key(KEY_ESCAPE)
	_check(not team.details.visible and team.color.a>0.0,"详情Esc恢复单层蒙层")
	team.queue_free(); await get_tree().process_frame
