extends "res://tools/previews/editor_n_play.gd"
func _run() -> void:
 await super._run()
 gate.hide()
 maze.player.input_locked=false
 Arena.ai_enabled=true
 Arena.infinite_life=true
 MonsterParameters.values[Arena.selected_kind]=20
 MonsterParameters.initialized=true
 maze.capture_flow.window_focused=true
 var controls: Node
 for child in maze.get_children():
  if child.get_script()==preload("res://tools/previews/editor_training_controls.gd"): controls=child
 Arena.forced_skill={"rockmane":"lunge","wind_frog":"water","thunder_eel":"electric","silverfish":"rush"}.get(Arena.selected_kind,"melee")
 var valid:=true
 var damaged:=false
 for i in 2500:
  controls._advance_loop()
  var state: Dictionary=Run.snapshot(sm)
  Run.Combat.advance(state,maze.player.position,0.02)
  damaged=damaged or float(state.combat.hp)<float(state.combat.max_hp)
  if not Run.valid(state):
   valid=false
   break
  sm.data[Run.KEY]=state
  maze.player.position=Run.Combat.vec(state.combat.hero)
  if controls.loop_attacks>=3: break
 _check(valid,"所选招式循环保持有效状态")
 _check(controls.loop_attacks>=3,"所选招式可连续起招三次",{"kind":Arena.selected_kind,"count":controls.loop_attacks,"message":controls.loop_message,"actor":Run.snapshot(sm).combat.actors[Arena.selected_id]})
 _check(damaged,"正常近距训练确实命中玩家")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)
