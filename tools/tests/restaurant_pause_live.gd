extends "res://tools/tests/restaurant_rest05b.gd"

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"正式存档隔离")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_fresh()
		_open({A:3})
		var hud = await _open_restaurant()
		await get_tree().create_timer(0.6).timeout
		var sign = hud.find_child("RestaurantDaySign",true,false)
		var play = sign.get_node("OpenMenu")
		_check(sign.end_button.visible and not play.visible and sign.end_button.text.is_empty(),"正式营业显示无文字暂停按钮")
		_check(sign.end_button.position==play.position and sign.end_button.size==play.size,"暂停复用开始按钮位置及尺寸")
		await _shot("pause_live")
		await _click(sign.end_button)
		var modal = sign.end_confirmation
		_check(modal.get_script()==preload("res://scripts/ui/components/destination_confirmation.gd"),"复用迷宫二次确认组件")
		_check(modal.visible and modal.question.text=="确定结束今日营业？","只保留确认问句")
		var row: Control = modal.confirm_button.get_parent()
		var buttons: Rect2 = modal.cancel_button.get_global_rect().merge(modal.confirm_button.get_global_rect())
		_check(absf(buttons.get_center().x-modal.panel.get_global_rect().get_center().x)<2,"按钮整体几何居中")
		_check(row.alignment==BoxContainer.ALIGNMENT_CENTER,"按钮居中布局")
		var clock: float = Day.snapshot(sm).remaining
		await get_tree().create_timer(0.3).timeout
		_check(Day.snapshot(sm).remaining==clock and hud._player.input_locked,"确认期间暂停计时并锁定移动")
		await _shot("pause_confirmation_live")
		await _send_key(KEY_ESCAPE)
		_check(not modal.visible and not hud._player.input_locked and not hud.customer_flow.busy,"Esc取消恢复输入")
		await _click(sign.end_button)
		await _click(modal.cancel_button)
		_check(not modal.visible and not hud._player.input_locked,"鼠标取消恢复移动")
		await _click(sign.end_button)
		var path: String = sm._active_save_path
		sm._active_save_path = ""
		await _click(modal.confirm_button)
		_check(modal.visible and Day.snapshot(sm).status=="open","保存失败留窗重试")
		sm._active_save_path = path
		sm.data["preparation_lesson_seen"] = true
		await _click(modal.confirm_button)
		_check(not modal.visible and Day.snapshot(sm).status=="closing","确认真实结束营业")
		await _wait_until(func(): return is_instance_valid(hud.day_settlement) and not hud.day_settlement.introducing,300)
		_check(is_instance_valid(hud.day_settlement) and not hud.day_settlement._confirm_button.disabled,"结算动画结束可操作")
		await _click(hud.day_settlement._confirm_button)
		await get_tree().process_frame
		_check(Day.snapshot(sm).day==2 and not hud._player.input_locked,"进入明日准备恢复输入")
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
