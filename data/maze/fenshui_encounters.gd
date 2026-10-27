extends RefCounted
## 普通水怪的固定身份和浅水活动区；不改变玩家可走地形。
const Roads = preload("res://data/maze/fenshui_roads.gd")
const TYPES := {
	"silverfish":{"name":"银鳞鱼","power":20,"element":"water","chance":75,"sheet":"res://assets/monsters/silverfish/idle.png","animation_dir":"res://assets/monsters/silverfish/","drops":["silverfish_meat"],"width":48.0},
	"thunder_eel":{"name":"雷鳗","power":30,"element":"thunder","chance":60,"sheet":"res://assets/monsters/thunder_eel/idle.png","animation_dir":"res://assets/monsters/thunder_eel/","drops":["thunder_eel_belly"],"width":58.0}
}
const POINTS := [Vector2(1065,405),Vector2(1050,230),Vector2(620,360),Vector2(390,395),Vector2(470,550),Vector2(1040,640)]
const BODY_RADIUS := 15.0

static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in POINTS.size():
		var kind := "silverfish" if i<4 else "thunder_eel"
		var row: Dictionary = TYPES[kind].duplicate(true)
		row.merge({"id":"fenshui_%s_%d" % [kind,i+1 if i<4 else i-3],"kind":kind,"region":"fenshui","position":POINTS[i],"direction":i%4})
		result.append(row)
	return result

static func protected(point: Vector2, margin: float = 0.0) -> bool:
	if preload("res://data/maze/yf_encounter_site.gd").protected(point,margin): return true
	if preload("res://data/maze/region_resources.gd").protected("fenshui",point,margin): return true
	return false

static func water(point: Vector2, radius: float = BODY_RADIUS) -> bool:
	if protected(point,radius): return false
	for i in 9:
		var p := point if i==8 else point+Vector2.RIGHT.rotated(i*TAU/8.0)*radius
		if not Roads.is_walkable(p,0.0) or Roads.terrain_multiplier(p)!=Roads.WATER_SPEED: return false
	return true

static func allowed(point: Vector2, home: Vector2) -> bool:
	return water(point)

static func move(origin: Vector2, displacement: Vector2, home: Vector2) -> Vector2:
	var current := origin
	var count := maxi(1,ceili(displacement.length()/2.0))
	for i in count:
		var next := current+displacement/float(count)
		if not allowed(next,home): break
		current=next
	return current
