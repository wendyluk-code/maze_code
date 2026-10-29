extends RefCounted
## 正式雷鳗岸水机会；与隔离试玩及范围借电分开。
const Water=preload("res://data/maze/fenshui_encounters.gd")
const Roads=preload("res://data/maze/fenshui_roads.gd")
const Ground=preload("res://scripts/maze/silverfish_combat.gd")
const Spacing=preload("res://scripts/maze/water_spacing.gd")
const SHORE_LIMIT=55.0
const STOP_TIME=2.5
const FORM_TIME=1.0

static func enabled(c: Dictionary, id: String) -> bool:
 return c.get("region","")=="fenshui" and not c.get("fs01_trial",false) and id.begins_with("fenshui_thunder_eel_")

static func shielded(c: Dictionary, id: String) -> bool:
 if not enabled(c,id): return false
 var a: Dictionary=c.actors[id]
 return a.hp>0 and a.get("eel_phase","idle") not in ["stranded","returning","forming"] and Water.water(Vector2(a.position[0],a.position[1]))

static func damage_amount(c: Dictionary, id: String, amount: float) -> float:
 return maxf(1.0,amount*0.25) if amount>0 and shielded(c,id) else amount

static func vec(p: Array) -> Vector2:
 return Vector2(p[0],p[1])

static func pack(p: Vector2) -> Array:
 return [p.x,p.y]

static func phase(a: Dictionary, name: String, left: float=0.0) -> void:
 a.eel_phase=name
 a.eel_left=left
 a.mode="windup" if name=="charging" else ("idle" if name=="idle" else "chase")
 a.windup=left if name=="charging" else 0.0

static func travelled(a: Dictionary) -> float:
 var result:=0.0
 var last:=vec(a.eel_origin)
 for p in a.eel_path:
  result+=last.distance_to(vec(p))
  last=vec(p)
 return result

static func move(run: Dictionary, id: String, origin: Vector2, displacement: Vector2, stop_on_shore: bool=false) -> Vector2:
 var current:=origin
 var count:=maxi(1,ceili(displacement.length()/2.0))
 for i in count:
  var step:=displacement/count
  if stop_on_shore:
   var left:=maxf(0.0,SHORE_LIMIT-travelled(run.combat.actors[id]))
   step=step.limit_length(left)
   if step.is_zero_approx(): break
  var next:=current+step
  if not Ground.allowed(next) or not Spacing.clear(run,id,next): break
  current=next
  if stop_on_shore:
   var a: Dictionary=run.combat.actors[id]
   if Water.water(current):
    a.eel_origin=pack(current)
    a.eel_path=[]
   else: a.eel_path.append(pack(current))
   if Ground.dry(current): break
 return current

