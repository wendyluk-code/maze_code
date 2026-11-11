extends RefCounted
## 巨蛙可越过岸路，起落点必须在水中；不改变玩家碰撞。
const Roads = preload("res://data/maze/fenshui_roads.gd")
const ID := "fenshui_wind_frog_1"
const HOME := Vector2(900,450)
const AREA := Rect2(790,365,220,170)
const BODY := 24.0
const JUMP_RANGE := 320.0
# 正式1.4倍参考蛙的可见体宽，沿视觉交付132体宽/330主浪宽换算。
# 水花仅沿交付体型标定；正式落地判定共用电鳗水域，不从透明图反推。
const SPLASH_BODY_WIDTH := 148.0/192.0*100.0*1.4
const SLAM_RADIUS := preload("res://scripts/maze/fenshui_electric_area.gd").RADIUS
const TYPE := {"name":"风袋巨蛙","power":96,"element":"wind","chance":50,"sheet":"res://assets/monsters/wind_frog/idle.png","animation_dir":"res://assets/monsters/wind_frog/","drops":["wind_frog_stomach"],"width":100.0}

static func row() -> Dictionary:
	var result := TYPE.duplicate(true)
	result.merge({"id":ID,"kind":"wind_frog","region":"fenshui","position":HOME,"direction":0})
	return result

static func water(p: Vector2, radius: float = 0.0) -> bool:
	if preload("res://data/maze/region_resources.gd").protected("fenshui",p,radius): return false
	# 半径为零时九个采样点完全相同，只需保留一次相同判定。
	for i in (1 if radius==0.0 else 9):
		var q := p if i==8 else p+Vector2.RIGHT.rotated(i*TAU/8.0)*radius
		if not Roads.is_walkable(q,0.0) or Roads.terrain_multiplier(q)!=Roads.WATER_SPEED: return false
	return true

static func line(a: Vector2,b: Vector2,radius: float = 0.0) -> bool:
	var steps := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(steps+1):
		if not water(a.lerp(b,float(i)/steps),radius): return false
	return true

static func allowed(p: Vector2) -> bool:
	return water(p,BODY)

static func air_allowed(p: Vector2) -> bool:
	# 允许经过岸路，仍避开岛体、地图边界和栅栏。
	for i in 9:
		var q := p if i==8 else p+Vector2.RIGHT.rotated(i*TAU/8.0)*8.0
		if not Roads.air_walkable(q,0.0): return false
	return true

static func jump_line(a: Vector2,b: Vector2) -> bool:
	if a.distance_to(b)>JUMP_RANGE+0.001 or not allowed(a) or not allowed(b): return false
	var steps := maxi(1,ceili(a.distance_to(b)/2.0))
	# 仍检查原来的同一组采样点，只先检查中段，让越过岛体/栅栏的长射线尽早失败。
	var probes := [floori(steps*0.5),floori(steps*0.25),floori(steps*0.75)]
	for i in probes:
		if not air_allowed(a.lerp(b,float(i)/steps)): return false
	for i in range(steps+1):
		if i in probes: continue
		if not air_allowed(a.lerp(b,float(i)/steps)): return false
	return true

static func move(a: Vector2,delta: Vector2) -> Vector2:
	var steps := maxi(1,ceili(delta.length()/2.0))
	var p := a
	for i in steps:
		var q := p+delta/steps
		if not allowed(q): break
		p=q
	return p
