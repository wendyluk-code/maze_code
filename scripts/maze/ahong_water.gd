extends RefCounted
## 只读现有浅水地形；四像素格连通域，格间逐像素检查，不跨干路或栅栏。
const Roads=preload("res://data/maze/fenshui_roads.gd")
const CELL=4
const CACHE_VERSION=1
const CACHE_PATH="res://scripts/maze/ahong_water_cache.json"
static var labels: Dictionary={}
static var cells: Dictionary={}
static var ready:=false

static func water(point: Vector2, region: String) -> bool:
	return region=="fenshui" and Roads.is_walkable(point,0.0) and Roads.terrain_multiplier(point)<1.0

static func line(a: Vector2,b: Vector2) -> bool:
	var count:=maxi(1,ceili(a.distance_to(b)))
	for i in range(count+1):
		if not water(a.lerp(b,float(i)/count),"fenshui"): return false
	return true

static func prepare() -> void:
	if ready: return
	if load_cache():
		ready=true
		return
	rebuild()

static func terrain_hash() -> String:
	return FileAccess.get_file_as_string("res://data/maze/fenshui_roads.gd").replace("\r\n","\n").sha256_text()+FileAccess.get_file_as_string("res://data/maze/fenshui_gates.gd").replace("\r\n","\n").sha256_text()

static func load_cache() -> bool:
	if not FileAccess.file_exists(CACHE_PATH): return false
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if not data is Dictionary or data.get("version")!=CACHE_VERSION or data.get("cell")!=CELL or data.get("terrain_hash")!=terrain_hash() or not data.get("runs") is Array: return false
	var decoded: Dictionary={}
	var groups: Dictionary={}
	for run in data.runs:
		if not run is Array or run.size()!=4: return false
		for value in run:
			if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or value<0 or floor(float(value))!=float(value): return false
		if run[0]+run[2]>ceili(Roads.SIZE.x/CELL)+1 or run[1]>ceili(Roads.SIZE.y/CELL) or run[2]<1 or run[3]<1: return false
		var id:=int(run[3])
		if not groups.has(id): groups[id]=[]
		for x in range(int(run[0]),int(run[0]+run[2])):
			var cell:=Vector2i(x,int(run[1]))
			decoded[cell]=id
			groups[id].append(cell)
	labels=decoded
	cells=groups
	return not labels.is_empty()

static func rebuild() -> void:
	labels.clear()
	cells.clear()
	ready=true
	var wet: Dictionary={}
	for y in range(0,int(Roads.SIZE.y)+1,CELL):
		for x in range(0,int(Roads.SIZE.x)+1,CELL):
			var cell:=Vector2i(x/CELL,y/CELL)
			if water(Vector2(x,y),"fenshui"): wet[cell]=true
	var component:=0
	for start in wet:
		if labels.has(start): continue
		component+=1
		var queue: Array[Vector2i]=[start]
		labels[start]=component
		var cursor:=0
		while cursor<queue.size():
			var here:=queue[cursor]
			cursor+=1
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=here+offset
				if labels.has(next) or not wet.has(next): continue
				if not line(Vector2(here)*CELL,Vector2(next)*CELL): continue
				labels[next]=component
				queue.append(next)
		cells[component]=queue

static func component(point: Vector2,region: String) -> int:
	if not water(point,region): return 0
	prepare()
	var center:=Vector2i((point/CELL).round())
	var best:=0
	var distance:=INF
	for y in range(center.y-2,center.y+3):
		for x in range(center.x-2,center.x+3):
			var cell:=Vector2i(x,y)
			if not labels.has(cell): continue
			var p:=Vector2(cell)*CELL
			if point.distance_squared_to(p)>=distance or not line(point,p): continue
			distance=point.distance_squared_to(p)
			best=int(labels[cell])
	return best
