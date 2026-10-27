extends RefCounted
## 分水庭水怪的身体间距与巨蛙落点预留；不修改玩家碰撞。
static func radius(id: String) -> float:
	return 48.0 if id.contains("wind_frog") else (29.0 if id.contains("thunder_eel") else 24.0)

static func clear(run: Dictionary, id: String, point: Vector2) -> bool:
	for other in run.combat.actors:
		if other==id or not str(other).begins_with("fenshui_"): continue
		if run.monsters[other].status not in ["alive","pending"]: continue
		var a: Dictionary=run.combat.actors[other]
		var separation:=radius(id)+radius(other)+3.0
		if point.distance_to(Vector2(a.position[0],a.position[1]))<separation: return false
		if a.get("frog_phase","") in ["warning","airborne"]:
			var start:=Vector2(a.frog_origin[0],a.frog_origin[1])
			var target:=Vector2(a.frog_target[0],a.frog_target[1])
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,start,target))<separation: return false
	return true

static func line_clear(run: Dictionary, id: String, start: Vector2, finish: Vector2) -> bool:
	var steps:=maxi(1,ceili(start.distance_to(finish)/6.0))
	for i in range(steps+1):
		if not clear(run,id,start.lerp(finish,float(i)/steps)): return false
	return true

static func swim(run: Dictionary, row: Dictionary, origin: Vector2, direction: Vector2, distance: float) -> Vector2:
	var water=preload("res://data/maze/fenshui_encounters.gd")
	for angle in [0.0,0.45,-0.45,0.9,-0.9,1.5,-1.5,2.2,-2.2,PI]:
		var step: Vector2=direction.rotated(angle)*distance
		var next: Vector2=water.move(origin,step,row.position)
		if next.distance_to(origin)>0.01 and clear(run,row.id,next): return next
	return origin

static func patrol(run: Dictionary, row: Dictionary, dt: float) -> void:
	var a: Dictionary=run.combat.actors[row.id]
	var pos:=Vector2(a.position[0],a.position[1])
	a.swim_left=maxf(0.0,float(a.get("swim_left",0.0))-dt)
	var direction:=Vector2(a.get("swim_heading",[0.0,0.0])[0],a.get("swim_heading",[0.0,0.0])[1])
	if direction.is_zero_approx(): direction=Vector2.RIGHT.rotated(float(abs(str(row.id).hash())%628)/100.0)
	if a.swim_left<=0.0:
		var seed_value:int=absi(str(row.id).hash()+int(run.combat.elapsed*11.0))
		direction=direction.rotated(float(seed_value%181-90)*PI/180.0)
		a.swim_left=2.0+float(seed_value%150)/100.0
	var next:=swim(run,row,pos,direction,(24.0 if row.kind=="silverfish" else 20.0)*dt)
	if next.distance_to(pos)>0.01: direction=pos.direction_to(next)
	else: a.swim_left=0.0
	a.swim_heading=[direction.x,direction.y]
	a.position=[next.x,next.y]
