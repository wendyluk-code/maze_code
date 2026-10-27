extends SceneTree
## 只读核验批准指针的 alpha 边界，不生成或修改图片。
func _init() -> void:
	var source := Image.load_from_file("res://assets/ui/cooking/cooking_pointer_v1.png")
	var bounds := [Rect2i(), Rect2i(), Rect2i()]
	var thresholds := [.05, .5, .95]
	for y in source.get_height():
		for x in source.get_width():
			var alpha := source.get_pixel(x,y).a
			for index in range(3):
				if alpha >= thresholds[index]:
					var pixel := Rect2i(x,y,1,1)
					bounds[index] = pixel if not bounds[index].has_area() else bounds[index].merge(pixel)
	for index in range(3):
		print("ALPHA ", thresholds[index], " BOUNDS ", bounds[index])
	quit()
