extends RefCounted
## 首区配额与道路出生点；随机过程只使用调用者的随机源。
const Roads = preload("res://data/maze/entry_roads.gd")
const SPAWN_CLEARANCE := 260.0
const MONSTER_CLEARANCE := 80.0
const PROP_CLEARANCE := 64.0

static func clear_of_props(point: Vector2) -> bool:
	for prop in preload("res://data/maze/entry_chests.gd").all() + preload("res://data/maze/entry_dig_sites.gd").all():
		if point.distance_to(prop.position) < PROP_CLEARANCE: return false
	return point.distance_to(preload("res://data/maze/elder_firewood.gd").POSITION) >= PROP_CLEARANCE

static func nearest_clear_point(point: Vector2) -> Vector2:
	if clear_of_props(point) and Roads.is_walkable(point): return point
	var nearest := point
	var distance := INF
	for candidate in spawn_points():
		var next_distance: float = point.distance_squared_to(candidate)
		if next_distance < distance:
			nearest = candidate
			distance = next_distance
	return nearest
const FIRST_SLIME_POSITION := Vector2(860,295)
const LAST_MONSTER_POSITION := Vector2(270,720)
# 只保护新入场：最大触发半径200（也覆盖180攻击选中范围）+ 首路半宽24。
# 包含入口后退方向及拐角圆帽，不能仅按距入口或怪物点位先后排序。
const FIRST_ENCOUNTER_CLEARANCE := 224.0
const TYPES := {
	"slime": {"name":"史莱姆", "power":8, "element":"water", "chance":80, "sheet":"res://assets/monsters/slime/slime_crawl_4directions.png", "drops":["slime_shell","slime_gel"]},
	"snail": {"name":"砖壳蜗牛", "power":24, "element":"earth", "chance":70, "sheet":"res://assets/monsters/capture/brick_snail.png", "drops":["brick_snail_meat"]},
	"beetle": {"name":"剑甲虫", "power":48, "element":"wind", "chance":60, "sheet":"res://assets/monsters/capture/sword_beetle.png", "drops":["sword_beetle_leg"]},
	"lizard": {"name":"石化蜥蜴", "power":160, "element":"earth", "chance":40, "sheet":"res://assets/monsters/capture/petrifying_lizard.png", "drops":["petrifying_lizard_tail"]}
}
const ELEMENTS := {"fire":"火", "grass":"草", "earth":"土", "thunder":"雷", "water":"水", "wind":"风"}
const COUNTERS := {"fire":"grass", "grass":"earth", "earth":"thunder", "thunder":"water", "water":"wind", "wind":"fire"}
const CHARACTER_ELEMENTS := {"yaya":"grass", "tieshan":"earth"}
const BALANCE_VERSION := 2

static func valid_layout(layout: Variant) -> bool:
	if not layout is Array: return false
	if layout.is_empty(): return true # 当前战斗旧档允许缺省，恢复时补存。
	if layout.size()!=10: return false
	for item in layout:
		if not item is Dictionary or not TYPES.has(item.get("kind")): return false
		var point: Variant = item.get("position")
		if not point is Array or point.size()!=2: return false
		for value in point:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
	return true

static func all(version: int = BALANCE_VERSION, layout: Array = []) -> Array[Dictionary]:
	if version == BALANCE_VERSION and not layout.is_empty():
		var generated: Array[Dictionary] = []
		var counters := {}
		for i in layout.size():
			var item: Dictionary = layout[i]
			counters[item.kind] = int(counters.get(item.kind, 0)) + 1
			var row: Dictionary = TYPES[item.kind].duplicate(true)
			row.merge({"id":"%s_%d" % [item.kind, counters[item.kind]], "kind":item.kind, "position":Vector2(item.position[0], item.position[1]), "direction":i%4, "power":TYPES[item.kind].power}, true)
			generated.append(row)
		return generated
	if version == 1: return _legacy_all()
	var result: Array[Dictionary] = []
	var fixed_layout := [
		["slime_1", "slime", Vector2(995,225), 6],
		["slime_2", "slime", Vector2(613,421), 12],
		["snail_1", "snail", Vector2(534,499), 20],
		["snail_2", "snail", Vector2(539,789), 80],
		["slime_3", "slime", Vector2(786,481), 30],
		["beetle_1", "beetle", Vector2(1086,755), 60],
		["beetle_2", "beetle", Vector2(983,1132), 180],
		["snail_3", "snail", Vector2(736,1119), 90],
		["beetle_3", "beetle", Vector2(862,771), 120],
		["lizard_1", "lizard", Vector2(270,720), 450],
	]
	for i in fixed_layout.size():
		var entry: Array = fixed_layout[i]
		var row: Dictionary = TYPES[entry[1]].duplicate(true)
		row.merge({"id":entry[0], "kind":entry[1], "position":entry[2], "power":entry[3], "direction":i%4}, true)
		result.append(row)
	return result

