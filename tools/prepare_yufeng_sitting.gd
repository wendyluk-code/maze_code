extends SceneTree
## 仅按图集格子切分、统一画布和脚底锚点；不绘制或合成角色动作。
func _init() -> void:
	var sheet := Image.load_from_file("res://output/yufeng_sitting/animation_sheet.png")
	var cell := sheet.get_size() / 2
	var info: Array = []
	for i in 4:
		var frame := sheet.get_region(Rect2i(Vector2i(i%2,i/2)*cell,cell))
		var rect := frame.get_used_rect()
		var crop := frame.get_region(rect)
		var factor := minf(480.0/crop.get_width(),464.0/crop.get_height())
		crop.resize(roundi(crop.get_width()*factor),roundi(crop.get_height()*factor),Image.INTERPOLATE_LANCZOS)
		var result := Image.create(512,512,false,Image.FORMAT_RGBA8)
		result.fill(Color.TRANSPARENT)
		result.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((512-crop.get_width())/2,488-crop.get_height()))
		var path := "res://assets/characters/yufeng_salia_sitting/frame_%02d.png" % i
		assert(result.save_png(path) == OK)
		info.append({"frame":i,"source_rect":str(rect),"output":path,"alpha":result.detect_alpha()})
	var file := FileAccess.open("res://output/yufeng_sitting/frame_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(info,"\t"))
	print("SITTING_FRAMES ",JSON.stringify(info))
	quit()
