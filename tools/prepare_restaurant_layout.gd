extends SceneTree
## 将已批准设计稿裁去透明边并清理近透明背景，保留原稿。
func _initialize() -> void:
	var source := "res://output/restaurant_layout/draft_v1/"
	var target := "res://assets/restaurant_layout/"
	DirAccess.make_dir_recursive_absolute(target)
	var manifest := {}
	for key in ["cauldron", "food_cart", "fridge", "bar_counter", "register", "store", "stool_left", "stool_middle", "stool_right"]:
		var img := Image.load_from_file(source + key + ".png")
		assert(img != null)
		img.convert(Image.FORMAT_RGBA8)
		# 生成图背景存在1/255透明噪点；阈值仅清理近透明像素，保留抗锯齿。
		for y in img.get_height():
			for x in img.get_width():
				var color := img.get_pixel(x, y)
				color.a = 0.0 if color.a < 0.025 else minf(1.0, color.a / (253.0 / 255.0))
				img.set_pixel(x, y, color)
		var rect := img.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var cropped := img.get_region(rect)
		assert(cropped.save_png(target + key + ".png") == OK)
		manifest[key] = {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
	var bg := Image.load_from_file(source + "background_v2.png")
	assert(bg != null and bg.get_size() == Vector2i(1448, 1086))
	assert(bg.save_png(target + "background.png") == OK)
	var out := FileAccess.open("res://output/restaurant_layout/crop_manifest.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(manifest, "\t"))
	print(JSON.stringify(manifest))
	quit()
