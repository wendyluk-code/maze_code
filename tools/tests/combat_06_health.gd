extends "res://tools/tests/combat_06_flow.gd"
func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _bars()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)

func _bars() -> void:
	await _new_scene()
	var flow=maze.capture_flow
	maze._busy=true
	var c: Dictionary=sm.data[Run.KEY].combat
	c.hp=36
	c.cooldown=100.0
	c.actors.slime_1.mode="chase"
	c.actors.slime_1.position=[995,225]
	c.actors.slime_1.hp=14
	c.actors.slime_2.mode="chase"
	c.actors.slime_2.position=[1015,215]
	c.actors.slime_2.hp=14
	await get_tree().process_frame
	await get_tree().process_frame
	_check(flow.health_bar is ProgressBar and flow.health_bar.is_visible_in_tree(),"主角原生血条常显")
	_check(flow.health_bar.size==Vector2(120,7) and flow.monsters.slime_1.health_bar.size==Vector2(120,7),"实际血条120乘7像素不受主题撑高")
	_check(flow.health_bar.ratio==1 and flow.health_bar.max_value==36,"主角满血填满")
	_check(flow.monsters.slime_1.health_bar.is_visible_in_tree() and flow.monsters.slime_1.health_bar.ratio==1,"激活怪满血条显示")
	_check(not flow.monsters.snail_1.health_bar.is_visible_in_tree(),"未激活怪不显示血条")
	_check(flow.power_label.size.x==120 and flow.monsters.slime_1.label.size.x==120,"攻击标签与血条收紧至120世界像素")
	_check(not flow.monsters.slime_1.label.get_global_rect().intersects(flow.monsters.slime_2.label.get_global_rect()),"多怪攻击血条布局不重叠")
	_check(not flow.monsters.slime_1.label.get_global_rect().intersects(flow.power_label.get_global_rect()),"魔物条不盖主角攻击血条")
	await _capture_image("health_full_multiple")
	c.sprint=0.55
	c.hp=18
	c.actors.slime_1.hp=7
	c.actors.slime_2.hp=3
	await get_tree().process_frame
	await get_tree().process_frame
	_check(flow.health_bar.ratio==0.5 and flow.monsters.slime_1.health_bar.ratio==0.5,"主角和魔物半血精确50%")
	_check(is_equal_approx(flow.monsters.slime_2.health_bar.ratio,3.0/14.0),"多怪分别读取自己的真实血量比例")
	_check(flow.hp_label.text=="HP:18/36" and flow.power_label.text=="ATK:3","主角真实ATK HP左右文字")
	_check(flow.sprint_bar.size==Vector2(120,4) and is_equal_approx(flow.sprint_bar.ratio,0.55),"更细金色加速条独立显示")
	_check(flow.monsters.slime_1.health_bar.get_theme_stylebox("fill").bg_color==Color("d96b60"),"魔物红血条")
	_check(flow.health_bar.get_theme_stylebox("fill").bg_color==Color("a6b967"),"主角绿血条")
	await _capture_image("health_injured_multiple")
	c.actors.slime_1.position=[1005,220]
	c.actors.slime_1.mode="return"
	c.actors.slime_1.hp=1
	maze._busy=false
	await get_tree().create_timer(0.25).timeout
	maze._busy=true
	await get_tree().process_frame
	_check(Run.snapshot(sm).combat.actors.slime_1.hp==14 and flow.monsters.slime_1.health_bar.ratio==1,"真实返航到出生点满血同步条形")
	await _capture_image("health_return_full")
	maze._busy=false
	maze._open_backpack()
	await get_tree().create_timer(0.15).timeout
	var frozen: Dictionary=Run.snapshot(sm).combat
	var hero_value: float=flow.health_bar.value
	var monster_value: float=flow.monsters.slime_1.health_bar.value
	await get_tree().create_timer(0.4).timeout
	_check(Run.snapshot(sm).combat==frozen and flow.health_bar.value==hero_value and flow.monsters.slime_1.health_bar.value==monster_value,"弹窗期间血条与真实战斗冻结一致")
	await _capture_image("health_modal_paused")
	await _send_key(KEY_ESCAPE)
	await get_tree().create_timer(0.15).timeout
	_check(Run.snapshot(sm).combat.elapsed>frozen.elapsed,"关闭恢复战斗推进")
	maze._busy=true
	sm.data[Run.KEY].combat.hp=0
	await get_tree().process_frame
	await get_tree().process_frame
	_check(flow.health_bar.ratio==0,"零生命血条完全为空")
	await _capture_image("health_empty")
	await _close_scene()
