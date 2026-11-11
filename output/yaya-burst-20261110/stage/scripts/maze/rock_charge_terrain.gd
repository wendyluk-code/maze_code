extends RefCounted
## 仅水晶、树丛和地图外缘阻挡冲撞及击飞；普通走路仍使用原地形。
const Roads=preload("res://data/maze/salt_pool_roads.gd")
const Crystals=preload("res://scripts/maze/salt_crystals.gd")
const TREES=[9,10,11,12,13,14,15]
static func touches(point: Vector2, shape: PackedVector2Array, radius: float) -> bool:
 if Geometry2D.is_point_in_polygon(point,shape): return true
 return Roads._near_edge(point,shape,radius)
static func allowed(point: Vector2,radius: float=4.0) -> bool:
 if not point.is_finite() or not Geometry2D.is_point_in_polygon(point,Roads.OUTLINE) or Roads._near_edge(point,Roads.OUTLINE,radius): return false
 for index in TREES:
  if touches(point,Roads.BLOCKERS[index],radius): return false
 for group in Crystals.SHAPES:
  for shape in group:
   if touches(point,shape,radius): return false
 return true
static func move(origin: Vector2,displacement: Vector2,radius: float=4.0) -> Vector2:
 var count:=maxi(1,ceili(displacement.length()/1.0))
 var current:=origin
 for i in range(1,count+1):
  var next:=origin+displacement*float(i)/count
  if not allowed(next,radius): break
  current=next
 return current

static func impact_alignment(contact: Vector2, aim: Vector2) -> float:
 # 以最近硬障碍边缘的实际接触法线区分正撞与擦边，圆角使用接触点方向。
 var shapes: Array=[Roads.OUTLINE]
 for index in TREES: shapes.append(Roads.BLOCKERS[index])
 for group in Crystals.SHAPES:
  for shape in group: shapes.append(shape)
 var nearest:=INF
 var alignment:=0.0
 for shape in shapes:
  for i in shape.size():
   var first: Vector2=shape[i]
   var second: Vector2=shape[(i+1)%shape.size()]
   var closest:=Geometry2D.get_closest_point_to_segment(contact,first,second)
   var distance:=contact.distance_squared_to(closest)
   if distance<nearest:
    nearest=distance
    var normal:=contact.direction_to(closest)
    if normal.is_zero_approx(): normal=(second-first).orthogonal().normalized()
    alignment=absf(aim.normalized().dot(normal))
 return alignment
