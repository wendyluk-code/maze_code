extends SceneTree
func _initialize() -> void:
	var report := {}
	for key in ["bar_counter", "register", "fridge", "food_cart"]:
		var img := Image.load_from_file("res://output/restaurant_layout/shadows/" + key + ".png")
		var rect := Rect2i()
		var started := false
		var samples := {}
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x,y)
				var bucket := str(int(c.a * 255.0))
				samples[bucket] = int(samples.get(bucket, 0)) + 1
				if c.a > 0.9:
					if not started:
						rect = Rect2i(x,y,1,1)
						started = true
					else:
						rect = rect.merge(Rect2i(x,y,1,1))
		report[key] = {"size":str(img.get_size()), "opaque_rect":str(rect), "alpha":samples}
	var f := FileAccess.open("res://output/restaurant_layout/shadows/alpha.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	quit()
