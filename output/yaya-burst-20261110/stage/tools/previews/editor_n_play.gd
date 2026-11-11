extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Arena=preload("res://tools/previews/editor_n_arena.gd")
const Confirmation=preload("res://scripts/ui/components/destination_confirmation.gd")
const FishParameters=preload("res://scripts/maze/silverfish_editor.gd")
const MonsterParameters=preload("res://scripts/maze/monster_editor.gd")
const PlayerParameters=preload("res://scripts/maze/player_editor.gd")
const REGIONS={"slime":"maze_entry","snail":"maze_entry","beetle":"maze_entry","lizard":"maze_entry","fish":"fenshui","eel":"fenshui","frog":"fenshui","mimic_crab":"salt_pool","blind_scorpion":"salt_pool","rockmane":"salt_pool"}
const KINDS={"fish":"silverfish","eel":"thunder_eel","frog":"wind_frog"}
var maze: Node2D
var gate: Control
var clock:=0.0

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 Arena.enabled=true
 var choice:="frog"
 if OS.has_feature("web"):
  choice=str(JavaScriptBridge.eval("window.parent.runtimeEnemy || 'frog'",true))
  var player: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.runtimePlayer || {})",true)))
  if player is Dictionary and player.get("version")==1 and player.get("effects") is Dictionary:
   var candidate: Dictionary={}
   var valid: bool=player.effects.size()==PlayerParameters.DEFAULTS.size()
   for id in PlayerParameters.DEFAULTS:
    var row: Variant=player.effects.get(id)
    if not row is Dictionary or not row.has("hitstop"):
     valid=false
     continue
    var n: Variant=row.hitstop
    if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)) or n<0 or n>200 or float(n)!=floor(float(n)):
     valid=false
    else:
     candidate[id]=int(n)
   if valid:
    PlayerParameters.values=candidate
    PlayerParameters.initialized=true
  var attacks: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.runtimeMonsterAttack || {})",true)))
  if attacks is Dictionary and attacks.get("version")==1 and attacks.get("attack") is Dictionary:
   var candidate: Dictionary=attacks.attack
   var valid: bool=candidate.size()==MonsterParameters.KINDS.size()
   for id in MonsterParameters.KINDS:
    if not candidate.has(id) or typeof(candidate[id]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(candidate[id])) or candidate[id]<0 or candidate[id]>100 or float(candidate[id])!=floor(float(candidate[id])): valid=false
   if valid:
    MonsterParameters.values=candidate.duplicate(true)
    MonsterParameters.initialized=true
  var packet: Variant=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.parent.runtimeConfig || {})",true)))
  if choice=="fish" and packet is Dictionary and packet.get("effects",{}) is Dictionary and packet.effects.get("fish",{}) is Dictionary:
   var fish: Dictionary=packet.effects.fish
   var good:=true
   for key in FishParameters.DEFAULTS:
    if not fish.has(key) or typeof(fish[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(fish[key])) or float(fish[key])<FishParameters.LIMITS[key][0] or float(fish[key])>FishParameters.LIMITS[key][1]: good=false
   if good:
    FishParameters.values=fish.duplicate(true)
    FishParameters.initialized=true
 else:
  for arg in OS.get_cmdline_user_args():
   if arg.begins_with("--arena-kind="): choice=arg.trim_prefix("--arena-kind=")
 if not REGIONS.has(choice): choice="frog"
 _install_tuning()
 Arena.selected_kind=KINDS.get(choice,choice)
 call_deferred("_run")

func _install_tuning() -> void:
 var tuning=preload("res://scripts/maze/combat_tuning.gd")
 tuning.install()
 for id in Run.Combat.STATS:
  var stats: Dictionary=Run.Combat.STATS[id]
  for key in stats:
   if key!="attack": stats[key]=tuning.number("base."+str(id),str(key),float(stats[key]))
 for key in FishParameters.DEFAULTS: FishParameters.values[key]=tuning.effect("fish",key,FishParameters.value(key))
 FishParameters.initialized=true
 for id in PlayerParameters.DEFAULTS: PlayerParameters.values[id]=int(tuning.effect(id,"hitstop",PlayerParameters.hitstop(id)))
 PlayerParameters.initialized=true
 Run.Combat.Rock.LUNGE_DISTANCE=tuning.number("rock.lunge","distance",160.0)
 Run.Combat.Rock.LUNGE_SPEED=tuning.number("rock.lunge","speed",200.0)
 Run.Combat.Rock.LUNGE_DURATIONS.lunge=Run.Combat.Rock.LUNGE_DISTANCE/Run.Combat.Rock.LUNGE_SPEED
 Run.Combat.Rock.LUNGE_DURATIONS.lunge_charge=tuning.number("rock.lunge","charge",1.2)
 Run.Combat.Rock.LUNGE_DURATIONS.lunge_recover=tuning.number("rock.lunge","recover",2.0)
 Run.Combat.Rock.LUNGE_DURATIONS.stunned=tuning.number("rock.lunge","stun",1.5)
 Run.Combat.Rock.RoarArea.RADIUS=tuning.number("rock.roar","range",260.0)
 Run.Combat.Rock.RoarArea.HALF_ANGLE=deg_to_rad(tuning.number("rock.roar","angle",70.0)/2.0)
 for i in 4:
  Run.Combat.Rock.COMBO_CHARGES[i]=tuning.number("rock.combo","charge"+str(i+1),Run.Combat.Rock.COMBO_CHARGES[i])
  Run.Combat.Rock.COMBO_RECOVERS[i]=tuning.number("rock.combo","recover"+str(i+1),Run.Combat.Rock.COMBO_RECOVERS[i])
 Run.Combat.ThunderEel.CHARGE_TIME=tuning.effect("electric","windup",1200.0)/1000.0
 Run.Combat.ThunderEel.DISCHARGE_TIME=tuning.effect("electric","recover",350.0)/1000.0
 Run.Combat.ThunderEel.EXHAUST_TIME=tuning.number("eel.skill","rest",4.0)
 Run.Combat.ThunderEel.FORM_TIME=tuning.number("eel.skill","form",1.0)


func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 if ProjectSettings.get_setting("application/config/name")!="maze_fenshui_editor_isolated":
  push_error("编辑器必须使用隔离项目")
  get_tree().quit(1)
  return
 _completed()
 # 训练场不播放主线教程；只修改本隔离项目创建的临时探索档。
 sm.data["ch2_guide_01"]={"step":"done","revision":2,"seen":{},"banked":{}}
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"隔离探索创建")
 var selected:=Arena.selected_kind
 var choice: String={"silverfish":"fish","thunder_eel":"eel","wind_frog":"frog"}.get(selected,selected)
 var region: String=REGIONS[choice]
 var initial: Vector2=sm.maze_terrain(region).SPAWN
 if region!="maze_entry": _check(Run.change_region(sm,region,initial).success,"进入怪物所在地图")
 if failures:
  get_tree().quit(1)
  return
 var run: Dictionary=sm.data[Run.KEY]
 var row: Dictionary={}
 for entry in Run.Catalog.rows(run.combat,true):
  if entry.kind==selected:
   row=entry
   break
 if row.is_empty():
  push_error("当前地图没有选中怪物："+selected)
  get_tree().quit(1)
  return
 Arena.selected_id=row.id
 var point:=Vector2.INF
 var spawn_distance: float=150.0 if selected=="rockmane" else (45.0 if selected=="silverfish" else 55.0)
 for index in 64:
  var candidate: Vector2=row.position+Vector2.RIGHT.rotated(TAU*index/64.0)*spawn_distance
  if sm.maze_terrain(region).is_walkable(candidate) and Run.Combat.Skills.clear_line(candidate,row.position,region) and not Run.Combat.protected(row,candidate):
   point=candidate
   break
 if not point.is_finite():
  push_error("怪物附近没有找到合法站位："+selected)
  get_tree().quit(1)
  return
 for id in run.monsters:
  if id!=row.id: run.monsters[id].status="skipped"
 run.combat.hero=Run.Combat.pack(point)
 run.combat.frog_unlocked=true
 if run.combat.has("slime_lesson"): run.combat.slime_lesson.enabled=false
 _check(sm.record_maze_location(region,point).success,"设置单怪真实地图站位")
 if failures:
  get_tree().quit(1)
  return
 maze=load("res://scenes/maze_"+("entry" if region=="maze_entry" else region)+".tscn").instantiate()
 get_parent().add_child(maze)
 if get_parent()==get_tree().root: get_tree().current_scene=maze
 for i in 240:
  if maze._entry_ready: break
  await get_tree().process_frame
 if not maze._entry_ready or not maze.capture_flow.monsters.has(row.id):
  push_error("真实地图或选中怪物未加载："+selected)
  get_tree().quit(1)
  return
 if selected=="wind_frog":
  var frog: Node=maze.capture_flow.monsters[row.id]
  if not frog.enable_frog_front24():
   push_error("巨蛙原动作未能加载")
   get_tree().quit(1)
   return
  var splash=preload("res://scripts/maze/frog_splash_aligned_visual.gd").new()
  splash.flow=maze.capture_flow
  frog.add_child(splash)
 var training=preload("res://tools/previews/editor_training_controls.gd").new()
 training.play=self
 maze.add_child(training)
 maze.player.input_locked=true
 var layer:=CanvasLayer.new()
 layer.layer=100
 maze.add_child(layer)
 gate=Confirmation.new()
 layer.add_child(gate)
 gate.open_confirmation("单怪训练："+str(row.name)+"\n真实地图与原战斗 · 隔离存档\nWASD移动 · 左键攻击\nTab锁定 / Q解除 · 空格/1/2换招", "开始体验", "关闭体验")
 gate.confirmed.connect(func(): gate.hide(); maze.player.input_locked=false)
 gate.cancelled.connect(func(): get_tree().quit())
 if "--arena-check" in OS.get_cmdline_user_args():
  print("ARENA_READY ",JSON.stringify({"kind":selected,"id":row.id,"region":region,"nodes":maze.capture_flow.monsters.keys(),"valid":Run.valid(Run.snapshot(sm))}))
  get_tree().quit()

