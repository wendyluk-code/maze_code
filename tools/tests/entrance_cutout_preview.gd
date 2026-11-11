extends "res://tools/tests/restaurant_rest05a.gd"

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	evidence=_arg("--output-dir=")
	_check(_verify_isolation(),"隔离预览存档")
	if failures==0:
		_seed_cycle()
		sm.data[Lesson.KEY]={"phase":"done"}
		var hud=await _open_restaurant()
		hud.hide()
		hud.customer_flow.set_process(false)
		var tracker=get_tree().get_first_node_in_group("order_tracking")
		tracker.hide()
		var camera=get_viewport().get_camera_2d()
		camera.set_process(false)
		camera.paused=true
		camera.set_physics_process(false)
		camera.position_smoothing_enabled=false
		camera.zoom=Vector2(1.65,1.65)
		var layer:=CanvasLayer.new()
		layer.layer=115
		add_child(layer)
		var dim:=ColorRect.new()
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.color=preload("res://scripts/ui/components/modal_style.gd").BACKDROP
		layer.add_child(dim)
		var shader=preload("res://scripts/ui/tutorial_task_cutout.gdshader")
		var material:=ShaderMaterial.new()
		material.shader=shader
		dim.material=material
		var dialog=preload("res://scenes/ui/dialog_box.tscn").instantiate()
		layer.add_child(dialog)
		for which in ["home","maze"]:
			var target=scene.get_node("InteractPoints/AdventurerHomeDoor" if which=="home" else "DepartureEntrance")
			camera.global_position=target.global_position+Vector2(0,70)
			camera.reset_smoothing()
			camera.force_update_scroll()
			await get_tree().process_frame
			var highlight=preload("res://scripts/ui/entrance_highlight.gd").new()
			highlight.configure_entrance(which)
			highlight.background=scene.get_node("BG")
			layer.add_child(highlight)
			# 依据用户标注的1280×720绿框范围，仅用于设计预览。
			var bounds := Rect2(899,147,371,394) if which=="home" else Rect2(36,64,385,370)
			var factor: Vector2 = dim.size / Vector2(1280,720)
			print("CUTOUT_WORLD ",which," ",highlight.background.get_global_transform_with_canvas().affine_inverse()*bounds)
			material.set_shader_parameter("overlay_size",dim.size)
			material.set_shader_parameter("ingredients_rect",Vector4(bounds.position.x*factor.x,bounds.position.y*factor.y,bounds.size.x*factor.x,bounds.size.y*factor.y))
			dialog.start("芽芽",[preload("res://scripts/chapter_1_outro.gd").HOME_LINE if which=="home" else preload("res://scripts/chapter_1_outro.gd").MAZE_LINE],load("res://assets/characters/yaya_portrait.png"))
			dialog._advance(false)
			await _shot("entrance_cutout_"+which)
			highlight.queue_free()
		layer.queue_free()
		await _close_restaurant()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
	var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
