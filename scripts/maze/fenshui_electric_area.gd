extends RefCounted
## 正式范围预警、扩散裁切与命中共用的局部水域；不含战斗状态。
const Water=preload("res://data/maze/fenshui_encounters.gd")
const RADIUS=125.0
const DIRECTIONS=128
static func radius(source: String) -> float:
 return preload("res://scripts/maze/combat_tuning.gd").number("frog.skill" if source.ends_with("_slam") else "eel.skill","range",RADIUS)
static var _cache: Dictionary={}

static func polygon(center: Vector2, source: String) -> PackedVector2Array:
 if _cache.has(source) and _cache[source].center==center and _cache[source].get("radius")==radius(source): return _cache[source].polygon
 var shape:=PackedVector2Array()
 if Water.water(center,0.0):
  var radius_limit:=radius(source)
  var reach: Array[float]=[]
  for i in DIRECTIONS:
   var direction:=Vector2.RIGHT.rotated(TAU*i/DIRECTIONS)
   var length:=0.0
   for step in range(1,ceili(radius_limit/2.0)+1):
    var distance:=minf(step*2.0,radius_limit)
    if not Water.water(center+direction*distance,0.0): break
    length=distance
   reach.append(length)
  for i in DIRECTIONS:
   var length:=minf(reach[i],minf(reach[(i+1)%DIRECTIONS],reach[(i+DIRECTIONS-1)%DIRECTIONS]))
   shape.append(center+Vector2.RIGHT.rotated(TAU*i/DIRECTIONS)*length)
 _cache[source]={"center":center,"radius":radius(source),"polygon":shape}
 return shape

static func contains(shape: PackedVector2Array, point: Vector2) -> bool:
 if shape.size()<3: return false
 if Geometry2D.is_point_in_polygon(point,shape): return true
 for i in shape.size():
  if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,shape[i],shape[(i+1)%shape.size()]))<0.00000001: return true
 return false