static func random_layout(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var combos := [[2,3,4,1],[2,4,3,1],[3,3,3,1]]
	var combo: Array = combos[rng.randi_range(0, combos.size()-1)]
	var kinds: Array = []
	for i in combo.size():
		for j in range(int(combo[i])): kinds.append(["slime","snail","beetle","lizard"][i])
	# 首怪占用本次配额中的一只，沿用slime_1身份，不新增槽位或奖励资格。
	kinds.erase("slime")
	var points := spawn_points()
	shuffle_points(points, rng)
	var layout: Array = [{"kind":"slime","position":[FIRST_SLIME_POSITION.x,FIRST_SLIME_POSITION.y]}]
	var occupied: Array = [FIRST_SLIME_POSITION,LAST_MONSTER_POSITION]
	for kind in kinds:
		if kind == "lizard":
			layout.append({"kind":kind,"position":[LAST_MONSTER_POSITION.x,LAST_MONSTER_POSITION.y]})
			continue
		for point in points:
			if point.distance_to(Roads.SPAWN) < SPAWN_CLEARANCE: continue
			if not outside_first_encounter(point): continue
			if occupied.any(func(other): return point.distance_to(other) < MONSTER_CLEARANCE): continue
			layout.append({"kind":kind,"position":[point.x,point.y]})
			occupied.append(point)
			break
	return layout

## 仅用于初始布局；冷却刷新继续使用完整spawn_points及原safe_spawn规则。
static func outside_first_encounter(point: Vector2) -> bool:
	var corridor: PackedVector2Array = Roads.roads()[0].points
	for i in range(corridor.size()-1):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,corridor[i],corridor[i+1])) <= FIRST_ENCOUNTER_CLEARANCE:
			return false
		if corridor[i+1] == FIRST_SLIME_POSITION: break
	return true

static func shuffle_points(points: Array, rng: RandomNumberGenerator) -> void:
	for i in range(points.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var point: Vector2 = points[i]
		points[i] = points[j]
		points[j] = point

static func spawn_points() -> Array:
	var result: Array = []
	for road in Roads.roads():
		for i in range(road.points.size()-1):
			var a: Vector2 = road.points[i]
			var b: Vector2 = road.points[i+1]
			var steps := maxi(1,ceili(a.distance_to(b)/35.0))
			for j in steps:
				var point := a.lerp(b,float(j)/steps)
				if spawn_inside_exit(point) and Roads.is_walkable(point) and clear_of_props(point) and not result.has(point): result.append(point)
	return result

static func spawn_inside_exit(point: Vector2) -> bool:
	# 最后一只蜥蜴左侧至出口为离场路段，初始与冷却刷新共用此边界。
	# 边界本身保留，允许蜥蜴在固定位置刷新。
	return point.x >= LAST_MONSTER_POSITION.x

## 无版本字段的进行中旧探索继续使用原13只怪物，结束后新探索才切换。
static func _legacy_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var layout := {
		"slime":[Vector2(995,225),Vector2(860,295),Vector2(613,421),Vector2(497,578),Vector2(956,582)],
		"snail":[Vector2(534,499),Vector2(539,789),Vector2(983,1132),Vector2(786,481)],
		"beetle":[Vector2(1086,755),Vector2(736,1119),Vector2(862,771)],
		"lizard":[Vector2(330,691)]}
	for kind in layout:
		for i in layout[kind].size():
			var row: Dictionary = TYPES[kind].duplicate(true)
			row.merge({"id":"%s_%d" % [kind,i+1], "kind":kind, "position":layout[kind][i], "direction":i%4})
			result.append(row)
	return result
static func find(id: String, version: int = BALANCE_VERSION, layout: Array = []) -> Dictionary:
	for row in all(version, layout):
		if row.id == id: return row
	return {}


## 首区旧布局保持原样；分水庭集合仅在首次到访时加入本趟。
const Rock = preload("res://data/maze/salt_boss.gd")
const Salt = preload("res://data/maze/salt_pool_encounters.gd")
const Frog = preload("res://data/maze/fenshui_boss.gd")
const Fenshui = preload("res://data/maze/fenshui_encounters.gd")
## 全局按种类计数必须包含未到访区域，不能用当前地图演员列表重建。
static func capture_kinds() -> Array:
	return TYPES.keys()+Fenshui.TYPES.keys()+["wind_frog","rockmane"]+Salt.TYPES.keys()

static func rows(c: Dictionary, every_region: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if every_region or c.get("region","maze_entry")=="maze_entry":
		result = all(BALANCE_VERSION,c.get("layout",[]))
	if c.get("fenshui_encounters",false) and (every_region or c.get("region","maze_entry")=="fenshui"):
		result.append_array(Fenshui.all())
	if c.get("frog_encounter",false) and (every_region or c.get("region","")=="fenshui"):
		result.append(Frog.row())
	if c.get("salt_encounters",false) and (every_region or c.get("region","")=="salt_pool"):
		result.append_array(Salt.all())
	if c.get("rock_encounter",false) and (every_region or c.get("region","")=="salt_pool"):
		result.append(Rock.row())
	return result

static func active(c: Dictionary, id: String) -> bool:
	if id in ["yufeng","salia"]: return true
	if id.begins_with("salt_pool_"): return c.get("region","")=="salt_pool"
	return (id.begins_with("fenshui_") and c.get("region","maze_entry")=="fenshui") or (not id.begins_with("fenshui_") and c.get("region","maze_entry")=="maze_entry")

static func targetable(c: Dictionary, id: String) -> bool:
	return id!=Frog.ID or c.actors[id].get("frog_phase","dormant") not in ["dormant","emerging"]
