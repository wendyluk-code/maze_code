extends RefCounted
const Config=preload("res://data/maze/fenshui_boss.gd")
const Spacing=preload("res://scripts/maze/water_spacing.gd")
static var grid: AStarGrid2D
static var allowed_cells: Dictionary = {}

static func prepare() -> void:
	if grid!=null: return
	allowed_cells.clear()
	grid=AStarGrid2D.new()
	grid.region=Rect2i(0,0,108,58)
	grid.cell_size=Vector2(16,16)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in 58:
		for x in 108: grid.set_point_solid(Vector2i(x,y),not Config.air_allowed(Vector2(x*16,y*16)))

static func allowed_cell(cell: Vector2i) -> bool:
	# 只复用不会随演员移动改变的静态水面；动态占位仍逐次检查。
	if not allowed_cells.has(cell): allowed_cells[cell]=Config.allowed(Vector2(cell)*16.0)
	return allowed_cells[cell]

static func nearest(point: Vector2) -> Vector2i:
	var center:=Vector2i((point/16.0).round())
	var best:=Vector2i(-1,-1)
	var distance:=INF
	for y in range(center.y-5,center.y+6):
		for x in range(center.x-5,center.x+6):
			var cell:=Vector2i(x,y)
			var value:=point.distance_squared_to(Vector2(cell)*16.0)
			if value>=distance or not grid.region.has_point(cell) or grid.is_point_solid(cell) or not allowed_cell(cell): continue
			distance=value
			best=cell
	return best

static func candidate_clear(run: Dictionary, origin: Vector2, point: Vector2) -> bool:
	if not allowed_cell(Vector2i(point/16.0)): return false
	# 先用原射线中段的同一组采样排除静态障碍，再检查动态占位，最后才扫描整条射线。
	var steps:=maxi(1,ceili(origin.distance_to(point)/2.0))
	for i in [floori(steps*0.5),floori(steps*0.25),floori(steps*0.75)]:
		if not Config.air_allowed(origin.lerp(point,float(i)/steps)): return false
	return Spacing.line_clear(run,Config.ID,origin,point) and Config.jump_line(origin,point)

static func landing(run: Dictionary, origin: Vector2, target: Vector2) -> Vector2:
	# 原算法最终也优先覆盖为直达目标；先判定可避免不必要的网格与整条路径检查。
	if Config.jump_line(origin,target) and Spacing.line_clear(run,Config.ID,origin,target): return target
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
	var count:=0
	while count<path.size() and origin.distance_to(path[count])<=Config.JUMP_RANGE: count+=1
	# 保留原有效前缀中最后一个合法点，只需从后往前找到第一个，不逐段重复扫描射线。
	for i in range(count-1,-1,-1):
		var point:=path[i]
		if origin.distance_squared_to(point)>=0.01 and candidate_clear(run,origin,point): return point
	# 空中网格的最短线未必含有能落水的中间点；只在原路线无进展时补查邻近落点。
	return alternative_landing(run,origin,target)

static func alternative_landing(run: Dictionary, origin: Vector2, target: Vector2) -> Vector2:
	var candidates: Array[Vector2]=[]
	var distance:=origin.distance_squared_to(target)
	var center:=Vector2i((origin/16.0).round())
	var reach:=ceili(Config.JUMP_RANGE/16.0)
	for y in range(maxi(0,center.y-reach),mini(grid.region.end.y,center.y+reach+1)):
		for x in range(maxi(0,center.x-reach),mini(grid.region.end.x,center.x+reach+1)):
			var cell:=Vector2i(x,y)
			if grid.is_point_solid(cell): continue
			var point:=Vector2(cell)*16.0
			if origin.distance_squared_to(point)<0.01 or origin.distance_to(point)>Config.JUMP_RANGE: continue
			if point.distance_squared_to(target)<distance-1.0: candidates.append(point)
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool:
		var da:=a.distance_squared_to(target)
		var db:=b.distance_squared_to(target)
		if not is_equal_approx(da,db): return da<db
		return a.x<b.x if a.x!=b.x else a.y<b.y)
	for point in candidates:
		if candidate_clear(run,origin,point): return point
	return origin
