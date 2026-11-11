extends Node2D
## 仅安装在隔离编辑器。按钮重设真实状态起点，后续仍由原战斗消费者推进。
const Run=preload("res://scripts/maze/capture_run.gd")
const Arena=preload("res://tools/previews/editor_n_arena.gd")
var play: Node
var clock:=0.0
var ack:=0
var error:=""
var last_command:=""
var bounds: Array[Dictionary]=[]
var settings_revision:=""
var generation:=0
var loop_attacks:=0
var loop_message:=""
var loop_next:=0.0
var loop_key:=""
var loop_last_clock:=0.0

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 z_index=99
 if OS.has_feature("web"): generation=int(str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('generation') || '0'",true)))

func _process(dt: float) -> void:
 if not is_instance_valid(play.maze) or not play.maze._entry_ready: return
 if OS.has_feature("web"):
  if int(JavaScriptBridge.eval("window.parent.editorGeneration || 0",true))!=generation: return
  var raw: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.editorTraining || {})",true)))
  if raw is Dictionary:
   Arena.ai_enabled=raw.get("ai",true)==true
   Arena.infinite_life=raw.get("infinite",false)==true
   Arena.show_bounds=raw.get("bounds",false)==true
   Arena.forced_skill=str(raw.get("skill","")) if raw.get("loop",false)==true else ""
  var command: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify((window.parent.editorCommands || []).shift() || null)",true)))
  if command is Dictionary:
   ack=int(command.get("id",0))
   last_command=str(command.get("action",""))
   error=""
   _command(last_command,command.get("value",""))
 _advance_loop()
 clock+=dt
 if clock<0.08: return
 clock=0.0
 var run: Dictionary=Run.snapshot(play.sm)
 if not run.get("combat",{}).get("actors",{}).has(Arena.selected_id): return
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[Arena.selected_id]
 var flow: Node=play.maze.capture_flow
 _bounds(run)
 queue_redraw()
 var status:={"ready":true,"generation":generation,"version":"unified-editor-20261110-018","ack":ack,"command":last_command,"error":error,"ai":Arena.ai_enabled,"infinite":Arena.infinite_life,"bounds":Arena.show_bounds,"elapsed":c.elapsed,"paused":get_tree().paused,"gate":play.gate.visible,"kind":Arena.selected_kind,"id":Arena.selected_id,"phase":a.get("rock_phase",a.get("frog_phase",a.get("eel_phase",a.get("fish_phase",a.mode)))),"mode":a.mode,"hero_hp":c.hp,"monster_hp":a.hp,"selected":c.get("selected",0),"throws":c.throws,"hits":c.hits,"lock":flow.locked_target_id,"actor":a,"hero":c.hero,"bounds_count":bounds.size(),"consumer_parameters":{"fish":play.FishParameters.values,"monster_attack":play.MonsterParameters.values,"player":play.PlayerParameters.values}}
 status["version"]="unified-editor-20261110-025"
 var hero_screen: Vector2=play.maze.player.get_global_transform_with_canvas().origin
 status["player_attack"]={"remaining":c.get("seed_remaining",0),"wait":c.get("seed_wait",0.0),"action_left":c.get("action_left",0.0),"cooldown":c.cooldown,"aim":c.get("aim",[]),"shots":c.shots,"screen":[hero_screen.x,hero_screen.y],"viewport":[get_viewport_rect().size.x,get_viewport_rect().size.y]}
 var tuning=preload("res://scripts/maze/combat_tuning.gd")
 status["tuning_values"]=tuning.values
 status["loop_attacks"]=loop_attacks
 status["loop_message"]=loop_message
 status["combo_note"]=a.get("rock_combo_note","")
 status["camera"]={"zoom":play.maze.camera.zoom.x,"position":[play.maze.camera.global_position.x,play.maze.camera.global_position.y],"combo_weight":play.maze.camera.combo_weight,"impact":play.maze.camera.impact_left}
 status["forced_skill"]=Arena.forced_skill
 status["save_retry"]=flow.save_retry_delay
 status["last_message"]=play.maze.last_message
 status["state_valid"]=Run.valid(run)
 var body: Sprite2D=flow.monsters[Arena.selected_id].body
 var pose: Sprite2D=flow.player_hurt_visual.pose
 status["hurt_visual"]={"monster_flash":body.material!=null and body.material.get_shader_parameter("flash")==true,"monster_alpha":body.self_modulate.a,"hero_flash":maze_flash(flow.maze.player.body),"pose_flash":maze_flash(pose),"pose_visible":pose.is_visible_in_tree(),"pose_alpha":pose.modulate.a}
 var monster: Node=flow.monsters[Arena.selected_id]
 status["motion"]={"action":monster.action,"frame":monster.frame_index(),"facing":monster.facing,"gait":monster.rock_gait,"entry_mix":monster.rock_lunge_pose.get("entry_mix",1.0),"pose_age":monster.rock_pose_age}
 status["tuning_reads"]=tuning.reads
 status["tuning_error"]=tuning.error
 status["tuning_metrics"]={"monster_stats":Run.Combat.STATS[Arena.selected_kind],"rock_distance":Run.Combat.Rock.LUNGE_DISTANCE,"rock_speed":Run.Combat.Rock.LUNGE_SPEED,"roar_range":Run.Combat.Rock.RoarArea.RADIUS,"roar_angle":rad_to_deg(Run.Combat.Rock.RoarArea.HALF_ANGLE)*2.0,"hero_action":Run.Combat.Skills.action_duration("hero"),"axe_action":Run.Combat.Skills.action_duration("tieshan"),"electric_charge":Run.Combat.ThunderEel.CHARGE_TIME,"electric_release":Run.Combat.ThunderEel.DISCHARGE_TIME,"electric_range":Run.Combat.ThunderEel.Area.radius(Arena.selected_id),"slam_range":Run.Combat.Frog.ElectricArea.radius(Run.Combat.Frog.Config.ID+"_slam")}
 if OS.has_feature("web"): JavaScriptBridge.eval("window.parent.editorTrainingStatus="+JSON.stringify(status),true)

