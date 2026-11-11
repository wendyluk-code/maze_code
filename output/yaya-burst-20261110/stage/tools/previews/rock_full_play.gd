extends "res://tools/previews/editor_n_play.gd"
## 统一编辑器候选；情境仅重设隔离起点，后续由真实战斗推进。
var tick:=0
var command_id:=-1
var scenario:="natural"
var last_error:=""
func get_viewport_rect() -> Rect2:
 return get_viewport().get_visible_rect()
func _process(dt: float) -> void:
 super._process(dt)
 if not OS.has_feature("web") or not is_instance_valid(maze) or not maze._entry_ready or not is_instance_valid(gate) or Arena.selected_kind!="rockmane": return
 tick+=1
 var command: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.rockScenarioCommand || null)",true)))
 if command is Dictionary and int(command.get("id",-1))!=command_id:
  command_id=int(command.id)
  _scenario(str(command.get("scenario","near")),str(command.get("direction","right")))
 var run: Dictionary=Run.snapshot(sm)
 var c: Dictionary=run.combat
 var flow: Node=maze.capture_flow
 var beast: Node=flow.monsters.get(Arena.selected_id)
 if not is_instance_valid(beast): return
 var visual: Node=flow.rock_status_visual
 var rect: Rect2=beast.label.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,beast.label.size)
 var s:={"tick":tick,"ack":command_id,"scenario":scenario,"error":last_error,"phase":c.actors[Arena.selected_id].rock_phase,"left":c.actors[Arena.selected_id].rock_left,"chain_left":c.actors[Arena.selected_id].get("rock_chain_left",0),"slow_left":c.get("rock_slow_left",0),"slow_factor":Run.Combat.Rock.slow_factor(c),"stun_left":c.get("rock_stun_left",0),"elapsed":c.elapsed,"frame":beast.frame_index(),"facing":beast.facing,"action":beast.action,"body_scale":[beast.body.scale.x,beast.body.scale.y],"body_alpha":beast.body.self_modulate.a,"pose_blend":beast.rock_lunge_pose.get("blend",0),"label_screen":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"status_visible":visual.is_visible_in_tree(),"player_stars":visual.player_stunned,"beast_stars":visual.beast_stunned,"exhausted":visual.exhausted,"rocks":visual.slow_count,"hit_received":beast.hit_visual.received,"hits":c.hits,"hp":c.hp,"beast_hp":c.actors[Arena.selected_id].hp,"hero":c.hero,"beast":c.actors[Arena.selected_id].position,"aim":c.actors[Arena.selected_id].rock_aim,"movement_factor":flow.rock_movement_factor(),"viewport":[get_viewport_rect().size.x,get_viewport_rect().size.y]}
 var hero_label: Rect2=flow.power_label.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,flow.power_label.size)
 s["hero_label_screen"]=[hero_label.position.x,hero_label.position.y,hero_label.size.x,hero_label.size.y]
 s["slow_visual"]={"binding":visual.slow_left>0.0,"left":visual.slow_left,"badge":visual.slow_badge,"release":visual.slow_release,"trails":visual.trails.size(),"clock":visual.clock}
 s["launch_left"]=c.get("rock_launch_left",0.0)
 s["launch_guard"]=c.get("rock_launch_guard",0.0)
 s["lift"]=flow.player_hurt_visual.rock_lift
 s["recovery"]=c.get("hurt_recovery_left",0.0)
 s["in_water"]=not preload("res://data/maze/salt_pool_roads.gd").is_walkable(Run.Combat.vec(c.hero))
 s["dust_visible"]=beast.roar_visual.phase=="lunge_charge"
 s["wave_visible"]=beast.roar_visual.phase=="rush" and beast.roar_visual.shape.size()>2
 s["attack_fx"]=beast.roar_visual.snapshot()
 s["camera_fx"]={"left":maze.camera.roar_visual_left,"duration":maze.camera.ROAR_SWAY_DURATION,"age":maze.camera.roar_visual_age,"offset":[maze.camera.offset.x,maze.camera.offset.y]}
 s["entry_mix"]=beast.rock_lunge_pose.get("entry_mix",1.0)
 s["entry_action"]=beast.rock_lunge_pose.get("entry",{}).get("action","")
 s["entry_frame"]=beast.rock_lunge_pose.get("entry",{}).get("frame",-1)
 s["distance"]=c.actors[Arena.selected_id].get("rock_distance",0.0)
 s["atlas_source"]=beast.body.texture.resource_path
 s["atlas_cell"]=[beast.body.region_rect.position.x,beast.body.region_rect.position.y,beast.body.region_rect.size.x,beast.body.region_rect.size.y]
 s["next_action"]=beast.rock_lunge_pose.get("next_action",beast.action)
 s["lunge_limit"]=Run.Combat.Rock.LUNGE_DISTANCE
 s["exhaustion_stars"]=visual.exhausted and visual.is_visible_in_tree()
 s["stars_world"]=visual.to_global(visual.beast_head)
 s["lock"]=flow.locked_target_id
 s["lock_eligible"]=preload("res://scripts/maze/monster_combat.gd").eligible(run,Arena.selected_id)
 s["lock_in_view"]=flow.visible_world_rect().has_point(Run.Combat.vec(c.actors[Arena.selected_id].position))
 s["combo"]=c.actors[Arena.selected_id].get("rock_combo",false)
 s["charge_duration"]=Run.Combat.Rock.charge_duration(c.actors[Arena.selected_id])
 s["recover_duration"]=Run.Combat.Rock.recover_duration(c.actors[Arena.selected_id])
 s["last_message"]=maze.last_message
 s["save_retry"]=flow.save_retry_delay
 s["lock_release_observations"]=flow.player_combat.lock_release_observations
 s["lock_marker_visible"]=flow.target_marker.is_visible_in_tree()
 JavaScriptBridge.eval("window.parent.rockFullStatus="+JSON.stringify(s),true)

