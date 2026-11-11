extends RefCounted
## 迷宫共用脚底实体；显示画布、保护膜和空中身体不参与地面占位。
const Catalog=preload("res://data/maze/capture_catalog.gd")

static func enabled(run: Dictionary) -> bool:
 var c: Dictionary=run.get("combat",{})
 return c.has("actors") and not c.get("fs01_trial",false)

static func footprint(id: String) -> Vector2:
 if id=="hero": return Vector2(7,4)
 if id.contains("rockmane"): return Vector2(38,20)
 if id.contains("wind_frog"): return Vector2(38,20)
 if id.contains("thunder_eel"): return Vector2(17,9)
 if id.contains("lizard"): return Vector2(18,10)
 if id.contains("mimic_crab") or id.contains("blind_scorpion"): return Vector2(12,8)
 return Vector2(10,7)

static func vec(p: Array) -> Vector2:
 return Vector2(p[0],p[1])

static func separates(origin: Vector2, target: Vector2, center: Vector2, size: Vector2) -> bool:
 var before:=((origin-center)/size).length_squared()
 var after:=((target-center)/size).length_squared()
 if before<1.0: return after>before+0.000001 and ((origin-center)/size).dot((target-origin)/size)>=-0.000001
 return Geometry2D.get_closest_point_to_segment(Vector2.ZERO,(origin-center)/size,(target-center)/size).length_squared()>=0.999999

static func step(run: Dictionary, id: String, origin: Vector2, target: Vector2, include_hero: bool=true) -> bool:
 if not enabled(run): return true
 var c: Dictionary=run.combat
 for other in c.actors:
  if other==id or not Catalog.active(c,str(other)): continue
  var a: Dictionary=c.actors[other]
  if not run.monsters.has(other) or run.monsters[other].status!="alive" or a.hp<=0: continue
  var size:=footprint(id)+footprint(other)
  var phase: String=a.get("frog_phase","")
  if phase not in ["airborne","toppling"] and not separates(origin,target,vec(a.position),size): return false
  if phase in ["warning","airborne","toppling"] and not separates(origin,target,vec(a.frog_target),size): return false
 if include_hero and id!="hero" and c.hp>0 and not separates(origin,target,vec(c.hero),footprint(id)+footprint("hero")): return false
 return true

static func move(run: Dictionary,id: String,origin: Vector2,target: Vector2,include_hero: bool=true) -> Vector2:
 var count:=maxi(1,ceili(origin.distance_to(target)/2.0))
 var current:=origin
 for i in range(1,count+1):
  var next:=origin.lerp(target,float(i)/count)
  if not step(run,id,current,next,include_hero): break
  current=next
 return current