func maze_flash(body: Sprite2D) -> bool:
 return body.material!=null and body.material.get_shader_parameter("flash")==true

func _advance_loop() -> void:
 if loop_key!=Arena.forced_skill:
  loop_key=Arena.forced_skill
  loop_next=0.0
  loop_message=""
 if loop_key.is_empty() or not Arena.ai_enabled or get_tree().paused or play.gate.visible: return
 var flow: Node=play.maze.capture_flow
 if flow.combat_paused(): return
 var run: Dictionary=Run.snapshot(play.sm)
 if not Run.valid(run): return
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[Arena.selected_id]
 if c.hp<=0 or a.hp<=0: return
 var step:=clampf(float(c.elapsed)-loop_last_clock,0.0,0.05)
 loop_last_clock=float(c.elapsed)
 var busy: bool=a.mode=="windup" or float(a.get("hit_remaining",0.0))>0.0 or float(a.get("cast",0.0))>0.0 or float(a.get("spit_left",0.0))>0.0
 if Arena.selected_kind=="rockmane": busy=busy or a.rock_phase!="active" or a.get("rock_combo",false)
 elif Arena.selected_kind=="wind_frog": busy=busy or a.frog_phase not in ["active","dormant"] or float(a.get("frog_spit_left",0.0))>0.0
 elif Arena.selected_kind=="silverfish": busy=busy or a.get("fish_phase","")!="idle"
 elif Arena.selected_kind=="thunder_eel": busy=busy or a.get("eel_phase","") not in ["idle","chasing"]
 if busy:
  loop_next=-1.0
  return
 if not _loop_position(run,step): return
 if loop_next<0.0:
  loop_next=float(c.elapsed)+float(Run.Combat.STATS[Arena.selected_kind].get("interval",1.2))
 if float(c.elapsed)<loop_next: return
 var previous_error:=error
 error=""
 _enemy_attack(loop_key)
 loop_message=error
 if error.is_empty():
  loop_attacks+=1
  loop_next=-1.0
 else: loop_next=float(c.elapsed)+0.5
 error=previous_error

func _loop_position(run: Dictionary, dt: float) -> bool:
 var a: Dictionary=run.combat.actors[Arena.selected_id]
 var pos:=Run.Combat.vec(a.position)
 var hero: Vector2=play.maze.player.position
 var next:=pos
 if Arena.selected_kind=="rockmane" and loop_key=="combo": return true
 if Arena.selected_kind=="rockmane" and loop_key=="lunge":
  if Run.Combat.Rock.can_lunge(pos,hero): return true
  next=Run.Combat.Rock.reposition(run,pos,hero,dt)
 elif loop_key=="melee":
  var stats: Dictionary=Run.Combat.STATS[Arena.selected_kind]
  var row: Dictionary=Run.monster_for(run,Arena.selected_id)
  var distance: float=pos.distance_to(hero if run.combat.region!="maze_entry" else Run.Catalog.nearest_clear_point(hero))
  if distance<=float(stats.reach) and Run.Combat.attack_line(row,pos,hero): return true
  var target: Vector2=Run.Combat.next_waypoint(pos,hero) if run.combat.region=="maze_entry" else hero
  if run.combat.region=="maze_entry":
   next=Run.Combat.move_monster(pos,hero,float(stats.speed)*dt)
   if next.distance_to(pos)<0.001: next=Run.Combat.move_monster(pos,target,float(stats.speed)*dt)
  else: next=Run.Combat.move_actor(row,pos,pos.direction_to(target)*minf(float(stats.speed)*dt,pos.distance_to(target)))
 else: return true
 a.position=Run.Combat.pack(next)
 a.velocity=Run.Combat.pack((next-pos)/dt if dt>0.0 else Vector2.ZERO)
 if Run.valid(run): play.sm.data[Run.KEY]=run
 loop_message="正在调整所选技能的出招站位"
 return false

