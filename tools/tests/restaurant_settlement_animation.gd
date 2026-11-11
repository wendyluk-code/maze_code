extends "res://tools/tests/restaurant_rest04.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离正式存档")
	if failures==0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			get_window().size = resolution
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			for values in [[[0,-3]],[[180,-3]],[[0,0]],[[0,3]],[[20,2],[180,-3]],[[10,-2],[40,4],[0,-3],[120,6],[80,-4],[180,-3]],[[-3,-3]]]:
				await _animation_scene(values)
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)

func _animation_scene(values: Array) -> void:
	_seed_cycle()
	# 本专项验收结算输入锁；已完成来客教学，避免独立教学接管角色输入。
	sm.data[preload("res://scripts/ui/components/restaurant_arrival_lesson.gd").KEY] = {"phase":"done"}
	# 结算成功后未读的备餐教学会合法接管输入，图表专项使用已读状态。
	sm.data["preparation_lesson_seen"] = true
	Cycle.settle(sm,"time")
	# 隔离档中的展示夹具；真实餐厅负责弹窗、输入锁及确认事务。
	var records: Array = []
	for i in values.size():
		records.append({"day":i+1,"income":values[i][0],"reputation":values[i][1],"losses_known":true,"losses":{"slime_candy":1}})
	var stats: Dictionary = records.back().duplicate(true)
	sm.data[Day.KEY].day = values.size()
	sm.data[Day.KEY].history = records.slice(0,-1)
	sm.data[Day.KEY].settlement = stats
	sm.save()
	sm.load_data()
	scene = RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await get_tree().create_timer(0.15).timeout
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	await _wait_until(func(): return is_instance_valid(hud.day_settlement),90)
	var modal = hud.day_settlement
	_check(is_instance_valid(modal) and modal.visible,"读档真实餐厅展示结算")
	if not is_instance_valid(modal): return
	modal.open(stats)
	var chart = modal.chart
	_check(chart.progress==0.0 and chart.gold_points.size()==values.size(),"打开从零开始且不补未来日期")
	for i in values.size():
		_check(is_equal_approx(chart.gold_points[i].y,chart._y(0 if i==values.size()-1 else values[i][0])) and is_equal_approx(chart.rep_points[i].y,chart._y(0 if i==values.size()-1 else values[i][1])),"历史完整，今日柱从零线开始")
	var before: Dictionary = sm.data.duplicate(true)
	var axis := Vector2(chart.axis_min,chart.axis_max)
	var name := "%ddays_%s_%s" % [values.size(),stats.income,stats.reputation]
	await get_tree().create_timer(0.32).timeout
	_check(chart.progress>0.2 and chart.progress<0.8,"0.8秒动画中途尚未结束",{"progress":chart.progress})
	for i in values.size():
		_check(is_equal_approx(chart.gold_points[i].y,chart._y(float(values[i][0])*(chart.progress if i==values.size()-1 else 1.0))) and is_equal_approx(chart.rep_points[i].y,chart._y(float(values[i][1])*(chart.progress if i==values.size()-1 else 1.0))),"历史固定，仅今日柱增长")
		_check(chart.gold_labels[i].text==chart._number(round(float(values[i][0])*(chart.progress if i==values.size()-1 else 1.0))) and chart.rep_labels[i].text==chart._number(round(float(values[i][1])*(chart.progress if i==values.size()-1 else 1.0))),"图表数字跟随动画")
	var income_label: Label = modal.summary.get_children().filter(func(n): return n is Label and n.position==Vector2(184,12))[0]
	_check(income_label.text==str(roundi(float(stats.income)*chart.progress)),"左收入数字与图表同步")
	await _shot("animation_mid_"+name)
	await get_tree().create_timer(0.55).timeout
	_check(chart.progress==1.0 and chart.line_progress>0.0 and chart.line_progress<1.0,"今日柱完成后才绘制末段连线")
	await _shot("line_mid_"+name)
	await get_tree().create_timer(0.45).timeout
	_check(chart.progress==1.0 and not chart.is_processing(),"柱和连线分阶段结束后停止动画")
	_check(Vector2(chart.axis_min,chart.axis_max)==axis,"动画全程数值轴固定")
	_check(sm.data==before,"播放动画不更改经营数据或结算金额")
	var has_positive := values.any(func(v): return v[0]>0 or v[1]>0)
	_check(chart.axis_ticks.has(0.0) and (chart.axis_ticks.any(func(v): return v>0)==has_positive),"明确零刻度且全非正数据不显示正刻度")
	for i in values.size():
		_check(is_equal_approx(chart.gold_points[i].y,chart._y(values[i][0])) and is_equal_approx(chart.rep_points[i].y,chart._y(values[i][1])),"结束柱端为真实值")
		if values[i][1]<0:
			_check(chart.rep_labels[i].position.y>chart.rep_points[i].y,"负声望文字位于柱底外侧")
		if values[i][0]<0:
			_check(chart.gold_labels[i].position.y>chart.gold_points[i].y,"负金币文字位于柱底外侧")
		_check(chart.rep_labels[i].get_rect().end.y<=283 and chart.gold_labels[i].get_rect().end.y<=283,"数值标签不侵入日期区域")
	var rect: Rect2 = modal._panel.get_global_rect()
	_check(rect.position.x>=0 and rect.end.x<=get_viewport().get_visible_rect().size.x and rect.end.y<=get_viewport().get_visible_rect().size.y,"双尺寸布局完整")
	await _shot("animation_final_"+name)
	# 动画尚未结束便再次打开，旧节点必须停止且释放。
	modal.open(stats)
	var old_chart = modal.chart
	await get_tree().create_timer(0.12).timeout
	modal.open(stats)
	_check(not old_chart.is_processing() and modal.chart.progress==0,"重复打开清理旧动画并重新从零开始")
	await get_tree().process_frame
	_check(not is_instance_valid(old_chart),"旧图表释放，没有延迟回写")
	var path: String = sm._active_save_path
	sm._active_save_path = ""
	await _click(modal._confirm_button)
	_check(modal.visible and scene.get_node("Player").input_locked and modal._body_label.text.contains("保存失败"),"动画中确认保存失败保留弹窗及输入锁")
	_check(sm.data==before,"保存失败不改变结算及余额")
	sm._active_save_path = path
	await _click(modal._confirm_button)
	_check(not modal.visible and not scene.get_node("Player").input_locked and not modal.chart.is_processing(),"确认成功停止动画恢复输入",{"visible":modal.visible,"locked":scene.get_node("Player").input_locked,"processing":modal.chart.is_processing(),"depth":hud._player_lock_depth,"previous":hud._locked_before,"status":Day.snapshot(sm).status,"error":modal._body_label.text})
	_check(sm.gold_balance()==int(before.gold) and sm.reputation()==int(before.reputation),"确认不重复发金币声望")
	scene.queue_free()
	await get_tree().process_frame


