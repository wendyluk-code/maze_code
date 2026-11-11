extends SceneTree
const Bodies=preload("res://scripts/maze/fenshui_bodies.gd")
const SaltBodies=preload("res://scripts/maze/rock_bodies.gd")
var failures:=0
func check(value: bool,label: String) -> void:
 print(label,": ",value)
 if not value: failures+=1
func _initialize() -> void:
 for pair in [["maze_entry","slime_1","snail_1"],["fenshui","fenshui_silverfish_1","fenshui_thunder_eel_1"],["salt_pool","salt_pool_mimic_crab_1","salt_pool_blind_scorpion_1"]]:
  var c={"region":pair[0],"hp":36,"hero":[-100,0],"actors":{pair[1]:{"hp":10,"position":[0,0]},pair[2]:{"hp":10,"position":[30,0]}}}
  var run={"combat":c,"monsters":{pair[1]:{"status":"alive"},pair[2]:{"status":"alive"}}}
  check(not Bodies.step(run,pair[1],Vector2.ZERO,Vector2(25,0)),str(pair[0])+"怪物间不可重叠")
  check(not Bodies.step(run,"hero",Vector2(60,0),Vector2(32,0)),str(pair[0])+"玩家不可穿怪")
  check(not Bodies.step(run,pair[1],Vector2.ZERO,Vector2(65,0)),str(pair[0])+"大步长不可穿透")
  check(Bodies.step(run,pair[1],Vector2(25,0),Vector2(24,0)),str(pair[0])+"初始重叠允许退出")
  if pair[0]=="salt_pool": check(not SaltBodies.step(run,pair[1],Vector2.ZERO,Vector2(25,0)),"盐池普通怪调用接通")
 check(not Bodies.separates(Vector2(0,0),Vector2(60,0),Vector2(30,0),Vector2(10,7)),"线段穿越测试")
 check(not Bodies.separates(Vector2(25,0),Vector2(65,0),Vector2(30,0),Vector2(10,7)),"重叠恢复也不能穿过身体中心")
 print("BODY_FAILURES=",failures)
 quit(1 if failures else 0)

