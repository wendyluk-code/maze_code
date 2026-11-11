extends SceneTree
const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Boss=preload("res://data/maze/salt_boss.gd")
func _initialize() -> void:
 var points: Array=[]
 for y in range(340,611,10):
  for x in range(700,1001,10):
   var p:=Vector2(x,y)
   if Salt.is_walkable(p) and p.distance_to(Boss.HOME)>70 and p.distance_to(Boss.HOME)<140:
    points.append(p)
 print("OLD_TEST_POINT_WALKABLE=",Salt.is_walkable(Vector2(850,550)))
 print("SAFE_POINTS=",points.slice(0,20))
 quit(0 if not points.is_empty() else 1)