func _process(dt: float) -> void:
 if not OS.has_feature("web") or not is_instance_valid(maze) or not maze._entry_ready or not is_instance_valid(gate): return
 clock+=dt
 if clock<0.1: return
 clock=0.0
 var command: String=str(JavaScriptBridge.eval("(()=>{const c=window.parent.runtimeCommand||'';window.parent.runtimeCommand='';return c})()",true))
 if command=="pause": get_tree().paused=not get_tree().paused
 var run: Dictionary=Run.snapshot(sm)
 var flow: Node=maze.capture_flow
 var hurt: Node=flow.player_hurt_visual
 var status:={"ready":true,"gate":is_instance_valid(gate) and gate.visible,"arena_enemy":str(JavaScriptBridge.eval("window.parent.runtimeEnemy",true)),"arena_kind":Arena.selected_kind,"spawned_ids":flow.monsters.keys(),"monsters":flow.monsters.size(),"hp":run.combat.hp,"max_hp":run.combat.max_hp,"hits":run.combat.hits,"lock":flow.locked_target_id,"paused":get_tree().paused,"hurt_recovery_left":run.combat.get("hurt_recovery_left",0.0),"player_hurt":{"kind":hurt.kind,"received":hurt.received},"version":"N-editor-candidate","parameters":{"fish":FishParameters.values,"monster_attack":MonsterParameters.values,"player":PlayerParameters.values}}
 status["combat_observation"]={"elapsed":run.combat.elapsed,"throws":run.combat.throws,"action":run.combat.get("action",""),"action_left":run.combat.get("action_left",0.0),"cooldown":run.combat.cooldown,"flow_paused":flow.combat_paused(),"window_focused":flow.window_focused,"player_locked":maze.player.input_locked,"maze_busy":maze._busy,"flow_busy":flow.busy,"hero":run.combat.hero,"target":run.combat.actors.get(Arena.selected_id,{})}
 status.combat_observation["confirmation"]=maze.confirmation.visible
 status.combat_observation["map_expanded"]=maze.map_ui.expanded
 status.combat_observation["physics_processing"]=maze.player.is_physics_processing()
 status.combat_observation["player_hitstop"]=flow.axe_hitstop.state.duplicate(true) if flow.axe_hitstop!=null else {}
 if is_instance_valid(gate) and gate.visible:
  var rect: Rect2=gate.confirm_button.get_global_rect()
  status.start_button=[rect.position.x,rect.position.y,rect.size.x,rect.size.y]
  var size:=get_viewport().get_visible_rect().size
  status.viewport=[size.x,size.y]
 JavaScriptBridge.eval("window.parent.runtimeStatus="+JSON.stringify(status),true)
