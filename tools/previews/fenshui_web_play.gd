extends "res://tools/previews/fenshui_unified_play.gd"
var _web_clock:=0.0

func _verify_isolation() -> bool:
 return OS.has_feature("web") and ProjectSettings.get_setting("application/config/name")=="maze_fenshui_lan"

func _process(dt: float) -> void:
 if not OS.has_feature("web"): return
 _web_clock+=dt
 if _web_clock<0.1: return
 _web_clock=0.0
 if not is_instance_valid(maze) or not maze._entry_ready: return
 var run: Dictionary=Run.snapshot(sm)
 if not run.has("combat"): return
 var c: Dictionary=run.combat
 var status:={"ready":true,"gate":is_instance_valid(gate) and gate.visible,"hero":[maze.player.position.x,maze.player.position.y],"hp":c.hp,"max_hp":c.max_hp,"monsters":maze.capture_flow.monsters.size(),"time":c.elapsed,"hits":c.hits,"lock":maze.capture_flow.locked_target_id,"frog":c.actors.get("fenshui_wind_frog_1",{}),"paused":get_tree().paused}
 var visual: Node=maze.capture_flow.player_hurt_visual
 status.hurt_recovery_left=float(c.get("hurt_recovery_left",0.0))
 status.throws=int(c.get("throws",0))
 status.action=str(c.get("action",""))
 status.version="20261106-G-hurt600-slam900"
 status.eels={}
 for id in c.actors:
  if not str(id).begins_with("fenshui_thunder_eel_"): continue
  var monster: Node=maze.capture_flow.monsters.get(id)
  if not is_instance_valid(monster): continue
  status.eels[id]={"actor":c.actors[id],"shielded":Run.Combat.ThunderEel.shielded(c,id),"bubble_visible":monster.membrane.visible,"body_scale":[monster.body.scale.x,monster.body.scale.y],"fx_visible":monster.exhaustion_visual.visible}
 if is_instance_valid(gate) and gate.visible:
  var button: Button=gate.get("confirm_button")
  if is_instance_valid(button):
   var rect:=button.get_global_rect()
   status.start_button=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
   var size:=get_viewport().get_visible_rect().size
   status.viewport=[size.x,size.y]
 var water: Node=maze.get_node_or_null("FenshuiWaterVisual")
 if is_instance_valid(water):
  status.water={"enabled":water.enabled,"depth":water.depth,"clock":water.clock,"reflection":is_instance_valid(water.reflection) and water.reflection.visible}
 if is_instance_valid(visual):
  status.player_hurt={"received":visual.received,"kind":visual.kind,"active":visual.active(),"pose_frame":visual.pose_frame,"effect_frame":visual.effect_frame}
 JavaScriptBridge.eval("window.fenshuiStatus="+JSON.stringify(status),true)
