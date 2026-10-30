extends RefCounted
## 分水庭隔离试玩：锁向冲刺与局部导电。阶段随现有探索事务保存。
const Water = preload("res://data/maze/fenshui_encounters.gd")
const Roads = preload("res://data/maze/fenshui_roads.gd")
const Spacing = preload("res://scripts/maze/water_spacing.gd")
const IDS := ["fenshui_silverfish_1", "fenshui_silverfish_2", "fenshui_thunder_eel_1"]
const ELECTRIC_RADIUS := 125.0
const RUSH_LENGTH := 110.0
const RUSH_SPEED := 220.0
const WARNING_FISH := 0.75
const WARNING_EEL := 1.2

static func enabled(c: Dictionary, row: Dictionary) -> bool:
 return c.get("fs01_trial",false) and c.get("region","")=="fenshui" and row.id in IDS

static func vec(value: Array) -> Vector2:
 return Vector2(value[0],value[1])

static func pack(point: Vector2) -> Array:
 return [point.x,point.y]

static func wet(point: Vector2) -> bool:
 return Roads.is_walkable(point,0.0) and Roads.terrain_multiplier(point)==Roads.WATER_SPEED

## 显示和伤害共用此判定；距离、岸路、植被岛和栅栏均截断传播。
static func conducts(origin: Vector2, target: Vector2) -> bool:
 if origin.distance_to(target)>ELECTRIC_RADIUS: return false
 var steps := maxi(1,ceili(origin.distance_to(target)/2.0))
 for i in range(steps+1):
  if not wet(origin.lerp(target,float(i)/steps)): return false
 return true

static func rush_end(origin: Vector2, aim: Vector2) -> Vector2:
 return Water.move(origin,aim*RUSH_LENGTH,origin)

static func advance(run: Dictionary, row: Dictionary, point: Vector2, dt: float, stats: Dictionary, skills: Script) -> void:
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[row.id]
 var pos := vec(a.position)
 a.velocity=[0.0,0.0]
 var phase: String=a.get("fs_phase","idle")
 if phase=="idle":
  a.mode="idle"
  if c.hp>0 and wet(point) and not Water.protected(point) and pos.distance_to(point)<=145.0:
   a.fs_phase="warning"
   a.fs_left=WARNING_FISH if row.kind=="silverfish" else WARNING_EEL
   var aim := pos.direction_to(point)
   a.fs_aim=pack(Vector2.DOWN if aim.is_zero_approx() else aim)
   a.fs_origin=pack(pos)
   a.fs_hit=false
   a.mode="windup"
   a.windup=a.fs_left
  else:
   Spacing.patrol(run,row,dt)
  a.velocity=pack((vec(a.position)-pos)/dt)
  return
 a.fs_left=maxf(0.0,float(a.fs_left)-dt)
 if phase=="warning":
  a.mode="windup"
  a.windup=a.fs_left
  if a.fs_left<=0.00001:
   if row.kind=="silverfish":
    a.fs_phase="rush"
    a.fs_left=RUSH_LENGTH/RUSH_SPEED
    a.mode="chase"
   else:
    # 先将已结算阶段写入状态；恢复会续放电画面，不会再次应用伤害。
    a.fs_phase="discharge"
    a.fs_left=0.35
    a.mode="chase"
    discharge(run,row,point,int(stats.attack),skills)
 elif phase=="rush":
  a.mode="chase"
  var aim := vec(a.fs_aim)
  var destination := Water.move(pos,aim*RUSH_SPEED*dt,row.position)
  if not Spacing.line_clear(run,row.id,pos,destination): destination=pos
  a.position=pack(destination)
  a.velocity=pack((destination-pos)/dt)
  var nearest := Geometry2D.get_closest_point_to_segment(point,pos,destination)
  if not a.fs_hit and c.hp>0 and wet(point) and not Water.protected(point) and point.distance_to(nearest)<=18.0:
   c.hp=maxf(0.0,c.hp-skills.incoming_damage(run,int(stats.attack)))
   c.last_attacker=row.kind
   c.flash_remaining=0.1
   a.fs_hit=true
  if a.fs_left<=0.00001 or destination.distance_to(pos)<0.001:
   recover(a,0.9)
 elif phase=="discharge":
  if a.fs_left<=0.00001: recover(a,1.3)
 elif phase=="recover":
  a.mode="chase"
  if a.fs_left<=0.00001: a.fs_phase="idle"

static func recover(a: Dictionary, duration: float) -> void:
 complete_recovery_fields(a)
 a.fs_phase="recover"
 a.fs_left=duration
 a.mode="chase"
 a.windup=0.0

static func complete_recovery_fields(a: Dictionary) -> void:
 if not a.has("fs_origin"): a.fs_origin=a.position.duplicate()
 if not a.has("fs_aim"): a.fs_aim=[0.0,1.0]
 if not a.has("fs_hit"): a.fs_hit=false

## 只补已知旧试玩停顿态遗漏的字段；不改计时、位置、生命或错误类型。
static func restore_recovery(c: Dictionary) -> void:
 if c.get("fs01_trial")!=true or not c.get("actors") is Dictionary: return
 for id in IDS:
  var a: Variant=c.actors.get(id)
  if a is Dictionary and a.get("fs_phase")=="recover" and a.get("position") is Array:
   complete_recovery_fields(a)

static func discharge(run: Dictionary, row: Dictionary, point: Vector2, amount: int, skills: Script) -> void:
 var c: Dictionary=run.combat
 var center := vec(c.actors[row.id].position)
 if c.hp>0 and not Water.protected(point) and conducts(center,point):
  c.hp=maxf(0.0,c.hp-skills.incoming_damage(run,amount))
  c.last_attacker=row.kind
  c.flash_remaining=0.1
 for id in IDS:
  if not id.contains("silverfish") or not c.actors.has(id): continue
  var fish: Dictionary=c.actors[id]
  if run.monsters[id].status!="alive" or fish.hp<=0 or not conducts(center,vec(fish.position)): continue
  fish.hp=maxf(0.0,float(fish.hp)-amount)
  fish.flash_remaining=0.1
  # 借电只造成原有伤害和白闪，不把鱼击退到预警区外，也不触发玩家招式计数。
  fish.erase("hit_velocity")
  fish.hit_remaining=0.0
  recover(fish,0.9)

static func valid(actor: Dictionary) -> bool:
 if not actor.has("fs_phase"): return true
 if actor.fs_phase not in ["idle","warning","rush","discharge","recover"]: return false
 var left: Variant=actor.get("fs_left")
 if typeof(left) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(left)) or left<0 or left>2.0: return false
 for key in ["fs_origin","fs_aim"]:
  var value: Variant=actor.get(key)
  if not value is Array or value.size()!=2: return false
  for number in value:
   if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)): return false
 if absf(vec(actor.fs_aim).length()-1.0)>0.001: return false
 return actor.get("fs_hit") is bool
