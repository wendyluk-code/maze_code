extends SceneTree
## 从当前地形重建专属连通缓存；--verify 只核对，不写文件。
const Water=preload("res://scripts/maze/ahong_water.gd")

func _initialize() -> void:
	var started:=Time.get_ticks_usec()
	Water.rebuild()
	var runs: Array=[]
	for y in range(ceili(Water.Roads.SIZE.y/Water.CELL)+1):
		var x:=0
		while x<=ceili(Water.Roads.SIZE.x/Water.CELL):
			var id:=int(Water.labels.get(Vector2i(x,y),0))
			if id==0:
				x+=1
				continue
			var first:=x
			while int(Water.labels.get(Vector2i(x,y),0))==id: x+=1
			runs.append([first,y,x-first,id])
	var data: Dictionary={"version":Water.CACHE_VERSION,"cell":Water.CELL,"terrain_hash":Water.terrain_hash(),"runs":runs}
	if "--verify" in OS.get_cmdline_user_args():
		var existing: Variant=JSON.parse_string(FileAccess.get_file_as_string(Water.CACHE_PATH))
		if existing!=JSON.parse_string(JSON.stringify(data)):
			push_error("C03 水域缓存与当前地形不一致")
			quit(1)
			return
		print("C03_WATER_CACHE_VERIFIED cells=",Water.labels.size())
		var expected:=Water.labels.duplicate()
		Water.ready=false
		Water.labels.clear()
		Water.cells.clear()
		var load_start:=Time.get_ticks_usec()
		Water.prepare()
		print("CACHE_LOAD_MS=",(Time.get_ticks_usec()-load_start)/1000.0)
		if expected!=Water.labels:
			push_error("C03 连通缓存解码不一致")
			quit(1)
			return
	else:
		var file:=FileAccess.open(Water.CACHE_PATH,FileAccess.WRITE)
		if not file:
			push_error("C03 水域缓存写入失败")
			quit(1)
			return
		file.store_string(JSON.stringify(data))
		print("C03_WATER_CACHE_BUILT cells=",Water.labels.size())
	print("BUILD_MS=",(Time.get_ticks_usec()-started)/1000.0)
	quit()
