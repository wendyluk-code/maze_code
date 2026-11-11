extends Node
## 角色持有的共用战斗协调模块；真实战斗状态仍由探索事务管理。
const Run=preload("res://scripts/maze/capture_run.gd")
const Rules=preload("res://scripts/maze/player_combat_rules.gd")
const AutoAim=preload("res://scripts/maze/auto_aim.gd")
const Monster=preload("res://scripts/maze/monster_combat.gd")
var flow: Node
var locked_target_id:=""

func enabled() -> bool:
 return is_instance_valid(flow) and flow.sparring()==null and Rules.enabled(flow.display_run().get("combat",{}))

func install(owner_flow: Node) -> void:
 flow=owner_flow
 if enabled():
  flow.axe_hitstop=preload("res://scripts/maze/axe_hitstop.gd").new()
  var parameters=preload("res://scripts/maze/player_editor.gd")
  flow.axe_hitstop.configure(parameters.hitstop("tieshan"))
  flow.axe_hitstop.configure_ranged(parameters.hitstop("hero"))
  flow.axe_hitstop.configure_ranged_kind("hero",parameters.hitstop("hero"))
  flow.axe_hitstop.configure_ranged_kind("yaya",parameters.hitstop("yaya"))
 flow.skill_visual=preload("res://scripts/maze/team_attack_visual.gd").new()
 flow.skill_visual.flow=flow
 flow.maze.add_child(flow.skill_visual)
 if enabled():
  flow.player_hurt_visual=preload("res://scripts/maze/player_hurt_visual.gd").new()
  flow.player_hurt_visual.flow=flow
  get_parent().add_child(flow.player_hurt_visual)
  flow.player_hurt_visual.enable_refined_pose()
  flow.target_marker=preload("res://scripts/maze/target_lock_marker.gd").new()
  flow.maze.add_child(flow.target_marker)

func candidates(run: Dictionary) -> Array[String]:
 var result: Array[String]=[]
 var c: Dictionary=run.get("combat",{})
 if not enabled() or not run.get("active",false) or float(c.get("hp",0))<=0: return result
 var visible_rect: Rect2=flow.visible_world_rect()
 for row in Run.Catalog.rows(c):
  var id: String=row.id
  if not flow.monsters.has(id) or not c.actors.has(id) or not run.monsters.has(id): continue
  var actor: Dictionary=c.actors[id]
  if not Monster.eligible(run,id): continue
  if visible_rect.has_point(Run.Combat.vec(actor.position)): result.append(id)
 return result

func sync(run: Dictionary) -> void:
 if not locked_target_id.is_empty() and not candidates(run).has(locked_target_id): locked_target_id=""

func cycle() -> void:
 var run: Dictionary=flow.display_run()
 var ids:=candidates(run)
 if ids.is_empty():
  locked_target_id=""
  return
 var index:=ids.find(locked_target_id)
 if index>=0:
  locked_target_id=ids[(index+1)%ids.size()]
  return
 var distance:=INF
 for id in ids:
  var next: float=flow.maze.player.position.distance_squared_to(Run.Combat.vec(run.combat.actors[id].position))
  if next<distance:
   locked_target_id=id
   distance=next

func handle_input(event: InputEvent) -> bool:
 if not is_instance_valid(flow) or flow.combat_paused(): return false
 if event is InputEventKey and event.pressed and not event.echo:
  if enabled() and event.keycode in [KEY_TAB,KEY_Q]:
   if event.keycode==KEY_TAB: cycle()
   else: locked_target_id=""
   if is_instance_valid(flow.target_marker): flow.target_marker.sync(flow,0.0)
   return true
  var slot:=-1
  if event.keycode==KEY_SPACE: slot=0
  elif event.keycode>=KEY_1 and event.keycode<=KEY_4: slot=int(event.keycode-KEY_1)+1
  elif event.keycode==KEY_TAB:
   var run: Dictionary=flow.display_run()
   for offset in range(1,6):
    var next: int=(int(run.combat.get("selected",0))+offset)%5
    if not Run.Combat.Skills.kind(run,next).is_empty():
     slot=next
     break
  if slot>=0:
   var previous_slot: int=int(flow.display_run().combat.get("selected",0))
   flow._select_skill(slot)
   if int(flow.display_run().combat.get("selected",0))!=previous_slot:
    GameAudio.play_cue(&"interact")
   return true
  return false
 if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT: return false
 var run: Dictionary=flow.display_run()
 sync(run)
 var player: Node2D=flow.maze.player
 var aim: Vector2=player.position.direction_to(Run.Combat.vec(run.combat.actors[locked_target_id].position)) if not locked_target_id.is_empty() else AutoAim.direction(run,player.position,player.facing,flow.sparring()!=null)
 if Run.Combat.Skills.kind(run,int(run.combat.get("selected",0))) in ["xiluomei","lanjiao"]:
  var mouse_world: Vector2=player.get_viewport().get_canvas_transform().affine_inverse()*event.position
  aim=player.position.direction_to(mouse_world)
 if seed_aim_enabled(): aim=seed_direction(player)
 if aim.is_zero_approx(): aim=player.facing
 if flow.sparring()!=null: flow.sparring().attack(aim)
 else:
  var result: Dictionary=Run.combat_attack(SaveManager,player.position,aim)
  if result.success and result.get("fired",false):
   GameAudio.play_attack(event.get_instance_id())
  if not result.success:
   flow.save_retry_delay=1.0
   flow.maze.show_toast("攻击保存失败，已恢复上次进度，请检查存档后重试")
 return true

func seed_aim_enabled() -> bool:
 if not enabled(): return false
 var run: Dictionary=flow.display_run()
 return Run.Combat.Skills.kind(run,int(run.get("combat",{}).get("selected",0)))=="yaya"

func seed_direction(player: Node2D) -> Vector2:
 var run: Dictionary=flow.display_run()
 if not locked_target_id.is_empty() and run.get("combat",{}).get("actors",{}).has(locked_target_id):
  var locked_aim: Vector2=player.position.direction_to(Run.Combat.vec(run.combat.actors[locked_target_id].position))
  if not locked_aim.is_zero_approx(): return locked_aim
 if not player.get_viewport_rect().has_point(player.get_viewport().get_mouse_position()): return player.facing
 var aim: Vector2=player.global_position.direction_to(player.get_global_mouse_position())
 return player.facing if aim.is_zero_approx() else aim

func _exit_tree() -> void:
 locked_target_id=""
 if not is_instance_valid(flow): return
 for visual in [flow.skill_visual,flow.target_marker]:
  if is_instance_valid(visual): visual.queue_free()
