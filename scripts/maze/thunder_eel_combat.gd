extends RefCounted
## 正式雷鳗岸水机会与局部范围放电；不改旧隔离试玩。
const Water=preload("res://data/maze/fenshui_encounters.gd")
const Roads=preload("res://data/maze/fenshui_roads.gd")
const Ground=preload("res://scripts/maze/silverfish_combat.gd")
const Spacing=preload("res://scripts/maze/water_spacing.gd")
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
const SHORE_LIMIT=55.0
const STOP_TIME=2.5
static var FORM_TIME: float=1.0
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
static var CHARGE_TIME: float=1.2
static var DISCHARGE_TIME: float=0.35
static var EXHAUST_TIME: float=4.0

static func configure() -> void:
 CHARGE_TIME=Tuning.effect("electric","windup",1200.0)/1000.0
 DISCHARGE_TIME=Tuning.effect("electric","recover",350.0)/1000.0
 EXHAUST_TIME=Tuning.number("eel.skill","rest",4.0)
 FORM_TIME=Tuning.number("eel.skill","form",1.0)

static func enabled(c: Dictionary, id: String) -> bool:
 configure()
 return c.get("region","")=="fenshui" and not c.get("fs01_trial",false) and id.begins_with("fenshui_thunder_eel_")

static func shielded(c: Dictionary, id: String) -> bool:
 if not enabled(c,id): return false
 var a: Dictionary=c.actors[id]
 return a.hp>0 and a.get("eel_phase","idle") not in ["stranded","returning","forming","exhausted"] and Water.water(Vector2(a.position[0],a.position[1]))

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

static func advance(run: Dictionary, row: Dictionary, hero: Vector2, dt: float, stats: Dictionary, skills: Script, hurt_feedback: Array=[]) -> void:
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[row.id]
 var pos:=vec(a.position)
 if not a.has("eel_phase"):
  a.eel_origin=pack(pos)
  a.eel_path=[]
  phase(a,"idle")
 if not a.has("eel_discharges"): a.eel_discharges=0
 a.velocity=[0.0,0.0]
 a.eel_left=maxf(0.0,float(a.eel_left)-dt)
 var wet:=Water.water(pos)
 # 力竭优先于回水和成泡；原外层受击击退仍保留，不允许提前补膜。
 if a.eel_phase=="exhausted":
  if a.eel_left<=0.00001:
   phase(a,"forming",FORM_TIME) if wet else phase(a,"returning")
  return
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
  elif a.eel_left<=0.00001:
   if int(a.eel_discharges)==3: a.eel_discharges=0
   phase(a,"idle")
  return
 if a.eel_phase=="discharge":
  if a.eel_left<=0.00001:
   a.eel_discharges+=1
   phase(a,"exhausted",EXHAUST_TIME) if int(a.eel_discharges)==3 else phase(a,"chasing")
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
   phase(a,"discharge",DISCHARGE_TIME)
   discharge(run,row,hero,int(Tuning.effect("electric","damage",float(stats.attack))),skills,hurt_feedback)
  return
 if float(a.get("hit_remaining",0.0))>0.0: return
 if wet:
  a.eel_origin=pack(pos)
  a.eel_path=[]
 if wet and distance<=Area.radius(row.id) and water_line(pos,hero):
  if a.cooldown<=0.00001:
   phase(a,"charging",CHARGE_TIME)
   a.cooldown=stats.interval*Tuning.effect("electric","interval_scale",100.0)/100.0
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

static func discharge(run: Dictionary, row: Dictionary, hero: Vector2, amount: int, skills: Script, hurt_feedback: Array=[]) -> void:
 var c: Dictionary=run.combat
 var center:=vec(c.actors[row.id].position)
 var shape:=Area.polygon(center,row.id)
 c.electric_serial=int(c.get("electric_serial",0))+1
 if c.hp>0 and Area.contains(shape,hero):
  var hp_before:=float(c.hp)
  if skills.receive_damage(run,amount):
   preload("res://scripts/maze/player_hurt_event.gd").record(c,hp_before,"electric",hero,center,hurt_feedback)
   c.last_attacker=row.kind
   c.hit_velocity=pack(center.direction_to(hero)*150.0)
   c.hit_remaining=0.12
   c.flash_remaining=0.1
 for id in c.actors:
  var frog: bool=preload("res://scripts/maze/wind_frog_counter.gd").enabled(c,id)
  if (not id.begins_with("fenshui_silverfish_") and not frog) or run.monsters[id].status!="alive": continue
  var fish: Dictionary=c.actors[id]
  if fish.hp<=0 or not Area.contains(shape,vec(fish.position)): continue
  fish.hp=maxf(0,float(fish.hp)-amount)
  if frog and amount>0: fish.frog_heal_quiet=0.0
  fish.flash_remaining=0.1
  fish.electric_left=4.0

static func point(value: Variant) -> bool:
 if not value is Array or value.size()!=2: return false
 for number in value:
  if typeof(number) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)): return false
 return true

static func valid(a: Dictionary) -> bool:
 if not a.has("eel_phase"):
  return not a.has("eel_left") and not a.has("eel_origin") and not a.has("eel_path") and not a.has("eel_discharges")
 if a.eel_phase not in ["idle","chasing","charging","discharge","stranded","returning","forming","exhausted"]: return false
 var completed: Variant=a.get("eel_discharges",0)
 if typeof(completed) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(completed)) or completed<0 or completed>3 or float(completed)!=floorf(float(completed)): return false
 if a.eel_phase=="exhausted" and (not a.has("eel_discharges") or completed!=3): return false
 if completed==3 and a.eel_phase not in ["exhausted","returning","forming"]: return false
 var left: Variant=a.get("eel_left")
 if typeof(left) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(left)) or left<0 or left>(EXHAUST_TIME if a.eel_phase=="exhausted" else STOP_TIME): return false
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
