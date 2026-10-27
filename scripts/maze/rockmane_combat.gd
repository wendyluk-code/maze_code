extends RefCounted
const Config=preload("res://data/maze/salt_boss.gd")
const Skills=preload("res://scripts/maze/team_attack.gd")
static func initialize(a: Dictionary) -> void:
	a.rock_phase="active"
	a.rock_left=0.0
	a.rock_reuse=6.0
	a.rock_distance=0.0
	a.rock_hit=false
	a.rock_aim=[0.0,1.0]
static func vec(p: Array) -> Vector2: return Vector2(p[0],p[1])
static func pack(p: Vector2) -> Array: return [p.x,p.y]
static func hurt(run: Dictionary,point: Vector2,source: Vector2) -> void:
	var c: Dictionary=run.combat
	c.hp=maxf(0,c.hp-Skills.incoming_damage(run,8))
	c.last_attacker="rockmane"
	var direction:=source.direction_to(point)
	if direction.is_zero_approx(): direction=Vector2.DOWN
	c.hit_velocity=pack(direction*150.0)
	c.hit_remaining=0.12
	c.flash_remaining=0.1
static func advance(run: Dictionary,point: Vector2,dt: float) -> void:
	var c: Dictionary=run.combat
	if c.get("region","")!="salt_pool" or not c.get("rock_encounter",false): return
	c.rock_shake_left=maxf(0,float(c.get("rock_shake_left",0))-dt)
	var a: Dictionary=c.actors[Config.ID]
	if run.monsters[Config.ID].status!="alive" or a.hp<=0 or c.hp<=0: return
	var pos:=vec(a.position)
	a.velocity=[0.0,0.0]
	if float(a.get("hit_remaining",0))>0:
		var used:=minf(dt,float(a.hit_remaining))
		var next:=Config.move(pos,vec(a.hit_velocity)*used)
		a.position=pack(next)
		a.velocity=pack((next-pos)/dt)
		a.hit_remaining=maxf(0,a.hit_remaining-dt)
		return
	if a.mode in ["idle","return"]:
		if pos.distance_to(point)>300: return
		a.mode="chase"
	# 保留旧阶段名兼容探索存档；rush 现在表示咆哮释放，不再冲撞。
	if a.rock_phase=="charge":
		a.rock_left=maxf(0,a.rock_left-dt)
		if a.rock_left<=0.00001:
			a.rock_phase="rush"
			a.rock_left=0.45
			a.rock_hit=true
			c.rock_shake_left=0.45
			if roar_hits(pos,vec(a.rock_aim),point): hurt(run,point,pos)
	elif a.rock_phase=="rush":
		a.rock_left=maxf(0,a.rock_left-dt)
		if a.rock_left<=0.00001:
			a.rock_phase="rest"
			a.rock_left=1.5
	elif a.rock_phase=="rest":
		a.rock_left=maxf(0,a.rock_left-dt)
		if a.rock_left<=0.00001: a.rock_phase="active"
	else:
		a.mode="chase"
		a.windup=0.0
		if pos.distance_to(point)<=260.0 and roar_clear(pos,point):
			a.rock_phase="charge"
			a.rock_left=1.1
			var aim:=pos.direction_to(point)
			a.rock_aim=pack(Vector2.DOWN if aim.is_zero_approx() else aim)
		else:
			var next:=preload("res://scripts/maze/rockmane_path.gd").step(pos,point,70*dt)
			a.position=pack(next)
			a.velocity=pack((next-pos)/dt)

static func roar_clear(origin: Vector2,target: Vector2) -> bool:
	# 声波可越过盐水池，实体岩石及盐晶仍会遮挡。
	var steps:=maxi(1,ceili(origin.distance_to(target)/4.0))
	for i in range(steps+1):
		var p:=origin.lerp(target,float(i)/steps)
		for o in Config.Roads.OBSTACLES:
			if ((p-Vector2(o.x,o.y))/Vector2(o.z,o.w)).length()<=1: return false
		for shapes in preload("res://scripts/maze/salt_crystals.gd").SHAPES:
			for polygon in shapes:
				if Geometry2D.is_point_in_polygon(p,polygon): return false
	return true

static func roar_hits(origin: Vector2,aim: Vector2,point: Vector2) -> bool:
	var offset:=point-origin
	return offset.length()<=260.0 and (offset.length()<=24 or offset.normalized().dot(aim)>=cos(deg_to_rad(35))) and roar_clear(origin,point)
static func valid(a: Dictionary) -> bool:
	if not Config.allowed(vec(a.position)) or a.get("rock_phase") not in ["active","charge","rush","rest"]: return false
	if not Skills.number(a.get("rock_left"),1.5) or not Skills.number(a.get("rock_reuse"),6.0) or not Skills.number(a.get("rock_distance"),180.001): return false
	return a.get("rock_hit") is bool and Skills.point(a.get("rock_aim")) and absf(vec(a.rock_aim).length()-1)<0.001
