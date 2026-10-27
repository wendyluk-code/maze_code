extends "res://tools/tests/team_entry_01.gd"
## 在真实餐厅流程后增加只读UI夹具；生产角色表和存档结构不变。
class Fixture:
	extends "res://scripts/ui/components/team_entry_modal.gd"
	var roster: Array = []
	var configurations: Dictionary = {}
	func _init() -> void:
		for i in 24:
			var id := "fixture_%02d" % i
			roster.append(id)
			var config: Dictionary = Progression.CHARACTERS.yaya.duplicate(true)
			config.name = "验收角色%02d" % i
			config.faction = ["grass", "earth", "lightning", "water", "wind", "fire"][i % 6]
			if i % 2 == 1: config.portrait = Progression.CHARACTERS.tieshan.portrait
			config.skills = []
			for j in 6:
				config.skills.append(["验收技能%d" % j, "这是一段隔离验收技能正文，用于验证整列宽度自动换行和完整滚动，不代表生产技能或数值。即使文字较长也必须全部保留，不能按短行截断。末尾标记%d。" % j])
			configurations[id] = config
	func _owned() -> Array: return roster
	func _config(id: String) -> Dictionary: return configurations.get(id, {})
	func _record(_id: String) -> Dictionary: return {"valid":true, "attack":7, "satiety_max":5, "rank":6}
	func _food_snapshot() -> Dictionary:
		var values := {}
		for id in roster: values[id] = 0.5
		return {"valid":true, "values":values}

func _entry_scene() -> void:
	await super._entry_scene()
	_completed()
	sm.cancel_maze_entry()
	await _restaurant()
	_check(modal.recommendations == ["grass", "thunder"], "首区4土3水3风按数量和既有稳定顺序推荐草雷")
	_check(Team.region_recommendations([]).is_empty(), "空区域不伪造推荐")
	_check(Team.region_recommendations([{"element":"lightning"}]) == ["earth"], "lightning与thunder映射兼容且土克雷")
	_check(Team.region_recommendations([{"element":"fire"}]) == ["wind"], "沿用风克火不修改克制环")
	await _click(modal.slots[0])
	await _tab_click(modal.tabs, 1)
	_check(modal.checks.keys() == ["yaya"], "草系筛选只显示已拥有芽芽")
	await _click(modal.checks.yaya)
	await _capture_image("filter_grass_selected")
	_check(modal.row_panels.yaya.size.x >= modal.selection_rows.size.x - 1, "选中行背景铺满至滚动条前")
	_check(modal.mini_slots[0].get_meta("character") == "yaya", "框外缩略槽实时显示草稿")
	await _tab_click(modal.tabs, 3)
	_check(modal.checks.is_empty() and modal.selection_rows.get_child(0).text.contains("暂无"), "无已拥有雷角色显示空态")
	await _capture_image("filter_empty")
	await _tab_click(modal.tabs, 2)
	_check(modal.checks.keys() == ["tieshan"], "土系筛选只显示铁山")
	await _click(modal.checks.tieshan)
	await _click(modal.selection_done)
	_check(not modal.selector.visible and modal.visible and sm.remembered_maze_party().is_empty(), "选择确认只返回组队不进入不记忆")
	_check(not modal.food_value.text.contains("/"), "组队总饱腹仅当前值")
	_check(modal.chart.elements == ["grass", "earth"], "属性图来自当前队伍")
	await _capture_image("reference_team")
	var tops := [modal.basic_content.global_position.y, modal.chart.global_position.y, modal.skills_text.global_position.y]
	_check(absf(tops[0] - tops[1]) < 0.1 and absf(tops[0] - tops[2]) < 0.1, "三列详情内容起点严格同高", {"resolution":str(get_window().size), "basic_chart_skills_top":tops})
	_check(modal.skills_text.get_child_count() == 3 and modal.skills_text.get_child(1) is ColorRect, "两技能之间存在独立细分隔线")
	await _click(modal.slot_names[0])
	_check(modal.details.visible and modal.details.character_id == "yaya", "组队姓名可查看真实详情")
	await _send_key(KEY_ESCAPE)
	await _click(modal.close_button)
	_check(not modal.visible and not hud._player.input_locked, "组队右上关闭恢复餐厅输入")
	await _send_key(KEY_E)
	await _click(modal.slots[0])
	await _click(modal.selection_close)
	_check(modal.visible and not modal.selector.visible, "选人右上关闭只返回组队")
	await _click(modal.cancel_button)
	await _fixture_checks()
	scene.queue_free()
	await get_tree().process_frame

func _tab_click(target: TabBar, index: int) -> void:
	await _click_point(target.global_position + target.get_tab_rect(index).get_center())

func _click_point(point: Vector2) -> void:
	get_viewport().warp_mouse(point)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame

