extends SceneTree
const Rock=preload("res://scripts/maze/rockmane_combat.gd")
var results: Array=[]
var failures:=0
func check(ok: bool, name: String) -> void:
 results.append({"name":name,"passed":ok})
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",name)
func _initialize() -> void:
 var origin:=Vector2(850,425)
 check(Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2(10,0)),"近身正前可命中")
 check(not Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2(-10,0)),"24像素内背后不能命中")
 check(not Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2(0,10)),"24像素内侧面不能命中")
 check(not Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2(100,100)),"扇形侧外不能命中")
 check(Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2(260,0)),"260边界可命中")
 check(not Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2(260.1,0)),"260外不能命中")
 for degrees in [-35.0,-34.9,0.0,34.9,35.0]:
  check(Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2.RIGHT.rotated(deg_to_rad(degrees))*80.0),"角度边界以内 "+str(degrees))
 for degrees in [-35.1,35.1,90.0,180.0]:
  check(not Rock.roar_hits(origin,Vector2.RIGHT,origin+Vector2.RIGHT.rotated(deg_to_rad(degrees))*10.0),"近身角度边界外 "+str(degrees))
 check(not Rock.roar_hits(Vector2(1026,479),Vector2.RIGHT,Vector2(1146,479)),"岩石后不命中")
 check(Rock.roar_hits(Vector2(1026,479),Vector2.RIGHT,Vector2(1056,479)),"岩石前命中")
 check(not Rock.roar_hits(Vector2(1100,330),Vector2.RIGHT,Vector2(1200,330)),"盐晶后不命中")
 check(Rock.roar_hits(Vector2(1100,330),Vector2.RIGHT,Vector2(1120,330)),"盐晶前命中")
 check(Rock.roar_hits(Vector2(1000,420),Vector2.RIGHT,Vector2(1200,420)),"声波跨水池不被水挡")
 var equal:=true
 var shadow_clear:=true
 for center in [origin,Vector2(1026,479),Vector2(1100,330)]:
  var shape:=Rock.RoarArea.polygon(center,Vector2.RIGHT)
  for degrees in range(-40,41,2):
   for distance in range(5,271,5):
    var point: Vector2=center+Vector2.RIGHT.rotated(deg_to_rad(degrees))*distance
    var hit:=Rock.roar_hits(center,Vector2.RIGHT,point)
    equal=equal and hit==Rock.RoarArea.contains(shape,point)
    if hit and not Rock.roar_clear(center,point): shadow_clear=false
 check(equal,"6642个点预警轮廓与命中同源")
 check(shadow_clear,"采样命中点不落在岩石盐晶遮挡后")
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):
   var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
   file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"results":results},"  "))
 quit(1 if failures else 0)
