extends SceneTree
## 将生成动作表按实测边界切片；只裁切和对齐，不拉伸各姿势。
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/characters/tieshan/tieshan_collapse_sheet.png")
	var columns := [0, 443, 887, 1330, 1774]
	for i in 8:
		var col := i % 4
		var top := 0 if i < 4 else 490
		var bottom := 470 if i < 4 else 887
		var region := Rect2i(columns[col], top, columns[col + 1] - columns[col], bottom - top)
		var cell := source.get_region(region)
		# 高透明度边缘不影响脚底测量；原 alpha（透明度）保留到最终纹理。
		var left := cell.get_width()
		var right := 0
		var foot := 0
		for y in cell.get_height():
			for x in cell.get_width():
				if cell.get_pixel(x, y).a > 0.5:
					left = mini(left, x)
					right = maxi(right, x + 1)
					foot = maxi(foot, y + 1)
		var frame := Image.create(480, 480, false, Image.FORMAT_RGBA8)
		frame.blit_rect(cell, Rect2i(0, 0, cell.get_width(), cell.get_height()),
			Vector2i(240 - (left + right) / 2, 448 - foot))
		var path := "res://assets/characters/tieshan/collapse_%02d.png" % i
		assert(frame.save_png(path) == OK)
		print("FRAME ", i, " source_foot=", foot, " x_bounds=", left, ",", right)
	quit()
