extends SceneTree
## 从已确认改稿生成生产分层：只补菜畦局部，原图其他像素不变；透明植株缩至160像素。
func _initialize() -> void:
	var original:=Image.load_from_file("res://assets/maps/waterkeeper_cottage.png")
	var edited:=Image.load_from_file("res://output/cottage-garden-20261028/soil-raw.png")
	if original==null or edited==null or original.get_size()!=edited.get_size():
		push_error("菜园补土素材缺失或尺寸不匹配")
		quit(1)
		return
	original.convert(Image.FORMAT_RGBA8)
	edited.convert(Image.FORMAT_RGBA8)
	var patches: Array[Rect2i]=[Rect2i(280,276,211,110),Rect2i(374,341,213,126)]
	for rect in patches:
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				var edge:=minf(minf(x-rect.position.x,rect.end.x-1-x),minf(y-rect.position.y,rect.end.y-1-y))
				var blend:=smoothstep(0.0,4.0,edge)
				original.set_pixel(x,y,original.get_pixel(x,y).lerp(edited.get_pixel(x,y),blend))
	if original.save_png("res://assets/maps/waterkeeper_cottage_soil.png")!=OK:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://assets/props/cottage_garden")
	for kind in ["tomato","turnip"]:
		var source:=Image.load_from_file("res://output/cottage-garden-20261028/"+kind+"-raw.png")
		if source==null or source.detect_alpha()==Image.ALPHA_NONE:
			push_error("植株素材缺少透明通道："+kind)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		var crop:=source.get_region(source.get_used_rect())
		var factor:=128.0/maxf(crop.get_width(),crop.get_height())
		crop.resize(maxi(1,roundi(crop.get_width()*factor)),maxi(1,roundi(crop.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
		var result:=Image.create(160,160,false,Image.FORMAT_RGBA8)
		result.fill(Color.TRANSPARENT)
		result.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((160-crop.get_width())/2,136-crop.get_height()))
		if result.save_png("res://assets/props/cottage_garden/"+kind+".png")!=OK:
			quit(1)
			return
	print("菜园分层素材已准备；两块补土区域外保留原图像素。")
	quit()
