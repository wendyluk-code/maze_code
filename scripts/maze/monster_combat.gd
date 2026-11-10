extends RefCounted
## 怪物共用结算；只修改外层探索事务中的原状态，不持有节点或写盘。
const Catalog=preload("res://data/maze/capture_catalog.gd")
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const Counter=preload("res://scripts/maze/wind_frog_counter.gd")
const PlayerRules=preload("res://scripts/maze/player_combat_rules.gd")
const Hitstop=preload("res://scripts/maze/axe_hitstop.gd")
const HIT_DURATION=0.12
const FLASH_DURATION=0.1
static var STATS: Dictionary = {
 "rockmane":{"attack":8,"hp":120,"windup":0.7},
 "mimic_crab":{"attack":5,"hp":28,"interval":2.0,"windup":0.65,"speed":80.0,"trigger":100.0,"leash":145.0,"home_limit":75.0,"reach":34.0},
 "blind_scorpion":{"attack":4,"hp":22,"interval":1.8,"windup":0.6,"speed":90.0,"trigger":100.0,"leash":145.0,"home_limit":75.0,"reach":42.0},
 "wind_frog":{"attack":6,"hp":96},
 "silverfish":{"attack":4,"hp":20,"interval":1.8,"windup":0.55,"speed":65.0,"trigger":110.0,"leash":150.0,"home_limit":85.0,"reach":35.0},
 "thunder_eel":{"attack":5,"hp":30,"interval":2.2,"windup":0.8,"speed":55.0,"trigger":110.0,"leash":150.0,"home_limit":85.0,"reach":70.0},
 "slime":{"attack":3,"hp":14,"interval":1.8,"windup":0.45,"speed":85.0,"trigger":150.0,"leash":420.0,"home_limit":600.0,"reach":32.0},
 "snail":{"attack":5,"hp":28,"interval":2.0,"windup":0.6,"speed":65.0,"trigger":140.0,"leash":380.0,"home_limit":520.0,"reach":32.0},
 "beetle":{"attack":4,"hp":21,"interval":1.3,"windup":0.35,"speed":145.0,"trigger":190.0,"leash":500.0,"home_limit":750.0,"reach":32.0},
 "lizard":{"attack":8,"hp":84,"interval":2.2,"windup":0.7,"speed":100.0,"trigger":200.0,"leash":550.0,"home_limit":700.0,"reach":40.0}
}

static func fresh_actor(kind: String, point: Vector2) -> Dictionary:
 preload("res://scripts/maze/combat_tuning.gd").apply_stats(STATS)
 return {"position":_pack(point),"hp":STATS[kind].hp,"mode":"idle","windup":0.0,"cooldown":0.0,"away":0.0,"velocity":[0.0,0.0]}

## 共用资格不包含视口、射程或弹道；它们仍由调用方负责。
static func eligible(run: Dictionary, id: String) -> bool:
 var c: Dictionary=run.get("combat",{})
 if not c.get("actors",{}).has(id) or not run.get("monsters",{}).has(id): return false
 var a: Dictionary=c.actors[id]
 return Catalog.active(c,id) and run.monsters[id].get("status","")=="alive" and float(a.get("hp",0))>0.0 and a.get("mode","")!="return" and Catalog.targetable(c,id)

static func protected_slime(run: Dictionary, id: String) -> bool:
 var lesson: Dictionary=run.combat.get("slime_lesson",{})
 return id=="slime_1" and lesson.get("enabled",false) and not lesson.get("completed",false)

## 岩鬃兽仍可被锁定；只有力竭或撞障碍眩晕时接受有效命中。
static func protected_rockmane(run: Dictionary, id: String) -> bool:
 if id!=Catalog.Rock.ID: return false
 var actor: Dictionary=run.get("combat",{}).get("actors",{}).get(id,{})
 return actor.get("rock_phase","active") not in ["rest","stunned"]

