extends RefCounted
const Terrain = preload("res://data/maze/salt_pool_roads.gd")
const Atlas = preload("res://data/maze/entry_map_projection.gd")
## 盐池场景映射到同一张浅层总图；入口与分水庭北侧路标共用锚点。
const SCALE := Vector2(0.23, 0.27)
var entrance_anchor := preload("res://data/maze/fenshui_projection.gd").new().project(Terrain.FENSHUI_PORTAL)
func project(point: Vector2) -> Vector2:
 var mapped := entrance_anchor + (point - Terrain.ENTRANCE) * SCALE
 # 左侧道路逐步校准到青苔池连接；保持分水庭入口原锚点不动。
 var link = preload("res://data/maze/moss_pool_roads.gd")
 var old_link: Vector2 = entrance_anchor + (link.SALT_SIDE_MARKER - Terrain.ENTRANCE) * SCALE
 return mapped + (link.SALT_LINK_ATLAS-old_link)*clampf((300.0-point.x)/265.0,0.0,1.0)
func project_direction(_point: Vector2, direction: Vector2) -> Vector2:
 return (project(_point+direction*2.0)-project(_point)).normalized()