static func advance(run: Dictionary, row: Dictionary, hero: Vector2, dt: float, stats: Dictionary, skills: Script) -> void:
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[row.id]
 var pos:=vec(a.position)
 if not a.has("eel_phase"):
  a.eel_origin=pack(pos)
  a.eel_path=[]
  phase(a,"idle")
 a.velocity=[0.0,0.0]
 a.eel_left=maxf(0.0,float(a.eel_left)-dt)
 var wet:=Water.water(pos)
 # 任何蓄电离水都先取消，不能在同一帧结算残留电击。
 if a.eel_phase=="charging" and not wet:
  phase(a,"stranded",STOP_TIME) if Ground.dry(pos) else phase(a,"returning")
 if a.eel_phase=="stranded":
  if a.eel_left<=0.00001: phase(a,"returning")
  return
 if a.eel_phase=="returning":
  if wet:
   a.eel_path=[]
   phase(a,"forming",FORM_TIME)
   return
  if float(a.get("hit_remaining",0.0))>0.0: return
  var target:=vec(a.eel_path.back()) if not a.eel_path.is_empty() else vec(a.eel_origin)
  if target.distance_to(pos)<0.01:
   a.eel_path.pop_back()
   target=vec(a.eel_path.back()) if not a.eel_path.is_empty() else vec(a.eel_origin)
  var next:=move(run,row.id,pos,pos.direction_to(target)*minf(stats.speed*dt,pos.distance_to(target)))
  a.position=pack(next)
  a.velocity=pack((next-pos)/dt)
  if Water.water(next):
   a.eel_path=[]
   phase(a,"forming",FORM_TIME)
  return
 if a.eel_phase=="forming":
  if not wet: phase(a,"returning")
  elif a.eel_left<=0.00001: phase(a,"idle")
  return
 var distance:=pos.distance_to(hero)
 if a.eel_phase=="idle" and c.hp>0 and distance<=stats.trigger and not Water.protected(hero): phase(a,"chasing")
 if a.eel_phase in ["chasing","charging"]:
  a.away=a.away+dt if distance>stats.leash else 0.0
  if a.away>=1.0 or Water.protected(hero) or c.hp<=0:
   a.away=0.0
   phase(a,"idle") if wet else phase(a,"returning")
   return
 if a.eel_phase=="idle":
  Spacing.patrol(run,row,dt)
  a.velocity=pack((vec(a.position)-pos)/dt)
  a.eel_origin=a.position.duplicate()
  a.eel_path=[]
  return
 if a.eel_phase=="charging":
  a.windup=a.eel_left
  if a.eel_left<=0.00001:
   if c.hp>0 and wet and distance<=stats.reach and water_line(pos,hero):
    c.hp=maxf(0,c.hp-skills.incoming_damage(run,int(stats.attack)))
    c.last_attacker=row.kind
    var direction:=pos.direction_to(hero)
    c.hit_velocity=pack(direction*150.0)
    c.hit_remaining=0.12
    c.flash_remaining=0.1
   phase(a,"chasing")
  return
 if float(a.get("hit_remaining",0.0))>0.0: return
 if wet:
  a.eel_origin=pack(pos)
  a.eel_path=[]
 if wet and distance<=stats.reach and water_line(pos,hero):
  if a.cooldown<=0.00001:
   phase(a,"charging",stats.windup)
   a.cooldown=stats.interval
  return
 var remaining:=maxf(0.0,SHORE_LIMIT-travelled(a))
 var next:=move(run,row.id,pos,pos.direction_to(hero)*minf(stats.speed*dt,minf(distance,remaining)),true)
 a.position=pack(next)
 a.velocity=pack((next-pos)/dt)
 if Water.water(next):
  a.eel_origin=pack(next)
  a.eel_path=[]
 else:
  if Ground.dry(next): phase(a,"stranded",STOP_TIME)
  elif next.distance_to(pos)<0.00001 or travelled(a)>=SHORE_LIMIT-0.00001: phase(a,"returning")

static func water_line(start: Vector2, finish: Vector2) -> bool:
 var steps:=maxi(1,ceili(start.distance_to(finish)/2.0))
 for i in range(steps+1):
  if not Water.water(start.lerp(finish,float(i)/steps),0.0): return false
 return true

static func point(value: Variant) -> bool:
 if not value is Array or value.size()!=2: return false
 for number in value:
  if typeof(number) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)): return false
 return true

static func valid(a: Dictionary) -> bool:
 if not a.has("eel_phase"):
  return not a.has("eel_left") and not a.has("eel_origin") and not a.has("eel_path")
 if a.eel_phase not in ["idle","chasing","charging","stranded","returning","forming"]: return false
 var left: Variant=a.get("eel_left")
 if typeof(left) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(left)) or left<0 or left>STOP_TIME: return false
 if not point(a.get("eel_origin")) or not Water.water(vec(a.eel_origin)): return false
 if not a.get("eel_path") is Array: return false
 var previous:=vec(a.eel_origin)
 var length:=0.0
 for p in a.eel_path:
  if not point(p): return false
  var next:=vec(p)
  length+=previous.distance_to(next)
  var steps:=maxi(1,ceili(previous.distance_to(next)/2.0))
  for i in range(steps+1):
   if not Ground.allowed(previous.lerp(next,float(i)/steps)): return false
  previous=next
 if length>SHORE_LIMIT+0.001: return false
 return Ground.allowed(vec(a.position))