func _command(action: String, value: Variant) -> void:
 if action=="pause":
  get_tree().paused=not get_tree().paused
  play.maze.player.clear_combat_input()
  return
 if action=="start":
  play.gate.hide()
  play.maze.player.input_locked=false
  return
 if play.gate.visible:
  error="请先点击开始体验"
  return
 var flow: Node=play.maze.capture_flow
 flow.window_focused=true
 if action=="step":
  if not get_tree().paused:
   error="请先暂停再单步"
   return
  _step()
 elif action=="weapon":
  var slot:=int(value)
  if slot not in [0,1,2]:
   error="未知角色招式，当前状态保留"
   return
  flow._select_skill(slot)
 elif action=="lock":
  if flow.locked_target_id.is_empty(): flow._cycle_target_lock()
  else: flow.locked_target_id=""
  flow.target_marker.sync(flow,0.0)
 elif action=="attack":
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=true
  flow.player_combat.handle_input(event)
 elif action=="enemy_attack": _enemy_attack(str(value))
 else: error="不支持的调试命令，当前状态保留"

func _step() -> void:
 var flow: Node=play.maze.capture_flow
 if flow.combat_paused():
  error="当前有游戏弹窗或控制锁，不能单步"
  return
 var result: Dictionary=Run.combat_tick(play.sm,play.maze.player.position,0.016,flow.visible_world_rect(),false,flow.axe_hitstop,play.maze.player.facing)
 if not result.success:
  error="单步事务失败："+str(result.get("reason","未知原因"))
  return
 var run: Dictionary=Run.snapshot(play.sm)
 play.maze.player.position=Run.Combat.vec(run.combat.hero)
 for event in result.get("player_hurt_feedback",[]): flow.player_hurt_visual.receive(event)
 for event in result.get("hit_feedback",[]):
  if flow.monsters.has(event.id): flow.monsters[event.id].hit_visual.receive(event)
 flow._process(0.0)
 for node in flow.monsters.values(): node._process(0.016)

func _enemy_attack(skill: String) -> void:
 var run: Dictionary=Run.snapshot(play.sm)
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[Arena.selected_id]
 if c.hp<=0 or a.hp<=0:
  error="角色或怪物已倒下，请先重置双方"
  return
 var pos:=Run.Combat.vec(a.position)
 var hero: Vector2=play.maze.player.position
 var aim:=pos.direction_to(hero)
 if aim.is_zero_approx(): aim=Vector2.DOWN
 var kind:=Arena.selected_kind
 if kind=="rockmane":
  if skill not in ["lunge","roar","combo"]:
   error="未知岩鬃兽技能，当前状态保留"
   return
  a.rock_combo=skill=="combo"
  a.rock_combo_note=""
  a.rock_chain_left=4 if skill=="combo" else 0
  a.rock_reuse=Run.Combat.Rock.Tuning.number("rock.roar","reuse",12.0)
  if skill=="combo":
   Run.Combat.Rock.start_combo(a,hero)
  elif skill=="roar":
   a.rock_phase="charge"
   a.rock_left=Run.Combat.Rock.Tuning.number("rock.roar","charge",1.1)
   a.rock_aim=Run.Combat.pack(aim)
  else:
   Run.Combat.Rock.begin_lunge(a,hero)
   if a.rock_phase!="lunge_charge":
    error="当前位置不足65单位或前方助跑不足40单位，请移动后再试"
    return
 elif kind=="wind_frog":
  if skill not in ["water","slam"]:
   error="未知巨蛙技能，当前状态保留"
   return
  if not Run.Combat.Frog.Config.water(hero):
   error="巨蛙技能要求玩家在可战斗水域，请先移动入水"
   return
  a.frog_phase="active"
  a.mode="chase"
  if skill=="water": Run.Combat.Frog.prepare_spit(a,pos,hero)
  else:
   var target: Vector2=preload("res://scripts/maze/frog_water_path.gd").landing(run,pos,hero)
   if target.distance_squared_to(pos)<0.01:
    error="附近没有可用跳跃落点，当前状态保留"
    return
   a.frog_phase="warning"
   a.frog_left=Run.Combat.Frog.Tuning.effect("slam","windup",1000.0)/1000.0
   a.frog_origin=a.position.duplicate()
   a.frog_target=Run.Combat.pack(target)
   a.frog_air_duration=Run.Combat.Frog.Counter.AIR_TIME
 elif kind=="silverfish":
  if skill!="rush":
   error="未知银鳞鱼技能，当前状态保留"
   return
  if not Run.Combat.Silverfish.Water.water(pos):
   error="银鳞鱼须先回水，当前状态保留"
   return
  a.fish_origin=a.position.duplicate()
  a.fish_aim=Run.Combat.pack(aim)
  a.fish_hit=false
  Run.Combat.Silverfish.phase(a,"warning",play.FishParameters.seconds("windup"))
 elif kind=="thunder_eel":
  if skill!="electric" or not Run.Combat.ThunderEel.Water.water(pos):
   error="雷鳗须在水中才能蓄电，当前状态保留"
   return
  if not a.has("eel_origin"):
   a.eel_origin=a.position.duplicate()
   a.eel_path=[]
  if not a.has("eel_discharges"): a.eel_discharges=0
  if a.eel_discharges>=3: a.eel_discharges=0
  Run.Combat.ThunderEel.phase(a,"charging",Run.Combat.ThunderEel.CHARGE_TIME)
 elif kind=="slime" and skill=="spit":
  a.mode="chase"
  a.cast=preload("res://scripts/maze/combat_tuning.gd").number("slime.spit","charge",0.65)
  a.cast_aim=Run.Combat.pack(aim)
  a.skill_reuse=preload("res://scripts/maze/combat_tuning.gd").number("slime.spit","interval",2.4)
 else:
  if skill!="melee":
   error="未知近战技能，当前状态保留"
   return
  var stats: Dictionary=Run.Combat.STATS[kind]
  a.mode="windup"
  a.windup=stats.windup
  a.cooldown=stats.interval
  if kind in ["mimic_crab","blind_scorpion"]: a.attack_aim=Run.Combat.pack(aim)
 a.velocity=[0.0,0.0]
 if not Run.valid(run):
  error="技能起点校验失败，原训练状态保留"
  return
 play.sm.data[Run.KEY]=run

