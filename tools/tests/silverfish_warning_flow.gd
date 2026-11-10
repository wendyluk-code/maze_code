extends "res://tools/tests/fenshui_area_flow.gd"
## 正式四鱼双鳗显示入口；先固定同场基线，再验收认可的短水纹。
const Fish = preload("res://scripts/maze/silverfish_combat.gd")
const WARNING_TEXTURE = "res://assets/effects/fenshui/silverfish_warning_v4.png"
var warning_visual: Node2D

func _draw_samples() -> void:
 for child in maze.get_children():
  if child is CanvasLayer and child.layer == 100:
   for hint in child.get_children():
    if hint.has_method("dismiss"): hint.dismiss() # 不沿用历史试玩“白箭头”的提示。
  if child.get_script() != null and child.get_script().resource_path == "res://scripts/maze/silverfish_warning.gd":
   warning_visual = child
 _check(is_instance_valid(warning_visual), "正式分水庭安装鱼预警显示")
 for size in [Vector2i(1152,648), Vector2i(1280,720)]:
  get_window().size = size
  await _reset(Vector2(1040,490))
  maze.capture_flow.set_process(false)
  var run: Dictionary = Run.snapshot(sm)
  var aims := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
  for i in 4:
   var id := "fenshui_silverfish_%d" % (i+1)
   var a: Dictionary = run.combat.actors[id]
   Fish.phase(a, "warning", 0.4)
   a.fish_aim = Fish.pack(aims[i])
  sm.data[Run.KEY] = run
  for id in maze.capture_flow.monsters:
   if not run.combat.actors.has(id): continue
   var node: Node = maze.capture_flow.monsters[id]
   node.position = Fish.vec(run.combat.actors[id].position)
   node.visible = run.monsters[id].status == "alive"
   node.sync_action(run.combat.actors[id], run.combat)
  for i in 45: await get_tree().process_frame
  var sprites: Array = _visible_warnings()
  _check(sprites.size() == 4, "四向鱼预警均实际显示认可的v4原图："+str(size), {"visible":sprites.size()})
  for i in 4:
   var id := "fenshui_silverfish_%d" % (i+1)
   var sprite := warning_visual.get_node_or_null(id) as Sprite2D
   if sprite == null: continue
   var offset: Vector2 = sprite.position-Fish.vec(run.combat.actors[id].position)
   _check(offset.dot(aims[i])>15 and offset.length()<45, "水纹只在鱼头附近，不画完整冲刺通道："+id)
   _check(Vector2.RIGHT.rotated(sprite.rotation).dot(aims[i])>0.999, "水纹四向对应已锁定朝向："+id)
   _check((sprite.get_rect().size*sprite.scale).length()<105, "单张水纹保持短小，不随攻击距离拉长："+id)
  await _image("four_fish_warning_%dx%d" % [size.x,size.y])
  frame_ms.clear()
  last_frame = 0
  recording = true
  section = "四鱼预警双鳗同场"+str(size)
  for i in 180: await get_tree().process_frame
  recording = false
  var samples: Array = frame_ms.duplicate()
  samples.sort()
  area_events.append({"resolution":str(size), "monsters":6, "samples":samples.size(), "median_ms":samples[samples.size()/2], "p95_ms":samples[int(samples.size()*0.95)], "max_ms":samples.max()})
  _check(samples.max()<250.0, "真实四鱼双鳗预警保留250毫秒门槛", area_events.back())
 await _state_checks()
 await _real_overlap()

func _settle() -> void:
 await get_tree().process_frame
 await get_tree().process_frame

