extends SceneTree
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
const Water=preload("res://data/maze/fenshui_encounters.gd")
var failed: Array=[]

func _initialize() -> void:
 call_deferred("run_probe")

func single(point: Vector2) -> bool:
 if Water.protected(point,0.0): return false
 return Water.Roads.is_walkable(point,0.0) and Water.Roads.terrain_multiplier(point)==Water.Roads.WATER_SPEED

func run_probe() -> void:
 var times: Array=[]
 var samples:=PackedVector2Array()
 var polygons: Array=[]
 var mismatch:=0
 for center in [Vector2(980,440),Vector2(1100,440)]:
  var start:=Time.get_ticks_usec()
  var shape:=Area.polygon(center,"probe")
  var cold:=Time.get_ticks_usec()-start
  start=Time.get_ticks_usec()
  for repeat in 100: Area.polygon(center,"probe")
  times.append({"center":str(center),"cold_us":cold,"cache_100_us":Time.get_ticks_usec()-start})
  var packed: Array=[]
  for p in shape: packed.append([p.x,p.y])
  polygons.append(packed)
  for left in [0.35,0.349,0.34,0.30,0.20,0.05,0.0]:
   var progress:=clampf(1.0-left/0.35,0.02,1.0)
   var inner:=maxf(0.0,progress-0.055)
   for i in shape.size():
    var first: Vector2=shape[i]-center
    var last: Vector2=shape[(i+1)%shape.size()]-center
    var band:=PackedVector2Array([center+first*inner,center+first*progress,center+last*progress])
    if inner>0: band.append(center+last*inner)
    var local:=PackedVector2Array()
    for p in band: local.append(p-center)
    if Geometry2D.triangulate_polygon(band).is_empty():
     var vertices: Array=[]
     var area:=0.0
     for j in local.size():
      vertices.append([band[j].x,band[j].y])
      area+=local[j].cross(local[(j+1)%local.size()])
     failed.append({"center":str(center),"left":left,"sector":i,"vertices":vertices,"local_triangles":Geometry2D.triangulate_polygon(local).size(),"area":area*0.5,"duplicate":local[0]==local[local.size()-1],"self_cross":Geometry2D.segment_intersects_segment(local[0],local[1],local[2],local[3])!=null if local.size()==4 else false})
  for i in 128:
   var direction:=Vector2.RIGHT.rotated(TAU*i/128.0)
   for step in range(64): samples.append(center+direction*minf(step*2.0,125.0))
 var start:=Time.get_ticks_usec()
 var old: Array=[]
 for point in samples: old.append(Water.water(point,0.0))
 var old_us:=Time.get_ticks_usec()-start
 start=Time.get_ticks_usec()
 for i in samples.size():
  if old[i]!=single(samples[i]): mismatch+=1
 var result: Dictionary={"failed":failed,"build_times":times,"sample_count":samples.size(),"zero_old_us":old_us,"zero_single_us":Time.get_ticks_usec()-start,"zero_mismatch":mismatch,"polygons":polygons}
 var output:="user://area-precision.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--probe="): output=arg.trim_prefix("--probe=")
 if not output.is_empty(): FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("原坐标失败扇区：",failed.size(),"；局部仍失败：",failed.filter(func(row): return row.local_triangles==0).size(),"；零半径等价差异：",mismatch,"；计时：",times,"；零半径旧/单点微秒：",old_us,"/",result.zero_single_us)
 quit(0)
