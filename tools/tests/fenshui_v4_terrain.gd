extends "res://tools/tests/ch2_entry_state.gd"
## v4地形公开入口检查；保持隔离存档。
const FS=preload("res://data/maze/fenshui_roads.gd")
const Boss=preload("res://data/maze/fenshui_boss.gd")
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
const Combat=preload("res://scripts/maze/combat_simulation.gd")
const POINTS={"A":Vector2(650,245),"B1":Vector2(544,381),"B2":Vector2(560,481),"C":Vector2(1000,337),"D":Vector2(1138,528),"E1":Vector2(948,670),"E2":Vector2(1132,717)}

func _run() -> void:
 sm=get_node("/root/SaveManager")
 _check(_verify_isolation(),"v4前置测试使用隔离环境")
 for id in POINTS:
  var point: Vector2=POINTS[id]
  _check(FS.is_walkable(point,FS.FOOT_RADIUS),"七台中心允许玩家站立："+id)
  _check(FS.terrain_multiplier(point)==1.0 and Fish.dry(point),"七台完整身体站立面为干地："+id)
  _check(Combat.projectile_clear(point,"fenshui"),"可站面不把攻击目标当空中岩墙："+id)
  _check(not Boss.allowed(point),"巨蛙起落仍不登台："+id)
  _check(not Boss.air_allowed(point),"脚底放行不能误放巨蛙空中过岛："+id)
  var island: Vector4
  for candidate in FS.ISLANDS:
   if Vector2(candidate.x,candidate.y)==point: island=candidate
  for side in 8:
   var direction:=Vector2.RIGHT.rotated(side*TAU/8.0)
   var rim:=point+direction*Vector2(island.z,island.w)*1.15
   var target:=FS.move_on_road(rim,point-rim)
   _check(target.distance_to(point)<0.01,"八向直接登台不中断："+id+"/"+str(side),{"from":str(rim),"actual":str(target)})
  _check(not preload("res://data/maze/fenshui_encounters.gd").water(point,0.0),"石台不同时被判成浅水："+id)
 for point in [Vector2(1184,248),Vector2(379,329),Vector2(1355,484),Vector2(1373,326),Vector2(1443,378)]:
  _check(not FS.is_walkable(point) and not Combat.projectile_clear(point,"fenshui"),"五块高岛脚底与弹道继续阻挡："+str(point))
 for gate in preload("res://data/maze/fenshui_gates.gd").GATES:
  var center: Vector2=(gate.a+gate.b)*0.5
  _check(not FS.is_walkable(center) and not Combat.projectile_clear(center,"fenshui"),"原封路栅栏继续阻挡："+gate.name)
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"scope":"仅前置红灯，不是v4接入或组合验收"},"  "))
 get_tree().quit(1 if failures else 0)
