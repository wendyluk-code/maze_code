extends "res://tools/tests/fenshui_body_state.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"雷鳗新占位岸行对照隔离用户存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"建立真实探索")
 _check(Run.change_region(sm,"fenshui",Vector2(438,395)).success,"进入原合法岸边")
 baseline=sm.data.duplicate(true)
 for x in [438.0,464.0]:
  sm.data=baseline.duplicate(true)
  var run:=state()
  var id:="fenshui_thunder_eel_1"
  var original: Array=run.combat.actors[id].position.duplicate()
  run.combat.actors[id].position=run.combat.actors["fenshui_silverfish_4"].position.duplicate()
  run.combat.actors["fenshui_silverfish_4"].position=original
  sm.data[Run.KEY]=run
  var reached:=false
  var phases: Array=[]
  var success:=true
  for i in 100:
   if not Run.combat_tick(sm,Vector2(x,395),0.05,Rect2(0,0,1715,917)).success:
    success=false
    break
   var a: Dictionary=state().combat.actors[id]
   if phases.is_empty() or phases.back().phase!=a.eel_phase: phases.append({"phase":a.eel_phase,"position":a.position})
   reached=reached or a.eel_phase=="stranded"
  trace.append({"hero_x":x,"reached_shore":reached,"phases":phases,"transaction_success":success})
  _check(success,"岸边单变量位置对照事务合法："+str(x))
  if x==438.0: _check(not reached,"站得过近被新脚底阻挡，不穿入玩家完成上岸")
  if x==464.0: _check(reached,"玩家在原岸路留出脚底间距后，雷鳗按原55像素限制完整上岸",{"phases":phases})
 _finish()
