extends "res://tools/tests/fenshui_player_hurt_state.gd"
const FrogCombat=preload("res://scripts/maze/wind_frog_combat.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"落地边界诊断使用隔离档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",HURT_POINT).success,"沿原事务建立落地检查点")
 original=sm.data.duplicate(true)
 var observations: Array=[]
 for distance in [0.0,64.0,65.0,66.0,100.0,124.0,125.0,126.0,135.0]:
  sm.data=original.duplicate(true)
  seed_attack("slam",false)
  var point:=Vector2(1040+distance,450)
  var hp: float=state().combat.hp
  var fish_hp: float=state().combat.actors[FISH_ID].hp
  var clear: bool=Boss.line(Vector2(1040,450),point)
  var result:=Run.combat_tick(sm,point,0.1)
  var hit: bool=state().combat.hp<hp
  var detail: Dictionary={"distance":distance,"line_clear":clear,"hit":hit,"hp_before":hp,"hp_after":state().combat.hp,"fish_hp_before":fish_hp,"fish_hp_after":state().combat.actors[FISH_ID].hp}
  observations.append(detail)
  _check(result.success and hit==(distance<=65.0 and clear),"原落地伤害边界实测："+str(distance),detail)
  _check(state().combat.actors[FISH_ID].hp==fish_hp,"当前落地尚未波及同图鱼，不能冒充范围攻击已完整接入",detail)
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"observations":observations,"frog_radius":FrogCombat.SLAM_RADIUS,"eel_radius":preload("res://scripts/maze/fenshui_electric_area.gd").RADIUS},"  "))
 get_tree().quit(1 if failures else 0)
