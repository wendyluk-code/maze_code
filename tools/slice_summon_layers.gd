extends SceneTree
## 用生成的无内容底板做背景解混；保留批准稿角色、姓名与按钮原像素。
const OUT := "res://assets/ui/summon/"
const SOURCE := "res://output/summon_ui/approved_reference.png"
const PLATE := "res://output/summon_ui/revision_02/clean_plate_source.png"
var reference: Image
var plate: Image
var guide: Image
var records := {}

func _initialize() -> void:
	reference = Image.load_from_file(SOURCE)
	plate = Image.load_from_file(PLATE)
	guide = Image.load_from_file("res://output/summon_ui/revision_02/extraction_guide.png")
	guide.resize(1003, 565, Image.INTERPOLATE_LANCZOS)
	assert(reference.get_size() == plate.get_size())
	reference.convert(Image.FORMAT_RGBA8)
	plate.convert(Image.FORMAT_RGBA8)
	_extract("key_visual", Rect2i(350, 140, 1030, 454))
	_extract("name_dingdang", Rect2i(450, 594, 137, 31))
	_extract("name_salia", Rect2i(770, 594, 162, 31))
	_extract("name_yufeng", Rect2i(1120, 594, 132, 31))
	_extract("heading", Rect2i(234, 162, 151, 56))
	_extract("single_button", Rect2i(523, 632, 344, 88))
	_extract("ten_button", Rect2i(881, 632, 345, 88))
	# 名义价格保持可读原稿字形，颜色由原生控件状态调制。
	_extract("single_price", Rect2i(628, 719, 133, 27))
	_extract("ten_original_price", Rect2i(949, 719, 92, 27))
	_extract("ten_price", Rect2i(1043, 719, 118, 27))
	var panel_rect := Rect2i(168, 140, 1445, 635)
	# 空白处直接保留批准稿底色，只有独立切层的矩形从无内容底板取样。
	var panel := reference.get_region(panel_rect)
	for label in records:
		var region: Array = records[label].rect
		var rect := Rect2i(region[0], region[1], region[2], region[3])
		for y in rect.size.y:
			for x in rect.size.x:
				var p := rect.position + Vector2i(x,y)
				if label == "key_visual" and p.y < 200 and (p.x < 694 or p.x > 966): continue
				panel.set_pixelv(p-panel_rect.position,plate.get_pixelv(p))
	for y in panel.get_height():
		for x in panel.get_width():
			var global := Vector2i(x, y) + panel_rect.position
			# 去掉底板中落在玻璃内的旧页签碎片；原生页签继续盖在玻璃上。
			if global.x < 264 and global.y >= 216 and global.y <= 427:
				panel.set_pixel(x, y, plate.get_pixel(265, global.y))
			var center := Vector2(clampf(x, 32, panel.get_width()-33), clampf(y, 32, panel.get_height()-33))
			var a := clampf(33.0 - Vector2(x, y).distance_to(center), 0, 1)
			var c := panel.get_pixel(x, y)
			c.a = a
			panel.set_pixel(x, y, c)
	panel.save_png(OUT + "panel_backplate.png")
	records["panel_backplate"] = {"rect": [168, 140, 1445, 635], "kind": "生成无内容底板，仅取玻璃范围"}
	var f := FileAccess.open(OUT + "layers.json", FileAccess.WRITE)
	var manifest := {"source": SOURCE, "source_sha256": FileAccess.get_sha256(SOURCE), "clean_plate": PLATE, "source_size": [1672,941], "layers": records}
	f.store_string(JSON.stringify(manifest, "\t"))
	var legacy := FileAccess.open(OUT + "slices.json", FileAccess.WRITE)
	legacy.store_string(JSON.stringify(manifest, "\t"))
	print("SUMMON_LAYERS: original pixels extracted with clean-plate alpha")
	quit()

func _extract(label: String, rect: Rect2i) -> void:
	var result := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for y in rect.size.y:
		for x in rect.size.x:
			var p := Vector2i(x, y) + rect.position
			var src := reference.get_pixelv(p)
			var bg := plate.get_pixelv(p)
			var delta := maxf(absf(src.r-bg.r), maxf(absf(src.g-bg.g), absf(src.b-bg.b)))
			var alpha := smoothstep(0.05, 0.16, delta)
			if label == "key_visual":
				# 浅色皮肤/白色衣服不能按色差抠空。由透明提取参考的腐蚀内部保护实体。
				var interior := true
				for oy in [-4,0,4]:
					for ox in [-4,0,4]:
						var q := p-Vector2i(330,90)+Vector2i(ox,oy)
						if q.x<0 or q.y<0 or q.x>=guide.get_width() or q.y>=guide.get_height() or guide.get_pixelv(q).a<0.985:
							interior = false
							break
					if not interior: break
				if interior: alpha = 1
			if label.ends_with("button"):
				var q := Vector2(absf(x-171.5)-129.0, absf(y-44.0))
				if Vector2(maxf(q.x,0),q.y).length() < 33: alpha = 1
			if label == "key_visual" and p.y < 200 and (p.x < 694 or p.x > 966): alpha = 0
			if label == "key_visual" and p.y < 148: alpha = 0
			if label == "key_visual" and alpha > 0:
				# 生成抠图只作为宽松轮廓参考；绝不使用它重绘后的角色RGB。
				var near_art := false
				var g := p - Vector2i(330, 90)
				for oy in range(-18, 19, 6):
					for ox in range(-18, 19, 6):
						var q := g + Vector2i(ox, oy)
						if q.x >= 0 and q.y >= 0 and q.x < guide.get_width() and q.y < guide.get_height() and guide.get_pixelv(q).a > 0.1:
							near_art = true
							break
					if near_art: break
				if not near_art: alpha = 0
			if alpha > 0.001:
				# 最小可解混透明度保证颜色不越界；重新叠在同坐标底板时还原原稿色彩。
				for channel in 3:
					var bound: float = (bg[channel]-src[channel])/maxf(bg[channel],0.001) if src[channel] < bg[channel] else (src[channel]-bg[channel])/maxf(1.0-bg[channel],0.001)
					alpha = maxf(alpha, bound)
				for channel in 3: src[channel] = clampf((src[channel]-bg[channel]*(1.0-alpha))/alpha, 0, 1)
			else:
				alpha = 0
				src = Color.TRANSPARENT
			src.a = alpha
			result.set_pixel(x, y, src)
	result.save_png(OUT + label + ".png")
	if label == "key_visual":
		var preview := Image.create(result.get_width(),result.get_height(),false,Image.FORMAT_RGBA8)
		for y in preview.get_height():
			for x in preview.get_width():
				preview.set_pixel(x,y,Color("#808080") if (x/20+y/20)%2==0 else Color("#b8b8b8"))
		preview.blend_rect(result,Rect2i(Vector2i.ZERO,result.get_size()),Vector2i.ZERO)
		preview.save_png("res://output/summon_ui/revision_02/cutout_checker.png")
	if label.ends_with("button"):
		for y in result.get_height():
			for x in result.get_width():
				var c := result.get_pixel(x,y)
				var value := c.r*0.299+c.g*0.587+c.b*0.114
				result.set_pixel(x,y,Color(value*0.88,value*0.88,value*0.87,c.a))
		result.save_png(OUT + label + "_disabled.png")
	records[label] = {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "kind": "批准稿原像素与生成底板解混，独立透明层"}
