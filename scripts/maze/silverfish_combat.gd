extends RefCounted
## 正式银鳞鱼的岸水机会；状态由既有探索事务保存。
const Water=preload("res://data/maze/fenshui_encounters.gd")
const Roads=preload("res://data/maze/fenshui_roads.gd")
const Spacing=preload("res://scripts/maze/water_spacing.gd")
const Rush=preload("res://scripts/maze/fenshui_borrow_lightning.gd")
const STRANDED_TIME=2.5
const FORM_TIME=1.0

static func enabled(c: Dictionary, id: String) -> bool:
 return c.get("region","")=="fenshui" and not c.get("fs01_trial",false) and id.begins_with("fenshui_silverfish_")

static func shielded(c: Dictionary, id: String) -> bool:
 if not enabled(c,id): return false
 var a: Dictionary=c.actors[id]
 return a.hp>0 and float(a.get("electric_left",0.0))<=0.0 and a.get("fish_phase","") not in ["stranded","returning","forming"] and Water.water(vec(a.position),0.0)

static func damage_amount(c: Dictionary, id: String, amount: float) -> float:
 return maxf(1.0,amount*0.25) if amount>0 and shielded(c,id) else amount

static func vec(p: Array) -> Vector2:
 return Vector2(p[0],p[1])

static func pack(p: Vector2) -> Array:
 return [p.x,p.y]

static func allowed(point: Vector2) -> bool:
 if Water.protected(point,Water.BODY_RADIUS): return false
 for i in 9:
  var p:=point if i==8 else point+Vector2.RIGHT.rotated(i*TAU/8)*Water.BODY_RADIUS
  if not Roads.is_walkable(p,0): return false
 return true

static func dry(point: Vector2) -> bool:
 for i in 9:
  var p:=point if i==8 else point+Vector2.RIGHT.rotated(i*TAU/8)*Water.BODY_RADIUS
  if Roads.terrain_multiplier(p)==Roads.WATER_SPEED: return false
 return true

static func move(run: Dictionary, id: String, origin: Vector2, displacement: Vector2) -> Vector2:
 var current:=origin
 var count:=maxi(1,ceili(displacement.length()/2))
 for i in count:
  var next:=current+displacement/count
  if not allowed(next) or not Spacing.clear(run,id,next): break
  current=next
 return current

static func phase(a: Dictionary, name: String, duration: float) -> void:
 a.fish_phase=name
 a.fish_left=duration
 a.windup=duration if name=="warning" else 0.0
 a.mode="windup" if name=="warning" else ("idle" if name=="idle" else "chase")

static func advance(run: Dictionary, row: Dictionary, point: Vector2, dt: float, stats: Dictionary, skills: Script) -> void:
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[row.id]
 var pos:=vec(a.position)
 if not a.has("fish_phase"):
  a.fish_origin=pack(pos)
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  phase(a,"idle",0)
 a.velocity=[0.0,0.0]
 var current: String=a.fish_phase
 a.fish_left=maxf(0,float(a.fish_left)-dt)
 if current=="idle":
  if c.hp>0 and not Water.protected(point) and pos.distance_to(point)<=stats.trigger:
   a.fish_origin=pack(pos)
   var aim:=pos.direction_to(point)
   a.fish_aim=pack(Vector2.DOWN if aim.is_zero_approx() else aim)
   a.fish_hit=false
   phase(a,"warning",Rush.WARNING_FISH)
  else:
   a.mode="idle"
   Spacing.patrol(run,row,dt)
   a.velocity=pack((vec(a.position)-pos)/dt)
 elif current=="warning":
  a.windup=a.fish_left
  if a.fish_left<=0.00001: phase(a,"rush",Rush.RUSH_LENGTH/Rush.RUSH_SPEED)
 elif current=="rush":
  var next:=move(run,row.id,pos,vec(a.fish_aim)*Rush.RUSH_SPEED*dt)
  a.position=pack(next)
  a.velocity=pack((next-pos)/dt)
  var closest:=Geometry2D.get_closest_point_to_segment(point,pos,next)
  if not a.fish_hit and c.hp>0 and not Water.protected(point) and point.distance_to(closest)<=18:
   c.hp=maxf(0,c.hp-skills.incoming_damage(run,int(stats.attack)))
   c.last_attacker=row.kind
   c.flash_remaining=0.1
   a.fish_hit=true
  if dry(next): phase(a,"stranded",STRANDED_TIME)
  elif a.fish_left<=0.00001 or next.distance_to(pos)<0.001:
   phase(a,"recover",0.9) if Water.water(next) else phase(a,"stranded",STRANDED_TIME)
 elif current=="stranded":
  if a.fish_left<=0.00001: phase(a,"returning",0)
 elif current=="returning":
  var target:=vec(a.fish_origin)
  var next:=move(run,row.id,pos,pos.direction_to(target)*minf(stats.speed*dt,pos.distance_to(target)))
  a.position=pack(next)
  a.velocity=pack((next-pos)/dt)
  if Water.water(next): phase(a,"forming",FORM_TIME)
 elif current in ["forming","recover"]:
  if a.fish_left<=0.00001: phase(a,"idle",0)

static func valid(a: Dictionary) -> bool:
 if a.has("electric_left"):
  var remaining: Variant=a.electric_left
  if typeof(remaining) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(remaining)) or remaining<0 or remaining>4.0: return false
 if not a.has("fish_phase"):
  return not a.has("fish_left") and not a.has("fish_origin") and not a.has("fish_aim") and not a.has("fish_hit")
 if a.fish_phase not in ["idle","warning","rush","stranded","returning","forming","recover"]: return false
 var left: Variant=a.get("fish_left")
 if typeof(left) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(left)) or left<0 or left>STRANDED_TIME: return false
 for key in ["fish_origin","fish_aim"]:
  var value: Variant=a.get(key)
  if not value is Array or value.size()!=2: return false
  for n in value:
   if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)): return false
 if absf(vec(a.fish_aim).length()-1)>0.001 or not a.get("fish_hit") is bool: return false
 return allowed(vec(a.position)) and Water.water(vec(a.fish_origin))

