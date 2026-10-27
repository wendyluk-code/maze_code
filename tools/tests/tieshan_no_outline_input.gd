extends "res://tools/tests/post_chapter_acceptance.gd"
## 资源替换的视觉回归：实测透明轮廓接地、真实动画与上菜后的微笑停帧。

func _opaque_bounds(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := 0
	var bottom := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a > 0.5:
				left = mini(left,x)
				top = mini(top,y)
				right = maxi(right,x+1)
				bottom = maxi(bottom,y+1)
	return Rect2i(left,top,right-left,bottom-top)

func _run() -> void:
	sm = get_node("/root/SaveManager")
	tm = get_node("/root/TutorialManager")
	evidence = _arg("--output-dir=")
	_check(_verify_isolation(),"隔离存档")
	if failures == 0:
		for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
			DisplayServer.window_set_size(resolution)
			suffix = "_%dx%d" % [resolution.x,resolution.y]
			await _visual_flow()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	print("TIESHAN_NO_OUTLINE ",checks," checks, ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _await_motion(predicate: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await get_tree().create_timer(0.016).timeout
	return predicate.call()

func _visual_flow() -> void:
	sm.data = sm._defaults()
	sm._active_save_path = "user://tieshan-no-outline.json"
	sm.data.prologue_done = true
	sm.data.chapter_1_intro = "guest_arrived"
	_check(sm.save() and sm.accept_first_order().success and sm.claim_first_order_ingredients().success and sm.cook_first_order().success,"待上菜场景前置事务")
	await _open_scene()
	var camera = scene.get_node("Camera")
	camera.paused = true
	camera.global_position = Vector2(724,400)
	await get_tree().process_frame
	var guest = tm._parked_guest
	_check(is_instance_valid(guest),"真实餐厅生成铁山")
	if not is_instance_valid(guest):
		await _close_scene()
		return
	var frames: SpriteFrames = guest.portrait.sprite_frames
	for i in 8:
		var texture := frames.get_frame_texture(&"collapse",i)
		var image := texture.get_image()
		var box := _opaque_bounds(image)
		_check(image.get_size() == Vector2i(480,480) and box.end.y == 448,"倒地／起身实际像素脚底统一：%d" % i)
		_check(image.get_pixel(0,0).a == 0 and image.get_pixel(479,479).a == 0,"帧背景透明：%d" % i)
		if i == 0:
			var height: float = box.size.y * guest.COLLAPSE_SCALE.y
			_check(height > 147 and height < 152,"去边后站立人物高度保留",{"height":height})
	guest.settle_prone()
	guest.play_collapse()
	await _shot("standing")
	_check(await _await_motion(func():return guest.collapse_completed,4.0),"倒地动画完整结束")
	await _shot("prone")
	var origin: Vector2 = guest.position
	var rise_points: Dictionary = {}
	var handler := func():
		if guest.seating_phase == "rising":
			rise_points[guest.portrait.frame] = guest.portrait.to_global(Vector2(240,448))
	guest.portrait.frame_changed.connect(handler)
	guest.play_seating()
	_check(await _await_motion(func():return guest.seating_phase == "fade_out",5.0),"起身后进入渐隐")
	await _shot("rise_standing")
	var first_foot: Vector2 = rise_points.get(0,Vector2.INF)
	_check(rise_points.size() == 8 and rise_points.values().all(func(point):return point.distance_to(first_foot)<0.001 and absf(point.y-origin.y)<0.001),"起身全八帧实际脚底在原地",{"frames":str(rise_points),"origin":str(origin)})
	_check(guest.ground_shadow.global_position.distance_to(origin)<0.001,"阴影贴合原地脚底")
	_check(await _await_motion(func():return guest.seating_completed,3.0),"渐显落座完成")
	guest.portrait.frame_changed.disconnect(handler)
	_check(guest.seating_phase == "waiting" and guest.portrait.flip_h and guest.position.distance_to(Vector2(471,271))<1,"第一张椅子朝右等待")
	_check(is_equal_approx(guest.portrait.scale.x,0.427142857),"坐姿缩放未变")
	await _shot("seated_waiting")
	var bar = scene.get_node("InteractPoints/BarCounter")
	scene.get_node("Player").global_position = _stand(bar)
	_check(await _await_motion(func():return tm.steps[tm.idx].get("type") == "interact" and tm.steps[tm.idx].get("target") == "吧台",2.0),"走近吧台后等待教学切换至上菜交互")
	await _use("InteractPoints/BarCounter")
	_check(sm.has_first_order_settlement() and guest.satisfied_started,"实际按E上菜触发满意动画")
	_check(await _await_motion(func():return guest.satisfied_completed,3.0),"满意动画到达微笑")
	_check(guest.seating_phase == "satisfied_smile" and guest.portrait.frame == 3 and guest.portrait.flip_h,"微笑末帧朝右")
	_check(is_equal_approx(guest.portrait.scale.x,0.228825),"满意坐姿缩放未变")
	await _shot("satisfied_smile")
	await get_tree().create_timer(1.0).timeout
	_check(guest.portrait.frame == 3 and guest.seating_phase == "satisfied_smile","微笑最后一帧持续保留")
	await _close_scene()
