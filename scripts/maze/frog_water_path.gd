extends RefCounted
const Config=preload("res://data/maze/fenshui_boss.gd")
const Spacing=preload("res://scripts/maze/water_spacing.gd")
static var grid: AStarGrid2D

static func prepare() -> void:
	if grid!=null: return
	grid=AStarGrid2D.new()
	grid.region=Rect2i(0,0,108,58)
	grid.cell_size=Vector2(16,16)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in 58:
		for x in 108: grid.set_point_solid(Vector2i(x,y),not Config.air_allowed(Vector2(x*16,y*16)))

static func nearest(point: Vector2) -> Vector2i:
	var center:=Vector2i((point/16.0).round())
	var best:=Vector2i(-1,-1)
	var distance:=INF
	for y in range(center.y-5,center.y+6):
		for x in range(center.x-5,center.x+6):
			var cell:=Vector2i(x,y)
			if not grid.region.has_point(cell) or grid.is_point_solid(cell) or not Config.allowed(Vector2(cell)*16.0): continue
			var value:=point.distance_squared_to(Vector2(cell)*16.0)
			if value<distance:
				distance=value
				best=cell
	return best

static func landing(run: Dictionary, origin: Vector2, target: Vector2) -> Vector2:
	prepare()
	# 以活体间距更新障碍，允许绕开鱼鳗，而非在同一条被挡直线上反复原地跳。
	var blocked: Array[Vector2i]=[]
	for id in run.combat.actors:
		if id==Config.ID or not str(id).begins_with("fenshui_") or run.monsters[id].status not in ["alive","pending"]: continue
		var actor: Dictionary=run.combat.actors[id]
		var p:=Vector2(actor.position[0],actor.position[1])
		var center:=Vector2i((p/16.0).round())
		var radius:=Spacing.radius(id)+Spacing.radius(Config.ID)+3.0
		for y in range(center.y-6,center.y+7):
			for x in range(center.x-6,center.x+7):
				var cell:=Vector2i(x,y)
				if not grid.region.has_point(cell) or grid.is_point_solid(cell): continue
				if (Vector2(cell)*16).distance_to(p)<radius:
					grid.set_point_solid(cell,true)
					blocked.append(cell)
	var start:=nearest(origin)
	var finish:=nearest(target)
	var path:=PackedVector2Array()
	if start.x>=0 and finish.x>=0: path=grid.get_point_path(start,finish)
	for cell in blocked: grid.set_point_solid(cell,false)
	var best:=origin
	for point in path:
		if origin.distance_to(point)>Config.JUMP_RANGE: break
		if Config.jump_line(origin,point) and Spacing.line_clear(run,Config.ID,origin,point): best=point
	if Config.jump_line(origin,target) and Spacing.line_clear(run,Config.ID,origin,target): best=target
	return best
