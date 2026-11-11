extends RefCounted
## 岩鬃兽预警、释放裁切与命中共享的世界坐标范围；不含战斗状态。
const Roads=preload("res://data/maze/salt_pool_roads.gd")
const Crystals=preload("res://scripts/maze/salt_crystals.gd")
static var RADIUS:=260.0
static var HALF_ANGLE:=PI*35.0/180.0
static var _cache: Dictionary={}

static func reach(origin: Vector2, direction: Vector2, maximum: float) -> float:
 var distance:=maximum
 for obstacle in Roads.OBSTACLES:
  var radii:=Vector2(obstacle.z,obstacle.w)
  var start:=(origin-Vector2(obstacle.x,obstacle.y))/radii
  if start.length_squared()<=1.0: return 0.0
  var ray:=direction/radii
  var a:=ray.dot(ray)
  var b:=2.0*start.dot(ray)
  var c:=start.dot(start)-1.0
  var discriminant:=b*b-4.0*a*c
  if discriminant>=0.0 and a>0.0:
   var hit:=(-b-sqrt(discriminant))/(2.0*a)
   if hit>=0.0: distance=minf(distance,hit)
 for group in Crystals.SHAPES:
  for shape in group:
   if Geometry2D.is_point_in_polygon(origin,shape): return 0.0
   for i in shape.size():
    var hit=Geometry2D.segment_intersects_segment(origin,origin+direction*distance,shape[i],shape[(i+1)%shape.size()])
    if hit!=null: distance=minf(distance,origin.distance_to(hit))
 return distance

static func clear(origin: Vector2, target: Vector2) -> bool:
 var distance:=origin.distance_to(target)
 return reach(origin,origin.direction_to(target),distance+0.001)>distance

static func polygon(origin: Vector2, aim: Vector2) -> PackedVector2Array:
 RADIUS=preload("res://scripts/maze/combat_tuning.gd").number("rock.roar","range",260.0)
 HALF_ANGLE=deg_to_rad(preload("res://scripts/maze/combat_tuning.gd").number("rock.roar","angle",70.0)/2.0)
 if _cache.get("origin")==origin and _cache.get("aim")==aim and _cache.get("radius")==RADIUS and _cache.get("angle")==HALF_ANGLE: return _cache.shape
 var angle:=aim.angle()
 var angles: Array[float]=[]
 for i in 141: angles.append(-HALF_ANGLE+2.0*HALF_ANGLE*i/140.0)
 for group in Crystals.SHAPES:
  for shape in group:
   for point in shape:
    var relative:=wrapf(origin.angle_to_point(point)-angle,-PI,PI)
    for delta in [-0.0001,0.0,0.0001]:
     if absf(relative+delta)<HALF_ANGLE: angles.append(relative+delta)
 angles.sort()
 var shape:=PackedVector2Array([origin])
 var previous:=-INF
 for relative in angles:
  if relative-previous<0.000001: continue
  previous=relative
  var direction:=Vector2.RIGHT.rotated(angle+relative)
  shape.append(origin+direction*reach(origin,direction,RADIUS))
 _cache={"origin":origin,"aim":aim,"shape":shape,"radius":RADIUS,"angle":HALF_ANGLE}
 return shape

static func contains(shape: PackedVector2Array, point: Vector2) -> bool:
 if shape.size()<3: return false
 if Geometry2D.is_point_in_polygon(point,shape): return true
 for i in shape.size():
  if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,shape[i],shape[(i+1)%shape.size()]))<0.00000001: return true
 return false