func _state_checks() -> void:
 var sprite := warning_visual.get_node_or_null(FISH) as Sprite2D
 if sprite == null: return
 var run: Dictionary = Run.snapshot(sm)
 var original: Dictionary = run.duplicate(true)
 var before: Transform2D = sprite.transform
 var alpha: float = sprite.modulate.a
 var scale_before: Vector2 = sprite.scale
 run.combat.actors[FISH].fish_left = 0.26
 sm.data[Run.KEY] = run
 await _settle()
 _check(sprite.position.distance_to(before.origin)>0.1 and sprite.position.distance_to(before.origin)<=2.1, "预警推进时只做轻微前后平移")
 _check(absf(sprite.modulate.a-alpha)>0.005 and sprite.scale==scale_before, "水纹明暗轻微变化，不缩放拉伸原图")
 await _click(maze.map_ui.mini_button)
 _check(maze.map_ui.expanded, "水纹预警时实际打开地图")
 before = sprite.transform
 alpha = sprite.modulate.a
 await get_tree().create_timer(0.25).timeout
 _check(sprite.transform==before and sprite.modulate.a==alpha, "暂停时水纹位置与透明度完全冻结")
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked, "关闭地图恢复输入")
 for phase in ["rush","idle","stranded","returning","forming","recover"]:
  run = original.duplicate(true)
  Fish.phase(run.combat.actors[FISH], phase, 0.3)
  sm.data[Run.KEY] = run
  await _settle()
  _check(not sprite.visible and _visible_warnings().size()==3, "离开预警立即隐藏且不影响其他鱼："+phase)
 for reason in ["hp_zero","captured","trial","other_region","inactive"]:
  run = original.duplicate(true)
  match reason:
   "hp_zero": run.combat.actors[FISH].hp = 0
   "captured": run.monsters[FISH].status = "captured"
   "trial": run.combat.fs01_trial = true
   "other_region": run.combat.region = "maze_entry"
   "inactive": run.active = false
  sm.data[Run.KEY] = run
  await _settle()
  _check(not sprite.visible, "非适用状态不残留水纹："+reason)
 sm.data[Run.KEY] = original
 await _settle()
 _check(_visible_warnings().size()==4, "恢复有效预警后四鱼正常显示")

func _real_overlap() -> void:
 # 仅布置起始恢复倒计时，使鱼、鳗在真实计时中进入相交窗口。
 for i in 4:
  var id := "fenshui_silverfish_%d" % (i+1)
  Fish.phase(baseline[Run.KEY].combat.actors[id], "recover", 0.6)
 await _reset(Vector2(1000,470))
 _check(Fish.vec(Run.snapshot(sm).combat.actors[FISH].position).distance_to(maze.player.position)<110.0, "组合起点在原有鱼触发距离内，不扩大游戏触发范围")
 section = "真实水纹保护泡范围电玩家攻击同场"
 recording = true
 last_frame = 0
 _check(await _wait_until(func():
  var c: Dictionary = Run.snapshot(sm).combat
  return c.actors[FISH].get("fish_phase","")=="warning" and c.actors[EEL].get("eel_phase","")=="charging" and c.actors[EEL].eel_left<0.3, 180), "真实计时进入鱼预警与鳗蓄电同帧窗口")
 await _send_key(KEY_2)
 await _attack_click()
 await _settle()
 var live: Dictionary = Run.snapshot(sm)
 var bubbles := 0
 for node in maze.capture_flow.monsters.values():
  if is_instance_valid(node.membrane) and node.membrane.is_visible_in_tree(): bubbles += 1
 var eel_phase: String = live.combat.actors[EEL].get("eel_phase","")
 _check(_visible_warnings().size()>0 and bubbles>0 and maze.capture_flow.skill_visual.hero.is_visible_in_tree() and eel_phase in ["charging","discharge"], "同一帧确有鱼预警、保护泡、范围电与玩家攻击", {"warnings":_visible_warnings().size(), "bubbles":bubbles, "eel_phase":eel_phase, "action":live.combat.action, "action_left":live.combat.action_left})
 await _image("actual_four_effects_overlap")
 _check(await _wait_until(func(): return Run.snapshot(sm).combat.actors[FISH].get("fish_phase","")!="warning", 180), "真实计时结束鱼预警")
 await _settle()
 _check(not warning_visual.get_node(FISH).visible, "真实冲刺开始后水纹无残留")
 await _close_pending_captures()
 var elapsed: float = Run.snapshot(sm).combat.elapsed
 var position_before: Vector2 = maze.player.position
 await _hold(KEY_LEFT, 0.2)
 _check(maze.player.position.distance_to(position_before)>5 and Run.snapshot(sm).combat.elapsed>elapsed and not maze.player.input_locked, "同帧组合结束后实际移动与战斗时间继续")
 _check(not invalid_seen and Run.valid(Run.snapshot(sm)), "新水纹组合全过程保持合法战斗状态")
 _check(not frame_ms.is_empty() and frame_ms.max()<250.0, "真实四类效果同帧交互保留250毫秒门槛", {"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
 recording = false

func _visible_warnings() -> Array:
 var result: Array = []
 for child in warning_visual.get_children():
  if child is Sprite2D and child.is_visible_in_tree() and child.texture != null and child.texture.resource_path == WARNING_TEXTURE:
   result.append(child)
 return result