## 保留原直接伤害入口：调用方已确认命中；不生成显示或局部时钟。
static func damage(run: Dictionary, id: String, amount: int=-1) -> void:
 var c: Dictionary=run.combat
 if not Catalog.targetable(c,id) or protected_rockmane(run,id): return
 var a: Dictionary=c.actors[id]
 var actual: float=Fish.damage_amount(c,id,int(c.attack) if amount<0 else amount)
 actual=Eel.damage_amount(c,id,actual)
 actual=Counter.damage_amount(c,id,actual)
 if Counter.enabled(c,id) and actual>0: a.frog_heal_quiet=0.0
 a.hp=maxf(1 if protected_slime(run,id) else 0,a.hp-actual)
 Counter.player_hit(c,id)
 # 近战沿用原标量运算顺序，避免迁移时改变已保存向量的精度。
 var direction:=_vec(c.hero).direction_to(_vec(a.position))
 if direction.is_zero_approx(): direction=Vector2.DOWN
 a.hit_velocity=[direction.x*100.0,direction.y*100.0]
 a.hit_remaining=HIT_DURATION
 a.flash_remaining=FLASH_DURATION
 if id==Catalog.Frog.ID and a.hp<=0: a.frog_shots.clear()
 c.hits+=1
 var lesson: Dictionary=c.get("slime_lesson",{})
 if lesson.get("enabled",false) and lesson.get("attack_read",false) and not lesson.get("switch_read",false):
  lesson.hits=mini(3,int(lesson.get("hits",0))+1)

## 玩家真实命中的完整入口；保护标志在伤害前取值，事件随外层事务提交。
static func impact(run: Dictionary, id: String, amount: int, weapon: String, contact: Vector2, direction: Vector2, feedback: Array, clock: Dictionary={}, source: Vector2=Vector2.INF) -> void:
 if not eligible(run,id) or protected_rockmane(run,id): return
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[id]
 var before:=float(a.hp)
 var protected:=Fish.shielded(c,id) or Eel.shielded(c,id) or Counter.shielded(c,id)
 damage(run,id,amount)
 if PlayerRules.enabled(c) and float(a.hp)<before:
  feedback.append({"id":id,"kind":weapon,"point":_pack(contact),"direction":_pack(Vector2.DOWN if direction.is_zero_approx() else direction.normalized()),"protected":protected})
 if weapon=="tieshan":
  a.mode="chase"
  # 多目标铁山由攻击方在整次挥击结束后统一触发一次70毫秒时钟。
 else:
  if a.hp>0: hit(a,_vec(a.position),_vec(c.hero) if source==Vector2.INF else source,12.0)
  else: clear_hit(a)
  if a.mode=="idle": a.mode="chase"
  if weapon in ["hero","yaya"]: Hitstop.trigger_ranged(clock,id,weapon)

## 兼容原Combat受击字段工具；玩家旧入口同样转发，不改变其规则。
static func hit(actor: Dictionary, position: Vector2, source: Vector2, distance: float) -> void:
 var direction:=source.direction_to(position)
 if direction.is_zero_approx(): direction=Vector2.DOWN
 actor.hit_velocity=_pack(direction*distance/HIT_DURATION)
 actor.hit_remaining=HIT_DURATION
 actor.flash_remaining=FLASH_DURATION

static func clear_hit(actor: Dictionary) -> void:
 actor.erase("hit_remaining")
 actor.erase("hit_velocity")
 actor.erase("flash_remaining")

static func valid_hit(actor: Dictionary) -> bool:
 for key in ["hit_remaining","flash_remaining"]:
  if actor.has(key):
   var value: Variant=actor[key]
   if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0.0 or value>HIT_DURATION: return false
 if actor.has("hit_velocity"):
  var p: Variant=actor.hit_velocity
  if not p is Array or p.size()!=2: return false
  for value in p:
   if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
  if _vec(p).length()>150.001: return false
 if float(actor.get("flash_remaining",0.0))>FLASH_DURATION: return false
 return float(actor.get("hit_remaining",0.0))<=0.0 or actor.has("hit_velocity")

static func _vec(p: Array) -> Vector2:
 return Vector2(p[0],p[1])

static func _pack(p: Vector2) -> Array:
 return [p.x,p.y]
