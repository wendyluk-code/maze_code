extends "res://tools/tests/fenshui_flow.gd"
const Salt = preload("res://data/maze/salt_pool_roads.gd")

func _combat_scene() -> void:
 await _new_scene()
 maze.capture_flow.set_process(false)
 for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode = "idle"
 for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key] = []
 maze.travel_region("salt_pool", Vector2(850,500))
 await get_tree().create_timer(1.5).timeout
 maze = get_tree().current_scene
 _check(maze.region_id == "salt_pool" and maze._entry_ready,"进入真实盐池场景")
 if maze.region_id != "salt_pool":
  await _close_scene()
  return
 maze.capture_flow.set_process(false)
 maze.capture_flow.window_focused = true
 maze.player.input_locked = false
 var normal := _measure(Vector2(238,596),Vector2.RIGHT,false)
 var salt := _measure(Vector2(850,500),Vector2.RIGHT,false)
 var restored := _measure(Vector2(238,596),Vector2.RIGHT,false)
 _check(normal>0 and absf(salt/normal-0.5)<0.01,"盐地50%速度",{"road":normal,"salt":salt})
 _check(absf(restored-normal)<0.01,"土路100%速度恢复")
 maze.player.position = Vector2(850,500)
 maze.player.set_physics_process(false)
 maze.camera.snap_to_target()
 maze.set_process(false)
 maze.process_mode = Node.PROCESS_MODE_DISABLED
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var effects = maze.get_node("SaltGroundEffects")
 effects.set_process(false)
 effects.footprints.clear()
 effects._last = maze.player.position
 # 真实图形渲染，逐0.5秒采样覆盖完整10秒。关闭该效果节点的对照图仅用于量化白色覆盖。
 effects.hide()
 await RenderingServer.frame_post_draw
 var clear_image := get_viewport().get_texture().get_image()
 effects.show()
 var peak := 0
 for step in 21:
  if step>0:
   await get_tree().create_timer(0.5).timeout
   effects._process(0.5)
  await RenderingServer.frame_post_draw
  var frame := get_viewport().get_texture().get_image()
  var white_pixels := 0
  for y in range(100,frame.get_height()-100,3):
   for x in range(100,frame.get_width()-100,3):
    var a := frame.get_pixel(x,y)
    var b := clear_image.get_pixel(x,y)
    if a.r-b.r>0.025 and a.g-b.g>0.025 and a.b-b.b>0.025:
     white_pixels += 1
  peak = maxi(peak,white_pixels)
  if step in [0,8,20]: await _capture_image("cycle_%02d" % step)
 _check(peak==0,"完整10秒周期无白色蒙层",{"peak_white_samples":peak,"samples":21,"interval_seconds":0.5})
 maze.player._walking = true
 for i in 65:
  maze.player.position += Vector2(1,0)
  effects._process(0.01)
 _check(effects.footprints.size()>0,"盐地移动生成脚印")
 await _capture_image("footprints_created")
 maze.player._walking = false
 effects._process(3.0)
 _check(not effects.footprints.is_empty(),"3秒脚印尚未消失")
 await _capture_image("footprints_fading")
 effects._process(1.01)
 _check(effects.footprints.is_empty(),"4秒脚印消退")
 await _capture_image("footprints_expired")
 maze.map_ui.open_map()
 _check(maze.map_ui.expanded,"保留地图")
 await _capture_image("map")
 maze.map_ui.close_map()
 await _close_scene()
