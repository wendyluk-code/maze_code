extends RefCounted
const Config=preload("res://data/maze/salt_boss.gd")
static var grid: AStarGrid2D
static func prepare() -> void:
	if grid!=null: return
	grid=AStarGrid2D.new()
	grid.region=Rect2i(0,0,203,123)
	grid.cell_size=Vector2(8,8)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in 123:
		for x in 203: grid.set_point_solid(Vector2i(x,y),not Config.allowed(Vector2(x*8,y*8)))
static func nearest(p: Vector2) -> Vector2i:
	var center:=Vector2i((p/8.0).round())
	var best:=Vector2i(-1,-1)
	var distance:=INF
	for y in range(center.y-10,center.y+11):
		for x in range(center.x-10,center.x+11):
			var cell:=Vector2i(x,y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell): continue
			var d:=p.distance_squared_to(Vector2(cell)*8)
			if d<distance:
				distance=d
				best=cell
	return best
static func step(origin: Vector2,target: Vector2,distance: float) -> Vector2:
	if Config.line(origin,target,Config.BODY): return Config.move(origin,origin.direction_to(target)*minf(distance,origin.distance_to(target)))
	prepare()
	var start:=nearest(origin)
	var end:=nearest(target)
	if start.x<0 or end.x<0: return origin
	var path:=grid.get_point_path(start,end)
	var waypoint:=origin
	for p in path:
		if not Config.line(origin,p,Config.BODY): break
		waypoint=p
	return Config.move(origin,origin.direction_to(waypoint)*minf(distance,origin.distance_to(waypoint)))
