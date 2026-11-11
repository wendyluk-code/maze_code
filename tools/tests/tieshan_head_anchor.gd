extends "res://tools/tests/tieshan_bubble_interaction.gd"

func _first_order() -> void:
	sm.data=sm._defaults()
	sm._active_save_path="user://tieshan-anchor.json"
	sm.data.prologue_done=true
	sm.data.chapter_1_intro="guest_arrived"
	_check(sm.accept_first_order().success,"真实首单接单")
	sm.save()
	scene=RESTAURANT.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene=scene
	await get_tree().create_timer(0.3).timeout
	tm.start()
	await get_tree().create_timer(0.5).timeout
	var guest=tm._parked_guest
	var bubble=guest.get_node("OrderBubble")
	await _send_key(KEY_E)
	await get_tree().create_timer(0.4).timeout
	var camera=get_viewport().get_camera_2d()
	camera.set_process(false)
	camera.set_physics_process(false)
	for zoom in [0.85,1.1]:
		camera.zoom=Vector2.ONE*zoom
		camera.global_position=guest.global_position+Vector2(100,140)
		camera.reset_smoothing()
		await get_tree().create_timer(0.2).timeout
		var portrait=guest.portrait
		var texture: Texture2D=portrait.sprite_frames.get_frame_texture(portrait.animation,portrait.frame)
		var pixels:=texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		var used:=pixels.get_used_rect()
		var band:=Rect2i(used.position,Vector2i(used.size.x,maxi(1,roundi(used.size.y*0.28))))
		var head:=pixels.get_region(band).get_used_rect()
		var x: float=band.position.x+head.position.x+head.size.x*0.5
		if portrait.flip_h: x=texture.get_width()-x
		var expected: Vector2=portrait.to_global(Vector2(x,used.position.y))-Vector2(0,6)
		_check(bubble.global_position.distance_to(expected)<1.0,"尖角固定铁山可见头顶 "+str(zoom),{"bubble":str(bubble.global_position),"expected":str(expected)})
		await _shot("tieshan_head_"+str(zoom))
	camera.global_position=guest.global_position+Vector2(0,650)
	camera.reset_smoothing()
	await get_tree().create_timer(0.2).timeout
	_check(bubble.modulate.a==0,"人物离开画面不把气泡钉在屏幕上沿")
	_check(not sm.deliver_first_order().success,"未制作交单拒绝")
	_check(bubble.visible,"交单失败保留订单气泡状态")
	_check(sm.claim_first_order_ingredients().success and sm.cook_first_order().success,"真实取料制作")
	_check(sm.deliver_first_order().success,"真实首单交付")
	await get_tree().create_timer(0.1).timeout
	_check(not bubble.visible,"交付成功气泡隐藏")
	tm._cancel_current_run()
	scene.queue_free()
	await get_tree().process_frame

