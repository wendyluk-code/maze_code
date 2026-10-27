extends "res://tools/tests/combat_07_flow.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size=resolution
			suffix="_%dx%d" % [resolution.x,resolution.y]
			await _hud_and_ui()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _visible_target(expected: String) -> void:
	var shown: Array=[]
	for id in maze.capture_flow.monsters:
		if maze.capture_flow.monsters[id].label.is_visible_in_tree(): shown.append(id)
	_check(shown==([] if expected.is_empty() else [expected]),"仅显示当前目标："+expected,{"shown":shown})
	_check(Combat.select_target(Run.snapshot(sm),maze.player.position)==expected,"显示与发射同源："+expected)

func _ui_click(control: Control, label: String) -> void:
	sm.data[Run.KEY].combat.cooldown=0.0
	var count: int=Run.snapshot(sm).combat.throws
	await _click(control)
	_check(Run.snapshot(sm).combat.throws==count,label+"不穿透攻击")

func _hud_and_ui() -> void:
	await _new_scene()
	var flow=maze.capture_flow
	flow.set_process(false)
	maze.player.position=Vector2(888,288)
	var c: Dictionary=sm.data[Run.KEY].combat
	c.hp=30
	c.sprint=0.6
	for actor in c.actors.values(): actor.position=[300,700]
	c.actors.slime_1.position=[836,310]
	c.actors.slime_1.hp=10
	c.actors.slime_2.position=[939,332]
	c.actors.beetle_1.position=[961,283]
	flow.combat_time=0.0
	flow._process(0.0)
	await get_tree().process_frame
	_visible_target("slime_1")
	_check(flow.health_bar.size==Vector2(60,6) and flow.sprint_bar.size==Vector2(60,4),"正式主角60像素短血条与金条")
	_check(flow.power_label.get_theme_font_size("font_size")==9 and flow.hp_label.get_theme_font_size("font_size")==9,"正式ATK HP字号9")
	_check(flow.hp_label.position==Vector2(0,12) and flow.hp_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT and flow.health_bar.position==Vector2(0,26),"两行左对齐血条左端")
	_check(flow.power_label.position==Vector2(-30,-113),"主角整组正上方居中")
	_check(flow.hp_label.text=="HP:30/36" and is_equal_approx(flow.health_bar.ratio,30.0/36),"正式组件读取真实状态")
	_check(flow.health_bar.get_theme_stylebox("fill").bg_color==Color("a6b967") and flow.sprint_bar.get_theme_stylebox("fill").bg_color==Color("e6b943"),"主角绿与加速金保留")
	for monster in flow.monsters.values():
		_check(monster.label.position.x==-30 and monster.health_bar.size==Vector2(60,6),"魔物标签居中短条："+str(monster.config.id))
		_check(monster.hp_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT and monster.label.get_theme_font_size("font_size")==9,"魔物两行左对齐9号字："+str(monster.config.id))
	_check(flow.monsters.slime_1.health_bar.get_theme_stylebox("fill").bg_color==Color("d96b60"),"魔物红保留")
	var content=flow.controls_hint.get_child(0).get_node("Content")
	_check(content.get_child(0).get_node("KeyIcon/KeyLabel").text=="Shift" and content.get_child(1).text=="加速" and content.get_child(2).get_node("KeyIcon/KeyLabel").text=="单击" and content.get_child(3).text=="攻击","两个带底键帽及准确文字")
	_check(content.get_child(0).size.x>=44 and content.get_child(0).get_node("KeyIcon").stretch_mode==TextureRect.STRETCH_SCALE,"Shift键帽去透明留白后仍覆盖文字")
	await _capture_image("short_bars_real_scene")
	c.cooldown=0.0
	await _attack_click()
	c=sm.data[Run.KEY].combat
	_check(c.shots.size()==1 and Combat.vec(c.shots[0].target).is_equal_approx(Combat.vec(c.actors.slime_1.position)+Combat.vec(c.actors.slime_1.velocity)*Combat.FLIGHT),"实际鼠标发射目标与显示目标一致")
	c.shots=[]
	c.actors.slime_1.mode="return"
	flow.combat_time=0.0
	flow._process(0.0)
	_visible_target("slime_2")
	c.actors.slime_2.hp=0
	# 暂停门禁避免测试零血目标触发胜利流程；渲染仍读取正式状态。
	maze._busy=true
	flow.combat_time=0.0
	flow._process(0.0)
	_visible_target("beetle_1")
	c.actors.beetle_1.position=[300,700]
	flow.combat_time=0.0
	flow._process(0.0)
	_visible_target("")
	_check(flow.power_label.is_visible_in_tree(),"无目标主角仍常显")
	c.actors.slime_2.hp=14
	c.actors.slime_2.position=[939,332]
	maze.player.position+=Vector2(15,0)
	flow.combat_time=0.0
	flow._process(0.0)
	_visible_target("slime_2")
	_check(is_equal_approx(flow.power_label.global_position.x+30,maze.player.global_position.x),"移动后主角血条随人物居中")
	await _capture_image("target_switch")
	maze._busy=false
	flow.combat_time=0.0
	flow._process(0.0)
	await _ui_click(flow.controls_hint,"底部提示框")
	await _ui_click(maze.task_tracker._task_button,"任务入口")
	await _ui_click(maze.task_tracker._task_button,"任务收起")
	await _ui_click(maze.gold_counter,"金币计数")
	await _ui_click(maze._ui_root.get_node("StaminaCounter"),"体力计数")
	await _ui_click(maze.map_ui.mini_button,"小地图入口")
	_check(maze.map_ui.expanded,"真实点击打开地图")
	await _ui_click(maze.map_ui.shallow_button,"地图浅层按钮")
	await _ui_click(maze.map_ui.close_button,"地图关闭按钮")
	_check(not maze.map_ui.expanded,"地图关闭恢复")
	await _ui_click(maze.backpack_entry,"背包入口")
	_check(maze.backpack_warehouse.visible,"真实点击打开背包")
	var count: int=Run.snapshot(sm).combat.throws
	await _attack_click()
	_check(Run.snapshot(sm).combat.throws==count,"背包内容点击不穿透")
	await _ui_click(maze.backpack_warehouse._cancel_button,"背包关闭按钮")
	_check(not maze.backpack_warehouse.visible and Run.snapshot(sm).combat.throws==count,"背包恢复无积攒攻击")
	await _ui_click(flow.member_buttons.yaya,"芽芽头像")
	_check(flow.character_details.visible,"真实点击打开角色详情")
	await _ui_click(flow.character_details._close_button,"角色详情关闭按钮")
	_check(not flow.character_details.visible,"详情关闭恢复")
	await _ui_click(flow.member_buttons.tieshan,"铁山头像")
	await _send_key(KEY_ESCAPE)
	await _mouse_state(true,Vector2(50,200))
	await _mouse_state(false,Vector2(50,200))
	_check(Run.snapshot(sm).combat.throws==count,"队伍空位不穿透")
	maze.player.input_locked=true
	await _attack_click()
	maze.player.input_locked=false
	_check(Run.snapshot(sm).combat.throws==count,"输入锁定不排队")
	sm.data[Run.KEY].combat.cooldown=0.0
	await _attack_click()
	_check(Run.snapshot(sm).combat.throws==count+1,"UI关闭后新单击可攻击")
	await _close_scene()
