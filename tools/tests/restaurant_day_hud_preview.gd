extends "res://tools/tests/restaurant_layout.gd"

func _layout_checks() -> void:
	sm.data=sm._defaults()
	sm.data.prologue_done=true
	sm.data.chapter_1_intro="guest_arrived"
	for method in ["accept_first_order","claim_first_order_ingredients","cook_first_order","deliver_first_order"]:
		_check(sm.call(method).success,method)
	for step in sm.WRAPUP_STEPS:
		if sm.RETIRED_WRAPUP_STEPS.has(step) or step=="ready_to_depart": continue
		sm.advance_departure(step)
	for step in ["party","home","maze","title"]: sm.advance_chapter_1_outro(step)
	scene=RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().create_timer(0.5).timeout
	var layer := CanvasLayer.new()
	layer.layer=90
	scene.add_child(layer)
	var Preview = load("res://tools/tests/restaurant_day_hud_art.gd")
	for resolution in [Vector2i(1280,720),Vector2i(1152,648)]:
		get_window().size=resolution
		await get_tree().process_frame
		await get_tree().process_frame
		for operating in [false,true]:
			var root := Control.new()
			layer.add_child(root)
			root.theme=SproutTheme.make_theme()
			var sign = Preview.TopSign.new()
			root.add_child(sign)
			sign.position=Vector2(resolution.x/2.0-90,4)
			sign.size=Vector2(180,62)
			var title := Label.new()
			sign.add_child(title)
			title.text="营业中" if operating else "准备中"
			title.position=Vector2(10 if operating else 22,14)
			title.size=Vector2(160 if operating else 102,36)
			title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			title.add_theme_font_size_override("font_size",22)
			if not operating:
				var play = Preview.PlayButton.new()
				sign.add_child(play)
				play.position=Vector2(126,12)
				play.size=Vector2(44,40)
			for i in range(2):
				var value := Label.new()
				root.add_child(value)
				value.text="第 2 天" if i==0 else ("04:32" if operating else "00:48:26")
				value.position=Vector2(sign.position.x-112 if i==0 else sign.position.x+196,18)
				value.size=Vector2(96 if i==0 else 125,36)
				value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT if i==0 else HORIZONTAL_ALIGNMENT_LEFT
				value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
				value.add_theme_font_size_override("font_size",21)
				value.add_theme_color_override("font_color",SproutTheme.CREAM)
				value.add_theme_color_override("font_outline_color",SproutTheme.INK)
				value.add_theme_constant_override("outline_size",4)
				_check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(value.get_global_rect()),"日期/时间在实际视口内")
			_check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(sign.get_global_rect()),"牌子在实际视口内")
			await _capture(_arg("--output-dir="),"hud_%s_%dx%d" % ["operating" if operating else "preparing",resolution.x,resolution.y])
			root.queue_free()
			await get_tree().process_frame

