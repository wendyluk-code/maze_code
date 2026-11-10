extends "res://tools/previews/editor_n_play.gd"
func _run() -> void:
 await super._run()
 gate.hide()
 maze.player.input_locked=false
 Arena.ai_enabled=false
 Arena.infinite_life=true
 maze.capture_flow.window_focused=true
 await get_tree().process_frame
 for i in 100:
  Run.combat_tick(sm,maze.player.position,0.02)
 var before: Dictionary=Run.snapshot(sm)
 var point: Vector2=maze.player.position
 var result: Dictionary=Run.combat_attack(sm,point,Vector2.LEFT)
 var after: Dictionary=Run.snapshot(sm)
 var simulation: Dictionary=before.duplicate(true)
 Run.Combat.Skills.sync_levels(simulation,sm)
 var fired: bool=Run.Combat.attack(simulation,point,Vector2.LEFT)
 _check(result.success and after.combat.throws>before.combat.throws,"真实攻击提交成功并增加出招",{"result":result,"before_valid":Run.valid(before),"after_valid":Run.valid(after),"before_throws":before.combat.throws,"after_throws":after.combat.throws,"simulation_fired":fired,"simulation_valid":Run.valid(simulation),"skills_valid":Run.Combat.Skills.valid(simulation.combat),"combat_valid":Run.Combat.valid(simulation.combat),"point":Run.Combat.pack(point)})
 var flow: Node=maze.capture_flow
 var body: Sprite2D=flow.monsters[Arena.selected_id].body
 flow._flash_body(body,0.1)
 _check(body.material!=null and body.material.get_shader_parameter("flash")==true,"怪物有效受伤显示白闪")
 flow._flash_body(maze.player.body,0.1)
 _check(maze.player.body.material==null or maze.player.body.material.get_shader_parameter("flash")==false,"玩家受伤不显示白闪")
 flow.player_hurt_visual.receive({"kind":"water","point":Run.Combat.pack(point),"direction":[1.0,0.0]})
 var pose: Sprite2D=flow.player_hurt_visual.pose
 _check(pose.material!=null and pose.material.get_shader_parameter("flash")==false and pose.modulate.a==1.0,"玩家实际受击姿态不透明且不白闪")
 flow._flash_body(body,0.0)
 _check(body.material.get_shader_parameter("flash")==false,"受伤结束清除白闪")
 sm.data[Run.KEY]=before.duplicate(true)
 var controls: Node
 for child in maze.get_children():
  if child.get_script()==preload("res://tools/previews/editor_training_controls.gd"): controls=child
 Arena.ai_enabled=true
 Arena.forced_skill="water"
 for i in 900:
  controls._advance_loop()
  var state: Dictionary=Run.snapshot(sm)
  Run.Combat.advance(state,point,0.02)
  sm.data[Run.KEY]=state
 _check(controls.loop_attacks>=2,"指定水枪完成后可以循环而非重置前摇",{"count":controls.loop_attacks,"message":controls.loop_message})
 _check(Run.valid(Run.snapshot(sm)),"循环结束保持有效战斗状态")
 var attacks: int=controls.loop_attacks
 Arena.ai_enabled=false
 for i in 10: controls._advance_loop()
 _check(controls.loop_attacks==attacks,"关闭主动攻击不再起循环新招")
 Arena.forced_skill=""
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"before":before,"simulation":simulation},"  "))
 print("EDITOR_INPUT ",checks," checks; failures=",failures)
 get_tree().quit(1 if failures else 0)