func _wheel(control: Control, count: int) -> void:
	var point := control.get_global_rect().get_center()
	get_viewport().warp_mouse(point)
	for i in count:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		get_viewport().push_input(event)
		await get_tree().process_frame
		event = event.duplicate()
		event.pressed = false
		get_viewport().push_input(event)
		await get_tree().process_frame

func _fixture_checks() -> void:
	var before: Dictionary = sm.data.duplicate(true)
	var fixture := Fixture.new()
	# 挂入真实餐厅原弹窗画布，以同一输入/绘制层进行等价控件操作。
	modal.get_parent().add_child(fixture)
	fixture.open_exploration()
	await get_tree().process_frame
	await _click(fixture.slots[0])
	_check(fixture.checks.size() == 24, "隔离长名单显示全部24名已拥有角色")
	for i in 4:
		var id := "fixture_%02d" % i
		fixture.selection_scroll.ensure_control_visible(fixture.checks[id])
		await get_tree().process_frame
		await _click(fixture.checks[id])
	_check(fixture.selected == ["fixture_00", "fixture_01", "fixture_02", "fixture_03"], "鼠标选择四人并保留顺序")
	fixture.selection_scroll.ensure_control_visible(fixture.checks.fixture_04)
	await get_tree().process_frame
	await _click(fixture.checks.fixture_04)
	_check(fixture.selected.size() == 4 and not fixture.checks.fixture_04.button_pressed, "第五人受上限约束且按钮回退")
	await _wheel(fixture.selection_scroll, 80)
	await get_tree().process_frame
	var end: Control = fixture.selection_rows.get_node("ListEnd")
	_check(fixture.selection_scroll.scroll_vertical > 0 and fixture.selection_scroll.get_global_rect().encloses(end.get_global_rect()), "鼠标滚轮真实滚到长名单末尾及到底文字")
	var end_row: HBoxContainer = end.get_child(0)
	_check(end_row.get_child_count() == 3 and end_row.get_child(0) is ColorRect and end_row.get_child(2) is ColorRect and end_row.get_child(0).size.x == 165 and end_row.get_child(2).size.x == 165, "到底文案两侧有等长真实短分割线")
	await _capture_image("fixture_list_end")
	await _click(fixture.selection_done)
	_check(not fixture.selector.visible, "夹具确认实际关闭选人页", {"button_rect":str(fixture.selection_done.get_global_rect()), "hover":str(get_viewport().gui_get_hovered_control())})
	_check(fixture.chart.elements == ["grass", "earth", "thunder", "water"], "四种属性均来自选中成员且雷映射一致")
	_check(fixture.food_value.text == "2" and fixture.power_value.text == "28", "四人当前饱腹向下取整且基础战力28")
	_check(not fixture.confirm_button.disabled and fixture.recommendations.size() <= 2, "推荐无门禁四人允许进入")
	_check(fixture.skill_count.text == "已解锁 24 项" and fixture.skills_text.text.count("末尾标记") == 24, "四人24项解锁技能全文保留")
	_check(get_viewport().get_visible_rect().encloses(fixture.team_panel.get_global_rect()), "四人长文面板在视口内")
	_check(fixture.slots.all(func(slot): return slot.size.x == slot.size.y), "四个头像均为正方形")
	await _capture_image("fixture_four_elements")
	await _wheel(fixture.skills_scroll, 250)
	var bar := fixture.skills_scroll.get_v_scroll_bar()
	_check(bar.value > 0 and absf(bar.value - (bar.max_value - bar.page)) < 2, "鼠标滚轮将24项长技能全部滚到最后")
	await _capture_image("fixture_skills_end")
	await _click(fixture.slots[0])
	await _tab_click(fixture.tabs, 3)
	_check(fixture.checks.size() == 4 and fixture.checks.has("fixture_02"), "雷筛选正确显示lightning角色")
	await _click(fixture.checks.fixture_02)
	await _click(fixture.selection_done)
	_check(not fixture.selector.visible, "夹具确认实际关闭选人页", {"button_rect":str(fixture.selection_done.get_global_rect()), "hover":str(get_viewport().gui_get_hovered_control())})
	_check(not fixture.chart.elements.has("thunder") and fixture.chart.elements.size() == 3, "移除雷角色立即移除节点高亮与出向箭头")
	await _capture_image("fixture_three_elements")
	await _click(fixture.slots[0])
	fixture.tabs.grab_focus()
	await _send_key(KEY_RIGHT)
	_check(fixture.tabs.current_tab == 1, "TabBar支持键盘左右筛选")
	for i in 30: await _send_key(KEY_TAB)
	_check(fixture.selection_panel.is_ancestor_of(get_viewport().gui_get_focus_owner()), "长名单Tab焦点仍限制在选人页")
	await _send_key(KEY_ESCAPE)
	_check(not fixture.selector.visible and fixture.visible, "长名单Esc返回组队")
	_check(sm.data == before, "UI夹具与筛选滚动全过程不修改真实经营状态")
	fixture.queue_free()
	await get_tree().process_frame
