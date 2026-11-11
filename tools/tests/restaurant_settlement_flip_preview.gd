extends "res://tools/tests/restaurant_rest05b.gd"
## 纯效果预览：独立蒙层/卡片与现有结算组件，不接正式触发。

func _run() -> void:
	Engine.max_fps = 60
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"预览使用隔离存档")
	for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
		get_window().size = resolution
		suffix = "_%dx%d" % [resolution.x,resolution.y]
		_fresh()
		var hud = await _open_restaurant()
		hud._lock_player()
		hud.customer_flow.set_process(false)
		var sign = hud.find_child("RestaurantDaySign",true,false)
		sign.set_process(false)
		sign.status_label.text = "结算中"
		sign.details_label.text = "第 1 天"
		sign.get_node("OpenMenu").hide()
		sign.end_button.hide()
		var layer := CanvasLayer.new()
		layer.layer = 120
		scene.add_child(layer)
		var modal := preload("res://scripts/ui/components/restaurant_day_settlement.gd").new()
		layer.add_child(modal)
		# 展示数值取用户参考截图，仅用于设计预览。
		modal.open({"day":1,"income":50,"reputation":179,"losses":{},"losses_known":true,"portions_complete":true,"menu_sold":2,"menu_lost":0})
		modal.set_process_input(false)
		modal.chart.stop_animation()
		modal.chart._apply_progress(0)
		modal._panel.hide()
		var factor := minf(resolution.x/1280.0,resolution.y/720.0)
		var card := Panel.new()
		card.theme = SproutTheme.make_theme()
		card.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style(SproutTheme.PANEL))
		card.size = Vector2(520,150)
		card.scale = Vector2.ONE*factor
		card.pivot_offset = card.size*0.5
		card.position = Vector2(resolution)*0.5-card.size*0.5
		layer.add_child(card)
		var title := Label.new()
		title.text = "今日营业完成"
		title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size",38)
		card.add_child(title)
		await get_tree().process_frame
		await _shot("flip_01_business_complete")
		await get_tree().create_timer(0.8).timeout
		var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		turn.tween_property(card,"scale:x",factor*0.04,0.25)
		await turn.finished
		await _shot("flip_02_card_edge")
		card.hide()
		modal._panel.pivot_offset = modal._panel.size*0.5
		modal._panel.position = Vector2(resolution)*0.5-modal._panel.size*0.5
		modal._panel.scale = Vector2(0.04,0.28)*factor
		modal._panel.show()
		var reveal := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		reveal.tween_property(modal._panel,"scale",Vector2.ONE*factor,0.4)
		await get_tree().create_timer(0.16).timeout
		await _shot("flip_03_settlement_revealing")
		await reveal.finished
		modal.chart.progress = 0
		modal.chart.set_process(true)
		await get_tree().create_timer(0.9).timeout
		await _shot("flip_04_settlement_complete")
		_check(modal._panel.scale.is_equal_approx(Vector2.ONE*factor),"翻面结束恢复结算尺寸")
		_check(modal.chart.progress==1,"翻面后图表动画完成")
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
