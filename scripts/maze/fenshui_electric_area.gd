extends RefCounted
## 正式范围预警、扩散裁切与命中共用的局部水域；不含战斗状态。
const Water=preload("res://data/maze/fenshui_encounters.gd")
const RADIUS=125.0
const DIRECTIONS=128
static func radius(source: String) -> float:
 return preload("res://scripts/maze/combat_tuning.gd").number("frog.skill" if source.ends_with("_slam") else "eel.skill","range",RADIUS)
static var _cache: Dictionary={}

static func _bounds(points: PackedVector2Array) -> Rect2:
 var box:=Rect2(points[0],Vector2.ZERO)
 for point in points: box=box.expand(point)
 return box.grow(0.01)

static func _query(center: Vector2, limit: float) -> Dictionary:
 # 本次所有采样都在此矩形内；仅排除完全不相交的对象，最终仍用原几何公式。
 var box:=Rect2(center-Vector2.ONE*limit,Vector2.ONE*limit*2.0).grow(0.01)
 var query: Dictionary={"protected":[],"gates":[],"edges":[],"low":[],"high":[],"dry":[]}
 var foot: Vector2=preload("res://data/maze/yf_encounter_site.gd").CHAT_FOOT
 var circles: Array[Vector3]=[Vector3(foot.x,foot.y,190.0)]
 for point in preload("res://data/maze/region_resources.gd").POINTS.get("fenshui",[]):
  circles.append(Vector3(point[1],point[2],42.0))
 for circle in circles:
  if box.intersects(Rect2(Vector2(circle.x-circle.z,circle.y-circle.z),Vector2.ONE*circle.z*2.0).grow(0.01)): query.protected.append(circle)
 for gate in Water.Roads.Gates.GATES:
  var direction: Vector2=(gate.b-gate.a).normalized()
  var a: Vector2=gate.a-direction*18.0
  var b: Vector2=gate.b+direction*18.0
  if box.intersects(_bounds(PackedVector2Array([a,b])).grow(5.0)): query.gates.append([a,b])
 for edge in Water.Roads.WATER_EDGES:
  var bounds:=_bounds(edge)
  if box.intersects(bounds): query.edges.append([edge,bounds])
 for i in Water.Roads.ISLANDS.size():
  var island: Vector4=Water.Roads.ISLANDS[i]
  if box.intersects(Rect2(Vector2(island.x-island.z,island.y-island.w),Vector2(island.z,island.w)*2.0).grow(0.01)):
   if i in Water.Roads.LOW_ISLANDS: query.low.append(island)
   else: query.high.append(island)
 for road in Water.Roads.dry_paths():
  for i in range(road.points.size()-1):
   var a: Vector2=road.points[i]
   var b: Vector2=road.points[i+1]
   var bounds:=_bounds(PackedVector2Array([a,b])).grow(road.width)
   if box.intersects(bounds): query.dry.append([a,b,road.width,bounds])
 return query

static func _water(point: Vector2, query: Dictionary) -> bool:
 # 等价于Water.water(point,0)：低岛/干路优先，水边覆盖粗略岛体，但不覆盖保护区/栅栏。
 for circle: Vector3 in query.protected:
  if point.distance_to(Vector2(circle.x,circle.y))<circle.z: return false
 for gate in query.gates:
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point,gate[0],gate[1]))<5.0: return false
 if Geometry2D.is_point_in_polygon(point,Water.Roads.ROAD_EDGE): return false
 for island: Vector4 in query.low:
  if point.x<island.x-island.z-0.01 or point.x>island.x+island.z+0.01 or point.y<island.y-island.w-0.01 or point.y>island.y+island.w+0.01: continue
  if ((point-Vector2(island.x,island.y))/Vector2(island.z,island.w)).length()<=1.0: return false
 for edge in query.edges:
  if edge[1].has_point(point) and Geometry2D.is_point_in_polygon(point,edge[0]): return true
 if not Geometry2D.is_point_in_polygon(point,Water.Roads.OUTLINE): return false
 for island: Vector4 in query.high:
  if point.x<island.x-island.z-0.01 or point.x>island.x+island.z+0.01 or point.y<island.y-island.w-0.01 or point.y>island.y+island.w+0.01: continue
  if ((point-Vector2(island.x,island.y))/Vector2(island.z,island.w)).length()<=1.0: return false
 for segment in query.dry:
  if segment[3].has_point(point) and point.distance_to(Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1]))<=segment[2]: return false
 return true

static func polygon(center: Vector2, source: String) -> PackedVector2Array:
 if _cache.has(source) and _cache[source].center==center and _cache[source].get("radius")==radius(source): return _cache[source].polygon
 var shape:=PackedVector2Array()
 if Water.water(center,0.0):
  var radius_limit:=radius(source)
  var query:=_query(center,radius_limit)
  var reach: Array[float]=[]
  for i in DIRECTIONS:
   var direction:=Vector2.RIGHT.rotated(TAU*i/DIRECTIONS)
   var length:=0.0
   for step in range(1,ceili(radius_limit/2.0)+1):
    var distance:=minf(step*2.0,radius_limit)
    if not _water(center+direction*distance,query): break
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
