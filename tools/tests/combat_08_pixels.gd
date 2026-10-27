extends "res://tools/tests/combat_07_flow.gd"

func _render_sample(view: SubViewport, sprite: Sprite2D, material: Material, label: String) -> Image:
	sprite.material = material
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var folder := _arg("--output-dir=")
	DirAccess.make_dir_recursive_absolute(folder)
	image.save_png(folder.path_join(label+".png"))
	return image

func _compare_body(source: Sprite2D, label: String) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(512,512)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var sprite := Sprite2D.new()
	sprite.texture = source.texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.position = Vector2(256,256)
	sprite.scale = Vector2.ONE * 320.0 / maxf(sprite.texture.get_width(),sprite.texture.get_height())
	view.add_child(sprite)
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/maze/hit_flash.gdshader")
	for tint in [Color.WHITE, Color(0.7,0.8,0.9,0.6)]:
		sprite.modulate = tint
		var name_suffix := "_plain" if tint==Color.WHITE else "_tinted"
		var baseline := await _render_sample(view,sprite,null,label+name_suffix+"_original")
		material.set_shader_parameter("flash",false)
		var off := await _render_sample(view,sprite,material,label+name_suffix+"_off")
		material.set_shader_parameter("flash",true)
		var white := await _render_sample(view,sprite,material,label+name_suffix+"_white")
		var changed := 0
		var alpha_changed := 0
		var max_difference := 0.0
		var white_error := 0.0
		var visible := 0
		for y in 512:
			for x in 512:
				var a := baseline.get_pixel(x,y)
				var b := off.get_pixel(x,y)
				var c := white.get_pixel(x,y)
				var difference := maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),maxf(absf(a.b-b.b),absf(a.a-b.a)))
				if difference>0.0: changed+=1
				max_difference=maxf(max_difference,difference)
				if absf(a.a-c.a)>0.0: alpha_changed+=1
				if c.a>0.05:
					visible+=1
					# 透明视口读回的是预乘alpha颜色；白色输出的RGB应等于alpha。
					white_error=maxf(white_error,maxf(absf(c.r-c.a),maxf(absf(c.g-c.a),absf(c.b-c.a))))
		_check(changed==0,"关闭闪白逐像素等同无材质："+label+name_suffix,{"changed_pixels":changed,"max_channel_difference":max_difference})
		_check(alpha_changed==0,"白闪透明度逐像素保持："+label+name_suffix,{"alpha_changed_pixels":alpha_changed})
		_check(visible>0 and white_error<=0.01,"白闪可见主体为白色："+label+name_suffix,{"visible_pixels":visible,"max_white_error":white_error})
	view.queue_free()
	await get_tree().process_frame

func _run() -> void:
	sm=get_node("/root/SaveManager")
	tm=get_node("/root/TutorialManager")
	_check(_verify_isolation(),"隔离正式存档")
	await _new_scene()
	maze.capture_flow.set_process(false)
	maze.player.set_process(false)
	maze.player.set_physics_process(false)
	await _compare_body(maze.player.body,"hero")
	await _compare_body(maze.capture_flow.monsters.slime_1.body,"slime")
	await _close_scene()
	var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"\t"))
	get_tree().quit(1 if failures else 0)
