extends RefCounted
## 正式反击的纯状态规则；无显示节点、不写盘、不依赖共享伤害模块。
const Boss=preload("res://data/maze/fenshui_boss.gd")
const AIR_TIME=0.8
const TOPPLE_TIME=0.56
const EXPOSED_TIME=3.0
const RISE_TIME=0.84

static func enabled(c: Dictionary, id: String) -> bool:
 return id==Boss.ID and c.get("region","")=="fenshui" and not c.get("fs01_trial",false)

static func vec(p: Array) -> Vector2:
 return Vector2(p[0],p[1])

static func direction_for(vector: Vector2, previous: int=0) -> int:
 var left:=previous in [1,3]
 var up:=previous in [2,3]
 if absf(vector.x)>absf(vector.y)*0.12: left=vector.x<0
 if absf(vector.y)>absf(vector.x)*0.12: up=vector.y<0
 return (1 if left else 0)+(2 if up else 0)

static func facing(a: Dictionary) -> int:
 if a.has("frog_facing"): return int(a.frog_facing)
 # 旧档只推导显示方向，不写状态、不补发攻击。
 var vector:=vec(a.frog_aim) if a.get("mode","")=="windup" else vec(a.frog_target)-vec(a.frog_origin)
 return direction_for(vector)

static func flight_time(a: Dictionary) -> float:
 # 缺字段的旧腾空检查点仍按原0.35秒续接。
 return float(a.get("frog_air_duration",0.35))

static func shielded(c: Dictionary, id: String) -> bool:
 if not enabled(c,id): return false
 var a: Dictionary=c.actors[id]
 return a.hp>0 and a.get("frog_phase","") not in ["exposed","recovering"] and float(a.get("electric_left",0.0))<=0 and float(a.get("frog_form_left",0.0))<=0 and Boss.water(vec(a.position))

static func damage_amount(c: Dictionary, id: String, amount: float) -> float:
 if not enabled(c,id): return amount
 if c.actors[id].get("frog_phase","")=="exposed": return amount*2.0
 return maxf(1.0,amount*0.25) if amount>0 and shielded(c,id) else amount

static func water_clock(a: Dictionary, dt: float) -> void:
 a.electric_left=maxf(0.0,float(a.get("electric_left",0.0))-dt)
 var wet:=Boss.water(vec(a.position))
 var previous: bool=a.get("frog_wet",wet)
 a.frog_form_left=1.0 if not wet or not previous else maxf(0.0,float(a.get("frog_form_left",0.0))-dt)
 a.frog_wet=wet

static func player_hit(c: Dictionary, id: String) -> void:
 if not enabled(c,id): return
 var a: Dictionary=c.actors[id]
 if a.hp<=0 or a.frog_phase!="airborne": return
 # 与现有正弦跳高同一时钟：最高点前后各0.10秒，窗外只结算原伤害。
 if absf(float(a.frog_left)-flight_time(a)*0.5)>0.100001: return
 a.frog_counter_from=a.position.duplicate()
 a.frog_phase="toppling"
 a.frog_left=TOPPLE_TIME
 a.mode="chase"
 a.windup=0.0

static func advance(a: Dictionary, dt: float) -> bool:
 if a.frog_phase not in ["toppling","exposed","recovering"]: return false
 a.hit_remaining=0.0
 a.velocity=[0.0,0.0]
 var remaining:=dt
 # 跨阶段仅消耗实际剩时，不丢掉余量，也不延长3秒露腹。
 while remaining>0.000001 and a.frog_phase in ["toppling","exposed","recovering"]:
  var used:=minf(remaining,float(a.frog_left))
  remaining-=used
  a.frog_left=maxf(0.0,float(a.frog_left)-used)
  if a.frog_phase=="toppling":
   var p:=vec(a.frog_counter_from).lerp(vec(a.frog_target),1.0-float(a.frog_left)/TOPPLE_TIME)
   a.position=[p.x,p.y]
  if a.frog_left>0.000001: break
  match a.frog_phase:
   "toppling":
    a.position=a.frog_target.duplicate()
    a.frog_phase="exposed"
    a.frog_left=EXPOSED_TIME
   "exposed":
    a.frog_phase="recovering"
    a.frog_left=RISE_TIME
   "recovering":
    a.frog_phase="active"
    a.frog_left=0.0
    a.frog_origin=a.position.duplicate()
    a.frog_target=a.position.duplicate()
    a.erase("frog_counter_from")
 return true

static func point(value: Variant) -> bool:
 if not value is Array or value.size()!=2: return false
 for n in value:
  if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)): return false
 return true

static func valid(a: Dictionary) -> bool:
 if a.has("frog_facing"):
  var direction: Variant=a.frog_facing
  if typeof(direction) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(direction)) or direction<0 or direction>3 or float(direction)!=floor(float(direction)): return false
 if a.has("frog_spit_left"):
  var left: Variant=a.frog_spit_left
  if typeof(left) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(left)) or left<0 or left>maxf(0.28,preload("res://scripts/maze/combat_tuning.gd").effect("water","recover",280.0)/1000.0): return false
 for key in ["electric_left","frog_form_left","frog_air_duration"]:
  if not a.has(key): continue
  var n: Variant=a[key]
  var limit:=4.0 if key=="electric_left" else (1.0 if key=="frog_form_left" else AIR_TIME)
  if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)) or n<0 or n>limit: return false
 if a.has("frog_air_duration") and not (is_equal_approx(float(a.frog_air_duration),0.35) or is_equal_approx(float(a.frog_air_duration),AIR_TIME)): return false
 if a.has("frog_wet") and not a.frog_wet is bool: return false
 if a.has("frog_counter_from") and not point(a.frog_counter_from): return false
 return true
