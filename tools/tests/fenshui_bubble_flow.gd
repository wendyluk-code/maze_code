extends "res://tools/tests/fenshui_area_flow.gd"
## 同一正式四鱼双鳗场景，基线只采集，接入验收检查玩家可见的泡膜。
@export var baseline_only := false

func _draw_samples() -> void:
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  get_window().size=size
  await _reset(Vector2(1040,490))
  maze.capture_flow.set_process(false)
  var run: Dictionary=Run.snapshot(sm)
  for id in Run.Catalog.Fenshui.all().map(func(row): return row.id):
   var node: Node=maze.capture_flow.monsters[id]
   node.position=Run.Combat.vec(run.combat.actors[id].position)
   node.sync_action(run.combat.actors[id],run.combat)
   node.set_process(true)
   _check(node.membrane.visible,"正式水中魔物具有保护膜："+id)
   if not baseline_only:
    _check(node.membrane.texture.resource_path=="res://assets/effects/fenshui/protection_bubble.png","实际使用用户认可的同一通用保护泡："+id)
    _check(not node.membrane.region_enabled,"通用泡不按怪物图集格子裁切："+id)
  # 预热与截图不计入连续帧样本；与旧版使用同一实际场景和数量。
  for i in 45: await get_tree().process_frame
  frame_ms.clear()
  last_frame=0
  section="保护泡连续帧"+str(size)
  recording=true
  for i in 180: await get_tree().process_frame
  recording=false
  var samples: Array=frame_ms.duplicate()
  samples.sort()
  area_events.append({"resolution":str(size),"monsters":6,"samples":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],"max_ms":samples.max()})
  _check(samples.max()<250.0,"实际四鱼双鳗连续帧保留250毫秒门槛",area_events.back())
  await _image("bubble_water_%dx%d" % [size.x,size.y])
  if not baseline_only: await _motion_check()

func _motion_check() -> void:
 var fish: Node=maze.capture_flow.monsters[FISH]
 var second: Node=maze.capture_flow.monsters["fenshui_silverfish_2"]
 var eel: Node=maze.capture_flow.monsters[EEL]
 _check(fish.membrane.texture==eel.membrane.texture,"鱼鳗共享同一张泡膜资源")
 var before: Transform2D=fish.membrane.transform
 var body_scale: Vector2=fish.body.scale
 var body_rotation: float=fish.body.rotation
 await get_tree().create_timer(0.35).timeout
 _check(not fish.membrane.transform.is_equal_approx(before),"水中泡膜实际轻微呼吸晃动")
 _check(fish.body.scale==body_scale and fish.body.rotation==body_rotation,"只动泡膜，不变形怪物本体")
 _check(not is_equal_approx(fish.membrane.rotation,second.membrane.rotation),"同类怪物的泡膜不同时晃动")
 _check(absf(fish.membrane.rotation)<=deg_to_rad(1.21),"泡膜轻摆不超过认可幅度")
 await _image("bubble_motion_"+str(get_window().size.x))
 maze.capture_flow.set_process(true)
 await _click(maze.map_ui.mini_button)
 _check(maze.map_ui.expanded,"真实地图面板打开")
 before=fish.membrane.transform
 await get_tree().create_timer(0.3).timeout
 _check(fish.membrane.transform==before,"地图暂停时泡膜完全冻结")
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"真实关闭地图恢复探索")
 maze.capture_flow.set_process(false)
 fish.set_process(true)
 fish.hide()
 before=fish.membrane.transform
 await get_tree().create_timer(0.2).timeout
 _check(fish.membrane.transform==before,"隐藏魔物不更新泡膜动画")
 fish.show()
 var point: Vector2=fish.position
 fish.position+=Vector2(5000,0)
 before=fish.membrane.transform
 await get_tree().create_timer(0.2).timeout
 _check(fish.membrane.transform==before,"画面外魔物不更新泡膜动画")
 fish.position=point
