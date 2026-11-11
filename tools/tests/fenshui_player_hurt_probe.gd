extends "res://tools/tests/fenshui_player_hurt_state.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"右侧鱼检查隔离存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 Run.begin(sm,Roads.SPAWN)
 Run.change_region(sm,"fenshui",HURT_POINT)
 original=sm.data.duplicate(true)
 for x in [1120.0,1114.0,1108.0]:
  sm.data=original.duplicate(true)
  seed_fish(false)
  var a: Dictionary=sm.data[Run.KEY].combat.actors[FISH_ID]
  a.position=[x,450.0]
  a.fish_origin=a.position.duplicate()
  a.fish_aim=[-1.0,0.0]
  var allowed: bool=Run.Combat.Silverfish.allowed(Vector2(x,450))
  var before: float=state().combat.hp
  var result:=Run.combat_tick(sm,HURT_POINT,0.1)
  trace.append({"start":x,"allowed":allowed,"hp_before":before,"after":state().combat.hp,"fish":state().combat.actors[FISH_ID],"result":result})
 _finish()
