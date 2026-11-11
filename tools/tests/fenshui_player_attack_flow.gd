extends "res://tools/tests/silverfish_shore_flow.gd"
## 正式场景真实发射与受击，不以网页播放代替游戏接入。
const YAYA_TEXTURE = "res://assets/combat/team_skills/fenshui_yaya_point.png"
const TIESHAN_TEXTURE = "res://assets/combat/team_skills/fenshui_tieshan_sweep.png"
const Thunder = preload("res://scripts/maze/thunder_eel_combat.gd")
const EEL_ID = "fenshui_thunder_eel_1"
var attack_events: Array = []
var observing := false
var feedback_frames: Array = []
var feedback_target: String = Rules.IDS[0]
@export var standalone_viewport := false
var attack_view: SubViewport

func _scene_check(_effects: Node) -> void:
 output = _arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 _check(get_window().unfocusable and ProjectSettings.get_setting_with_override("display/window/size/no_focus"), "测试启动保持不可聚焦，系统焦点由运行器独立采样", {"cached_focus":get_window().has_focus(),"unfocusable":get_window().unfocusable})
 if standalone_viewport:
  # 主窗口最小化时仍渲染；测试事件、截图与真正场景必须使用同一视口。
  attack_view=SubViewport.new()
  attack_view.size=Vector2i(1280,720)
  attack_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  get_tree().root.add_child(attack_view)
  maze.reparent(attack_view)
  reparent(attack_view)
 _check(get_viewport()==maze.get_viewport(),"测试输入、截图与真实场景消费同一视口")
 for layer in maze.get_children():
  if layer is CanvasLayer and layer.layer==100:
   for hint in layer.get_children():
    if hint.has_method("dismiss"): hint.dismiss()
 RenderingServer.frame_post_draw.connect(_observe_feedback)
 baseline = sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial = false
 baseline[Run.KEY].combat.cooldown = 0.0
 for id in baseline[Run.KEY].monsters:
  baseline[Run.KEY].monsters[id].status = "alive" if id==Rules.IDS[0] else "skipped"
 var fish: Dictionary = baseline[Run.KEY].combat.actors[Rules.IDS[0]]
 fish.position = [920.0,440.0]
 fish.fish_origin = fish.position.duplicate()
 fish.fish_aim = [0.0,1.0]
 fish.fish_hit = false
 Fish.phase(fish, "recover", 2.5)
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  get_window().size = size
  if is_instance_valid(attack_view): attack_view.size=size
  await _yaya_flight()
  await _tieshan_timing()
 await _sweep_frames()
 for target in [Rules.IDS[0],EEL_ID]:
  for slot in [KEY_SPACE,KEY_1,KEY_2]: await _hit_feedback(slot,target)
 for slot in [KEY_SPACE,KEY_1,KEY_2]: await _miss_feedback(slot)
 await _axe_behind_observation()
 _check(not invalid_seen, "真实玩家出手与受击过程中战斗状态合法")
 _check(not frame_ms.is_empty() and frame_ms.max()<250.0, "本批单目标出手与反馈保留250毫秒帧门槛", {"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
 _finish_attack()

func _yaya_flight() -> void:
 section = "芽芽正式光点发射"
 await _reset(Vector2(840,490))
 recording = true
 last_frame = 0
 await _send_key(KEY_1)
 var before: int = Run.snapshot(sm).combat.throws
 await _attack_click()
 _check(Run.snapshot(sm).combat.throws==before+1, "真实内部按键和鼠标发射芽芽招式")
 _check(await _wait_until(func():
  for shot in Run.snapshot(sm).combat.shots:
   if shot.get("kind","")=="yaya" and shot.time>=0.07: return true
  return false, 60), "取证前真实光点已离手进入在途段")
 maze.capture_flow.set_process(false)
 await get_tree().process_frame
 var points := _sprites(YAYA_TEXTURE)
 _check(points.size()==1, "真实在途芽芽弹体使用用户认可的水彩光点", {"visible":points.size()})
 _check(maze.capture_flow.skill_visual.beams.is_empty(), "正式分水庭不再叠加旧长束线")
 if not points.is_empty():
  var point: Sprite2D = points[0]
  var shot: Dictionary = Run.snapshot(sm).combat.shots[0]
  _check(Vector2.RIGHT.rotated(point.rotation).dot(Fish.vec(shot.origin).direction_to(Fish.vec(shot.target)))>0.999, "光点头部朝向真实弹道，不沿旧图标旋转角")
  _check(is_equal_approx(point.texture.get_width()*point.scale.x*maze.camera.zoom.x,60.0), "光点沿用新确认的60屏幕像素，不拉成长激光")
  var original: Dictionary = sm.data[Run.KEY].duplicate(true)
  var before_transform: Transform2D = point.transform
  var alpha: float = point.modulate.a
  await _click(maze.map_ui.mini_button)
  await get_tree().create_timer(0.2).timeout
  _check(maze.map_ui.expanded and point.transform==before_transform and point.modulate.a==alpha, "地图暂停时光点位置、方向和明暗冻结")
  await _send_key(KEY_ESCAPE)
  var hidden: Dictionary = original.duplicate(true)
  hidden.combat.shots.clear()
  sm.data[Run.KEY] = hidden
  await get_tree().process_frame
  await get_tree().process_frame
  _check(_sprites(YAYA_TEXTURE).is_empty(), "原在途弹体结束后不残留光点")
  hidden = original.duplicate(true)
  hidden.combat.fs01_trial = true
  sm.data[Run.KEY] = hidden
  await get_tree().process_frame
  await get_tree().process_frame
  _check(_sprites(YAYA_TEXTURE).is_empty() and not maze.capture_flow.skill_visual.beams.is_empty(), "历史隔离试玩保持旧显示，不混入正式新素材")
  sm.data[Run.KEY] = original
  await get_tree().process_frame
 await _image("yaya_flight_"+str(get_window().size.x))
 recording = false

func _tieshan_timing() -> void:
 for side in ["right","left"]:
  section = "铁山真实挥斧"+side
  await _reset(Vector2(880,490) if side=="right" else Vector2(940,490))
  recording = true
  last_frame = 0
  await _send_key(KEY_2)
  await _attack_click()
  _check(await _wait_until(func():
   var c: Dictionary = Run.snapshot(sm).combat
   return c.action=="tieshan" and c.action_left<=0.30 and c.action_left>0.24, 120), "真实计时进入向前挥斧帧："+side)
  maze.capture_flow.set_process(false)
  await get_tree().process_frame
  await get_tree().process_frame
  _check(_sprites(TIESHAN_TEXTURE).size()==1, "真实向前挥斧叠加认可的原弧光："+side)
  if not _sprites(TIESHAN_TEXTURE).is_empty():
   var sweep: Sprite2D = _sprites(TIESHAN_TEXTURE)[0]
   _check((sweep.scale.x<0)==(side=="left"), "弧光转轴与角色同步左右镜像："+side)
   _check(sweep.texture.get_width()*absf(sweep.scale.x)*maze.camera.zoom.x<135.0, "弧光保持认可的相对人物比例，不表达更大判定："+side)
  await _image("tieshan_sweep_"+side+"_"+str(get_window().size.x))
  recording = false

func _sweep_frames() -> void:
 var original: Dictionary = Run.snapshot(sm)
 for index in 8:
  var run: Dictionary = original.duplicate(true)
  run.combat.action = "tieshan"
  run.combat.action_left = 0.48-(float(index)+0.5)*0.06
  sm.data[Run.KEY] = run
  await get_tree().process_frame
  await get_tree().process_frame
  var visible: bool = not _sprites(TIESHAN_TEXTURE).is_empty()
  _check(visible==(index in [2,3]), "八帧原动作仅向前扫过的第2/3帧出现弧光："+str(index))
 var run: Dictionary = original.duplicate(true)
 run.combat.action_left = 0.28
 sm.data[Run.KEY] = run
 await get_tree().process_frame
 await get_tree().process_frame
 var sweep: Sprite2D = _sprites(TIESHAN_TEXTURE)[0]
 await _click(maze.map_ui.mini_button)
 var before: Transform2D = sweep.transform
 var alpha: float = sweep.modulate.a
 await get_tree().create_timer(0.2).timeout
 _check(maze.map_ui.expanded and sweep.transform==before and sweep.modulate.a==alpha, "暂停时挥砍弧光与原人物帧同步冻结")
 await _send_key(KEY_ESCAPE)
 for action in ["hero","yaya",""]:
  run = original.duplicate(true)
  run.combat.action = action
  run.combat.action_left = 0.2 if not action.is_empty() else 0.0
  sm.data[Run.KEY] = run
  await get_tree().process_frame
  await get_tree().process_frame
  _check(_sprites(TIESHAN_TEXTURE).is_empty(), "换招或结束不残留弧光："+action)

func _observe_feedback() -> void:
 if not observing: return
 var run: Dictionary = Run.snapshot(sm)
 var a: Dictionary = run.combat.actors[feedback_target]
 var node: Node = maze.capture_flow.monsters[feedback_target]
 feedback_frames.append({"frame":Engine.get_frames_drawn(), "hp":a.hp, "position":a.position.duplicate(), "flash":node.body.material.get_shader_parameter("flash"), "flash_left":a.get("flash_remaining",0.0), "hit_left":a.get("hit_remaining",0.0), "action_left":run.combat.action_left, "membrane":node.membrane.visible})

func _feedback_actor() -> Dictionary:
 return Run.snapshot(sm).combat.actors[feedback_target]

func _hit_feedback(slot: Key,target: String) -> void:
 section = "真实命中反馈"+target+"_"+str(slot)
 var saved: Dictionary = baseline.duplicate(true)
 feedback_target = target
 for id in baseline[Run.KEY].monsters: baseline[Run.KEY].monsters[id].status = "alive" if id==target else "skipped"
 if target==EEL_ID:
  var eel: Dictionary = baseline[Run.KEY].combat.actors[target]
  eel.position = [920.0,440.0]
  eel.eel_origin = eel.position.duplicate()
  eel.eel_path = []
  Thunder.phase(eel, "charging", 1.2)
 await _reset(Vector2(840,490) if slot==KEY_1 else Vector2(880,490))
 await _send_key(slot)
 var hp: float = _feedback_actor().hp
 var point: Vector2 = Fish.vec(_feedback_actor().position)
 var hits: int = Run.snapshot(sm).combat.hits
 feedback_frames = []
 observing = true
 recording = true
 last_frame = 0
 await _attack_click()
 _check(await _wait_until(func(): return _feedback_actor().hp<hp,180), "真实招式命中才扣怪物生命："+target+"_"+str(slot))
 var after_hp: float = _feedback_actor().hp
 await _image("hit_"+target+"_"+str(slot))
 await get_tree().create_timer(0.3).timeout
 observing = false
 var changed: Array = feedback_frames.filter(func(row): return row.hp<hp)
 _check(not changed.is_empty() and changed[0].flash==true, "第一次实际扣血的渲染帧同步出现既有闪白："+str(slot))
 _check(Fish.vec(_feedback_actor().position).distance_to(point)>1.0, "真实命中后怪物发生既有击退位移："+str(slot))
 _check(_feedback_actor().get("hit_remaining",0.0)<=0.00001 and not maze.capture_flow.monsters[target].body.material.get_shader_parameter("flash"), "受击结束后闪白与击退计时恢复："+str(slot))
 _check(_feedback_actor().hp==after_hp and Run.snapshot(sm).combat.hits==hits+1, "单次招式不因绘制新特效重复伤害："+str(slot))
 attack_events.append({"case":section, "target":target, "hp_before":hp, "hp_after":after_hp, "displacement":Fish.vec(_feedback_actor().position).distance_to(point), "frames":feedback_frames.duplicate(true)})
 recording = false
 baseline = saved
 feedback_target = Rules.IDS[0]

func _miss_feedback(slot: Key) -> void:
 section = "真实打空"+str(slot)
 var saved: Dictionary = baseline.duplicate(true)
 baseline[Run.KEY].monsters[Rules.IDS[0]].status = "skipped"
 await _reset(Vector2(840,490))
 await _send_key(slot)
 var hp: float = actor().hp
 var hits: int = Run.snapshot(sm).combat.hits
 recording = true
 last_frame = 0
 await _attack_click()
 await get_tree().create_timer(0.8).timeout
 _check(actor().hp==hp and Run.snapshot(sm).combat.hits==hits, "真实打空不制造扣血或命中："+str(slot))
 _check(_sprites(YAYA_TEXTURE).is_empty() and _sprites(TIESHAN_TEXTURE).is_empty(), "打空招式结束后新素材全部隐藏："+str(slot))
 baseline = saved
 recording = false

func _axe_behind_observation() -> void:
 var saved: Dictionary = baseline.duplicate(true)
 var second := "fenshui_silverfish_2"
 baseline[Run.KEY].monsters[second].status = "alive"
 var fish: Dictionary = baseline[Run.KEY].combat.actors[second]
 fish.position = [1040.0,440.0]
 fish.fish_origin = fish.position.duplicate()
 fish.fish_aim = [0.0,1.0]
 fish.fish_hit = false
 Fish.phase(fish, "recover", 2.5)
 await _reset(Vector2(980,440))
 await _send_key(KEY_2)
 var hp := {Rules.IDS[0]:actor().hp, second:Run.snapshot(sm).combat.actors[second].hp}
 await _attack_click()
 var aim: Vector2 = Fish.vec(Run.snapshot(sm).combat.aim)
 _check(await _wait_until(func():
  var c: Dictionary = Run.snapshot(sm).combat
  return c.actors[Rules.IDS[0]].hp<hp[Rules.IDS[0]] and c.actors[second].hp<hp[second],120), "视觉接入保留原旋斧前后两侧66范围命中，不改成扇形")
 var run: Dictionary = Run.snapshot(sm)
 var behind: Array = []
 for id in hp:
  if (Fish.vec(run.combat.actors[id].position)-maze.player.position).dot(aim)<0 and run.combat.actors[id].hp<hp[id]: behind.append(id)
 _check(not behind.is_empty(), "实测确认挥斧背侧目标也可能扣血的既有表现差异")
 attack_events.append({"case":"铁山背侧受击观察", "aim":run.combat.aim, "behind":behind})
 await _image("axe_behind_actual_hit")
 baseline = saved

func _image(name: String) -> void:
 await super._image(name)
 var a: Dictionary = _feedback_actor()
 var node: Node = maze.capture_flow.monsters[feedback_target]
 pictures[-1].merge({"target":feedback_target, "hp":a.hp, "position":a.position, "phase":a.get("eel_phase","idle") if feedback_target==EEL_ID else a.get("fish_phase","idle"), "action":node.action, "frame":node.frame_index(), "direction":node.facing, "membrane_visible":node.membrane.visible},true)

func _sprites(path: String) -> Array:
 var result: Array = []
 for child in maze.capture_flow.skill_visual.get_children():
  if child is Sprite2D and child.is_visible_in_tree() and child.texture!=null and child.texture.resource_path==path:
   result.append(child)
 return result

func _finish_attack() -> void:
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks, "failures":failures, "results":results, "frame_ms":frame_ms, "long_frames":long_frames, "pictures":pictures, "attack_events":attack_events, "user_dir":OS.get_user_data_dir()}, "\t"))
 print("分水庭玩家出手接入：",checks,"项，失败",failures)
 get_tree().quit(1 if failures else 0)
