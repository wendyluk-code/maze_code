extends SceneTree
const Monster=preload("res://scripts/maze/monster_combat.gd")
const Rock=preload("res://scripts/maze/rockmane_combat.gd")
const Frog=preload("res://scripts/maze/wind_frog_combat.gd")
const Parameters=preload("res://scripts/maze/monster_editor.gd")

func _initialize() -> void:
 if Parameters.attack("silverfish",4)!=17 or Parameters.attack("thunder_eel",5)!=5:
  printerr("银鳞鱼攻击参数未读取或污染电鳗")
  quit(1)
  return
 var run:={"members":[],"bento":{},"combat":{"hp":100.0,"region":"salt_pool","actors":{},"action":"","action_left":0.0,"axe_pending":false}}
 Rock.hurt(run,Vector2.ZERO,Vector2.LEFT)
 if not is_equal_approx(float(run.combat.hp),88.0):
  printerr("岩鬃兽实际受击未读取12点攻击：",run.combat.hp)
  quit(1)
  return
 run.combat.region="fenshui"
 run.combat.hp=100.0
 Frog.hurt(run,Vector2.ZERO,Vector2.LEFT)
 if not is_equal_approx(float(run.combat.hp),91.0):
  printerr("巨蛙实际受击未读取9点攻击：",run.combat.hp)
  quit(1)
  return
 print("MONSTER_SETTINGS_REAL_HURT silverfish=17 eel=5 rock=12 frog=9")
 quit(0)
