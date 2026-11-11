extends "res://output/restaurant_day_design/preview.gd"

class TopSign extends Control:
	func _draw() -> void:
		var shape := PackedVector2Array([Vector2(0,-4),Vector2(180,-4),Vector2(176,48),Vector2(166,56),Vector2(90,61),Vector2(14,56),Vector2(4,48)])
		var shadow := PackedVector2Array()
		for point in shape: shadow.append(point+Vector2(0,3))
		draw_colored_polygon(shadow,Color(0.20,0.12,0.05,0.22))
		draw_colored_polygon(shape,Color("edd19c"))
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge,Color("926739"),2,true)
		draw_polyline(PackedVector2Array([Vector2(8,0),Vector2(11,44),Vector2(20,49),Vector2(90,54),Vector2(160,49),Vector2(169,44),Vector2(172,0)]),Color("fff0c9"),1.5,true)
		for x in [18,162]:
			draw_circle(Vector2(x,7),2,Color("ac8150"),true,-1,true)

class PlayButton extends Button:
	func _ready() -> void:
		for state in ["normal","hover","pressed","focus"]:
			add_theme_stylebox_override(state,StyleBoxEmpty.new())
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(16,13),Vector2(16,27),Vector2(28,20)]),Color("607e43"))
		draw_polyline(PackedVector2Array([Vector2(16,13),Vector2(16,27),Vector2(28,20),Vector2(16,13)]),Color("4e6638"),1.5,true)

func _ready() -> void:
	theme=SproutTheme.make_theme()
	for resolution in [Vector2i(1280,720),Vector2i(1152,648)]:
		get_window().size=resolution
		await get_tree().process_frame
		for operating in [false,true]:
			build_hud(operating)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://hud_%s_%dx%d.png" % ["operating" if operating else "preparing",resolution.x,resolution.y])
	print("HUD_PREVIEW_OK: two states, two resolutions; screenshot background, no game state")
	get_tree().quit()

func build_hud(operating: bool) -> void:
	if is_instance_valid(canvas):
		remove_child(canvas)
		canvas.queue_free()
	canvas=Control.new()
	add_child(canvas)
	canvas.scale=Vector2(get_viewport_rect().size.x/1280.0,get_viewport_rect().size.y/720.0)
	var bg := TextureRect.new()
	bg.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/ui/restaurant_reference.png"))
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	place(bg,canvas,Rect2(0,0,1280,720))
	var sign := TopSign.new()
	place(sign,canvas,Rect2(550,0,180,62))
	var state := label_at(sign,"营业中" if operating else "准备中",Rect2(22 if not operating else 10,14,102 if not operating else 160,36),22)
	state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not operating:
		var play := PlayButton.new()
		play.tooltip_text="选择今日菜单"
		place(play,sign,Rect2(126,12,44,40))
	var day := label_at(canvas,"第 2 天",Rect2(438,18,96,36),21,SproutTheme.CREAM)
	day.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var timer := label_at(canvas,"04:32" if operating else "00:48:26",Rect2(746,18,125,36),23,SproutTheme.CREAM)
	for text_node in [day,timer]:
		text_node.add_theme_color_override("font_outline_color",SproutTheme.INK)
		text_node.add_theme_constant_override("outline_size",4)
	var note := label_at(canvas,"位置效果图 · 示例时间",Rect2(473,677,334,28),17,SproutTheme.CREAM)
	note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_outline_color",SproutTheme.INK)
	note.add_theme_constant_override("outline_size",4)



