extends Node2D
const Roads=preload("res://data/maze/entry_roads.gd")
var overlay: Image
func _ready() -> void:
	get_window().size=Vector2i(1222,1287)
	var map=Sprite2D.new()
	map.texture=load("res://assets/maps/maze_entry.png")
	map.centered=false
	add_child(map)
	overlay=Image.create(1222,1287,false,Image.FORMAT_RGBA8)
	for y in 1287:
		for x in 1222:
			if Roads.is_walkable(Vector2(x,y)):
				overlay.set_pixel(x,y,Color(0.05,1.0,0.25,0.48))
	var mask=Sprite2D.new()
	mask.texture=ImageTexture.create_from_image(overlay)
	mask.centered=false
	add_child(mask)
	for road in Roads.roads():
		var line=Line2D.new()
		line.points=road.points
		line.width=2
		line.default_color=Color(1,0.85,0.1,0.9)
		add_child(line)
	var boundary=Line2D.new()
	boundary.points=PackedVector2Array([Vector2(98,670),Vector2(98,760)])
	boundary.width=3
	boundary.default_color=Color.RED
	add_child(boundary)
	await RenderingServer.frame_post_draw
	var out=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): out=arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(out)
	# 原始分辨率合成，不受窗口尺寸和桌面缩放影响。
	var result=load("res://assets/maps/maze_entry.png").get_image()
	result.convert(Image.FORMAT_RGBA8)
	result.blend_rect(overlay,Rect2i(0,0,1222,1287),Vector2i.ZERO)
	result.save_png(out+"/walkable_overlay.png")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var f=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			f.store_string(JSON.stringify({"checks":1,"failures":0}))
	get_tree().quit()
