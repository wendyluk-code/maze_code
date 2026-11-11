extends "res://tools/previews/editor_n_play.gd"
## 仅隔离编辑器的取证桥：正常体验只读；显式测试页才允许受控显示。
var review_tick:=0
var probe_id:=-1
var probe_mode:=false
func _process(dt: float) -> void:
 super._process(dt)
 if not OS.has_feature("web") or not is_instance_valid(maze) or not maze._entry_ready or not is_instance_valid(gate): return
 if Arena.selected_kind!="rockmane": return
 var flow: Node=maze.capture_flow
 var beast: Node2D=flow.monsters.get(Arena.selected_id)
 if not is_instance_valid(beast): return
 review_tick+=1
 var probe: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.rockVisualProbe || null)",true)))
 if probe is Dictionary and int(probe.get("id",-1))!=probe_id:
  probe_id=int(probe.id)
  probe_mode=true
  gate.hide()
  maze.process_mode=Node.PROCESS_MODE_DISABLED
  var snapshot: Dictionary=Run.snapshot(sm).duplicate(true)
  var actor: Dictionary=snapshot.combat.actors[Arena.selected_id]
  var directions: Array=[Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]
  var facing: Vector2=directions[int(probe.get("row",0))]
  actor.rock_aim=[facing.x,facing.y]
  actor.rock_phase=str(probe.get("phase","lunge"))
  actor.rock_left=float(preload("res://scripts/maze/rockmane_combat.gd").LUNGE_DURATIONS[actor.rock_phase])*(1.0-float(probe.get("progress",0.4)))
  actor.velocity=[0.0,0.0]
  maze.player.position=beast.position+Vector2(float(probe.get("dx",0)),float(probe.get("dy",12)))
  beast.sync_action(actor,snapshot.combat)
  beast.label.show()
  flow.power_label.show()
  flow._layout_combat_labels()
  if probe.has("hit"):
   beast.hit_visual.clear()
   beast.hit_visual.receive({"kind":str(probe.hit),"point":[beast.position.x,beast.position.y],"direction":[facing.x,facing.y],"protected":false})
   beast.hit_visual.advance(0.04)
  if is_instance_valid(flow.target_marker): flow.target_marker.sync(flow,0.0)
 var info:={"tick":review_tick,"probe":probe_mode,"ack":probe_id,"body_scale":[beast.body.scale.x,beast.body.scale.y],"offset":[beast.body.offset.x,beast.body.offset.y],"frame":beast.frame_index(),"row":beast.facing,"action":beast.action,"hero_y":maze.player.global_position.y,"beast_y":beast.global_position.y,"hero_index":maze.player.get_index(),"beast_index":beast.get_index(),"hero_label":_rect(flow.power_label),"beast_label":_rect(beast.label),"labels_visible":flow.power_label.is_visible_in_tree() and beast.label.is_visible_in_tree(),"label_layers":[flow.power_label.z_index,beast.label.z_index],"hit_received":beast.hit_visual.received,"effects":beast.hit_visual.effects,"hit_ratio":beast.hit_visual.ratio,"hit_widths":beast.hit_visual.WIDTHS}
 info["body_alpha"]=beast.body.self_modulate.a
 var label_screen: Rect2=beast.label.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,beast.label.size)
 info["label_screen"]=[label_screen.position.x,label_screen.position.y,label_screen.size.x,label_screen.size.y]
 info["hit_alpha"]=beast.hit_visual.modulate.a
 info["shadow_alpha"]=beast.shadow.modulate.a
 info["label_alpha"]=beast.label.modulate.a
 var body_rect: Rect2=beast.body.get_global_transform_with_canvas()*beast.body.get_rect()
 info["body_canvas_rect"]=[body_rect.position.x,body_rect.position.y,body_rect.size.x,body_rect.size.y]
 JavaScriptBridge.eval("window.parent.rockVisualStatus="+JSON.stringify(info),true)
func _rect(control: Control) -> Array:
 var rect:=control.get_global_rect()
 return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