func _bounds(run: Dictionary) -> void:
 bounds.clear()
 if not Arena.show_bounds: return
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[Arena.selected_id]
 var pos:=Run.Combat.vec(a.position)
 var kind:=Arena.selected_kind
 if c.get("region","")=="fenshui":
  var bodies=preload("res://scripts/maze/fenshui_bodies.gd")
  bounds.append({"shape":_ellipse(pos,bodies.footprint(Arena.selected_id)),"color":Color(0.61,0.82,0.65,0.12)})
  bounds.append({"shape":_ellipse(Run.Combat.vec(c.hero),bodies.footprint("hero")),"color":Color(0.61,0.82,0.65,0.12)})
 elif kind=="rockmane":
  bounds.append({"shape":_ellipse(pos,Run.Combat.Rock.Bodies.footprint(Arena.selected_id)),"color":Color(0.61,0.82,0.65,0.12)})
  bounds.append({"shape":_ellipse(Run.Combat.vec(c.hero),Run.Combat.Rock.Bodies.footprint("hero")),"color":Color(0.61,0.82,0.65,0.12)})
 if kind=="rockmane" and a.rock_phase in ["charge","rush"]:
  bounds.append({"shape":Run.Combat.Rock.RoarArea.polygon(pos,Run.Combat.vec(a.rock_aim)),"color":Color(0.95,0.67,0.35,0.22)})
 if kind=="thunder_eel" and a.get("eel_phase","") in ["charging","discharge"]:
  bounds.append({"shape":Run.Combat.ThunderEel.Area.polygon(pos,Arena.selected_id),"color":Color(0.9,0.78,0.4,0.2)})
 if kind=="wind_frog" and a.frog_phase in ["warning","airborne","landing"]:
  bounds.append({"shape":Run.Combat.Frog.ElectricArea.polygon(Run.Combat.vec(a.frog_target),Arena.selected_id+"_slam"),"color":Color(0.4,0.78,0.82,0.2)})

func _ellipse(origin: Vector2, radius: Vector2) -> PackedVector2Array:
 var shape:=PackedVector2Array()
 for i in 32: shape.append(origin+Vector2(cos(TAU*i/32.0),sin(TAU*i/32.0))*radius)
 return shape

func _draw() -> void:
 for row in bounds:
  var shape: PackedVector2Array=row.shape
  if shape.size()<3: continue
  draw_colored_polygon(shape,row.color)
  var edge:=shape.duplicate()
  edge.append(shape[0])
  draw_polyline(edge,Color(row.color,0.7),1.0,true)
