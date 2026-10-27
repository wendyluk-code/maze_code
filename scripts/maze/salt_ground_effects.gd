extends Node2D
## 效果仅影响地表显示；不会改动碰撞、角色或存档。
const Terrain = preload("res://data/maze/salt_pool_roads.gd")
const LIFETIME := 4.0
var player: Node2D
var footprints: Array[Dictionary] = []
var _last := Vector2.ZERO
var _distance := 0.0
var _side := 1.0
func _ready() -> void:
 _last = player.position
func _process(delta: float) -> void:
 if player.input_locked: return
 for footprint in footprints: footprint.age += delta
 footprints = footprints.filter(func(f): return f.age < LIFETIME)
 var moved := player.position.distance_to(_last)
 _last = player.position
 if moved > 60.0:
  _distance = 0.0
 elif moved > 0.01 and Terrain.terrain_multiplier(player.position)<1.0 and Terrain.is_walkable(player.position):
  _distance += moved
  if _distance>=12.0:
   _distance = fmod(_distance,12.0)
   _side = -_side
   footprints.append({"point":player.position+player.facing.orthogonal()*3.0*_side,"angle":player.facing.angle(),"age":0.0})
 elif not player._walking or Terrain.terrain_multiplier(player.position)>=1.0:
  _distance = 0.0
 queue_redraw()
func _draw() -> void:
 for f in footprints:
  draw_set_transform(f.point,f.angle,Vector2(1.7,0.8))
  draw_circle(Vector2.ZERO,2.0,Color(0.36,0.40,0.40,0.30*(1.0-f.age/LIFETIME)),true,-1,true)
 draw_set_transform(Vector2.ZERO)