func _scenario(kind: String, direction: String = "right") -> void:
 scenario=kind
 last_error=""
 var run: Dictionary=Run.snapshot(sm).duplicate(true)
 var c: Dictionary=run.combat
 var actor: Dictionary=c.actors[Arena.selected_id]
 var origin:=Vector2.INF
 var aim: Vector2={"right":Vector2.RIGHT,"left":Vector2.LEFT,"up":Vector2.UP,"down":Vector2.DOWN,"right_down":Vector2(1,1).normalized(),"left_down":Vector2(-1,1).normalized(),"right_up":Vector2(1,-1).normalized(),"left_up":Vector2(-1,-1).normalized()}.get(direction,Vector2.RIGHT)
 var distance: float={"near":50.0,"middle":130.0,"far":230.0,"miss":130.0,"chain":230.0,"body":60.0,"open":80.0,"wall":80.0,"edge":80.0,"chain_open":80.0}.get(kind,50.0)
 # 为距离对照选择真实无遮挡地段，保持地图碰撞，不伪造空场。
 for y in range(140,850,30):
  for x in range(140,1350,30):
   var p:=Vector2(x,y)
   if Run.Combat.Rock.Config.allowed(p) and sm.maze_terrain("salt_pool").is_walkable(p+aim*distance) and Run.Combat.Rock.roar_clear(p,p+aim*distance):
    origin=p
    break
  if origin!=Vector2.INF: break
 if kind in ["open","wall","edge","chain_open"]:
  var spots: Dictionary=preload("res://tools/previews/rock_pacing_cases.gd").find("open" if kind=="chain_open" else kind)
  origin=spots.get("beast",Vector2.INF)
  aim=Vector2.RIGHT
 if kind=="water":
  origin=Vector2(980,190)
  distance=80.0
  aim=Vector2.RIGHT
 if kind=="roar_chain":
  origin=Vector2(800,425)
  distance=100.0
  aim=Vector2.RIGHT
 var impact_cases:={"impact_early":[Vector2(506,308),PI/4.0],"impact_front":[Vector2(494,260),3.0*PI/8.0],"impact_graze":[Vector2(506,260),3.0*PI/8.0],"impact_late":[Vector2(626,260),3.0*PI/4.0],"impact_open":[Vector2(800,425),0.0],"impact_route":[Vector2(506,308),PI/4.0]}
 if impact_cases.has(kind):
  origin=impact_cases[kind][0]
  aim=Vector2.RIGHT.rotated(impact_cases[kind][1])
 if origin==Vector2.INF:
  last_error="未找到合法距离站位，未修改训练状态"
  return
 var point:=origin+aim*distance
 if impact_cases.has(kind): point=origin+aim*8.0 if kind=="impact_route" else Vector2(700,425)
 actor.position=Run.Combat.pack(origin)
 actor.hp=Run.Combat.STATS.rockmane.hp
 actor.mode="chase"
 actor.velocity=[0.0,0.0]
 actor.hit_remaining=0.0
 actor.flash_remaining=0.0
 actor.rock_phase="charge"
 actor.rock_left=Run.Combat.Rock.Tuning.number("rock.roar","charge",1.1)
 actor.rock_reuse=Run.Combat.Rock.Tuning.number("rock.roar","reuse",12.0)
 actor.rock_combo=false
 actor.rock_chain_left=0
 actor.rock_distance=0.0
 actor.rock_hit=false
 actor.rock_aim=Run.Combat.pack(-aim if kind=="miss" else aim)
 if kind=="chain":
  Run.Combat.Rock.start_combo(actor,point)
 if kind in ["open","wall","edge","chain_open","water"]:
  actor.rock_phase="active"
  actor.rock_left=0.0
  if kind=="chain_open":
   Run.Combat.Rock.start_combo(actor,point)
 if kind=="body":
  actor.rock_phase="rest"
  actor.rock_left=1.5
 if impact_cases.has(kind):
  actor.rock_phase="active" if kind=="impact_route" else "lunge"
  actor.rock_left=0.0 if kind=="impact_route" else Run.Combat.Rock.LUNGE_DURATIONS.lunge
  actor.rock_aim=Run.Combat.pack(aim)
  actor.rock_combo=kind!="impact_route"
  actor.rock_chain_left=4 if actor.rock_combo else 0
 c.hp=c.max_hp
 c.hero=Run.Combat.pack(point)
 c.hurt_recovery_left=0.0
 c.rock_stun_left=0.0
 c.rock_slow_left=0.0
 c.rock_slow_factor=1.0
 c.rock_launch_left=0.0
 c.rock_launch_guard=0.0
 c.rock_launch_velocity=[0.0,0.0]
 c.hit_remaining=0.0
 c.action=""
 c.action_left=0.0
 c.axe_pending=false
 c.shots=[]
 c.enemy_shots=[]
 c.cooldown=0.0
 c.hits=0
 if not Run.valid(run):
  last_error="情境状态校验失败，未修改训练状态"
  return
 sm.data[Run.KEY]=run
 maze.player.position=point
 maze.capture_flow.monsters[Arena.selected_id].position=origin
 maze.capture_flow.player_hurt_visual.clear()
 maze.capture_flow.monsters[Arena.selected_id].hit_visual.clear()
 maze.player.input_locked=false
 get_tree().paused=false
 gate.hide()
