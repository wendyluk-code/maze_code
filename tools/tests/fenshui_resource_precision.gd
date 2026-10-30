extends SceneTree
const R=preload("res://data/maze/region_resources.gd")
const Roads=preload("res://data/maze/fenshui_roads.gd")
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")

func old(region: String, point: Vector2, margin: float) -> bool:
 for row in R.all(region):
  if point.distance_to(row.position)<42.0+margin: return true
 return false

func direct(region: String, point: Vector2, margin: float) -> bool:
 for p in R.POINTS.get(region,[]):
  if point.distance_to(Vector2(p[1],p[2]))<42.0+margin: return true
 return false

func _initialize() -> void:
 var points:=PackedVector2Array()
 for center in [Vector2(980,440),Vector2(1100,440)]:
  for i in 128:
   for step in 64: points.append(center+Vector2.RIGHT.rotated(TAU*i/128.0)*minf(step*2.0,125.0))
 var start:=Time.get_ticks_usec()
 for point in points: old("fenshui",point,0)
 var resource_us:=Time.get_ticks_usec()-start
 start=Time.get_ticks_usec()
 for point in points: direct("fenshui",point,0)
 var direct_us:=Time.get_ticks_usec()-start
 start=Time.get_ticks_usec()
 for point in points:
  Roads.is_walkable(point,0)
  Roads.terrain_multiplier(point)
 var road_us:=Time.get_ticks_usec()-start
 var mismatches:=0
 for region in ["fenshui","salt_pool",""]:
  for margin in [0.0,15.0,42.0,-1.0]:
   for point in points:
    if old(region,point,margin)!=direct(region,point,margin) or R.protected(region,point,margin)!=old(region,point,margin): mismatches+=1
   for p in R.POINTS.get(region,[]):
    for delta in [-0.001,0.0,0.001]:
     var point:=Vector2(p[1],p[2])+Vector2(42.0+margin+delta,0)
     if old(region,point,margin)!=R.protected(region,point,margin): mismatches+=1
 var builds: Array=[]
 for center in [Vector2(980,440),Vector2(1100,440)]:
  start=Time.get_ticks_usec()
  Area.polygon(center,"resources")
  builds.append(Time.get_ticks_usec()-start)
 var report: Dictionary={"sample_count":points.size(),"resource_us":resource_us,"direct_us":direct_us,"road_us":road_us,"mismatches":mismatches,"cold_us":builds}
 FileAccess.open("user://resource-precision.json",FileAccess.WRITE).store_string(JSON.stringify(report))
 print("资源保护等价计时：",JSON.stringify(report))
 quit(1 if mismatches else 0)
