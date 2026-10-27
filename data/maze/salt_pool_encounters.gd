extends RefCounted
## 盐池普通怪只沿现有岸线活动；元素不赋予水池通行能力。
const Roads = preload("res://data/maze/salt_pool_roads.gd")
const TYPES := {
	"mimic_crab":{"name":"拟态宝箱蟹","power":28,"element":"earth","chance":65,"sheet":"res://assets/monsters/mimic_crab/idle.png","animation_dir":"res://assets/monsters/mimic_crab/","drops":["mimic_crab_meat"],"width":64.0,"anchor":0.82},
	"blind_scorpion":{"name":"盲水蝎","power":22,"element":"water","chance":70,"sheet":"res://assets/monsters/blind_scorpion/idle.png","animation_dir":"res://assets/monsters/blind_scorpion/","drops":["blind_scorpion_tail"],"width":62.0,"anchor":0.82}
}
const POINTS := [Vector2(460,470),Vector2(1000,470),Vector2(1370,370),Vector2(750,690),Vector2(900,420),Vector2(1000,615)]
const HOME_RADIUS := 75.0
const BODY_RADIUS := 14.0
const RESERVED := [Vector2(505,365),Vector2(1170,315),Vector2(400,310),Vector2(1140,650),Vector2(1360,300)]

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in POINTS.size():
		var kind := "mimic_crab" if i<3 else "blind_scorpion"
		var row: Dictionary = TYPES[kind].duplicate(true)
		row.merge({"id":"salt_pool_%s_%d" % [kind,i%3+1],"kind":kind,"region":"salt_pool","position":POINTS[i],"direction":i%4})
		result.append(row)
	return result

static func protected(point: Vector2, margin: float = 0.0) -> bool:
	if preload("res://data/maze/region_resources.gd").protected("salt_pool",point,margin): return true
	if point.distance_to(Roads.SPAWN)<110.0+margin or point.distance_to(Vector2(1010,225))<95.0+margin: return true
	for p in RESERVED:
		if point.distance_to(p)<42.0+margin: return true
	return false

static func ground(point: Vector2, radius: float = BODY_RADIUS) -> bool:
	return Roads.is_walkable(point,radius) and not protected(point,radius)

static func allowed(point: Vector2, home: Vector2) -> bool:
	return point.distance_to(home)<=HOME_RADIUS and ground(point)

static func move(origin: Vector2, displacement: Vector2, home: Vector2) -> Vector2:
	var current := origin
	var count := maxi(1,ceili(displacement.length()/2.0))
	for i in count:
		var next := current+displacement/float(count)*Roads.terrain_multiplier(current)
		if not allowed(next,home): break
		current=next
	return current

static func line(a: Vector2,b: Vector2) -> bool:
	var count := maxi(1,ceili(a.distance_to(b)/2.0))
	for i in range(count+1):
		if not ground(a.lerp(b,float(i)/count),0.0): return false
	return true
