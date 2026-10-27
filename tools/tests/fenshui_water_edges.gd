extends "res://tools/tests/combat_07_flow.gd"
const FS = preload("res://data/maze/fenshui_roads.gd")
func _combat_scene() -> void:
 await _new_scene()
 maze.capture_flow.set_process(false)
 for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode = "idle"
 for key in ["shots","enemy_shots"]: sm.data[Run.KEY].combat[key] = []
 _check(Run.change_region(sm,"fenshui",Vector2(920,440)).success,"进入分水庭")
 await _close_scene()
 maze = load(sm.resume_scene_path()).instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene = maze
 await get_tree().process_frame
 maze.capture_flow.set_process(false)
 maze.capture_flow.window_focused = true
 maze.player.set_physics_process(true)
 for p in [Vector2(1370,451),Vector2(1455,476)]:
  _check(FS.is_walkable(p) and FS.terrain_multiplier(p)==1.0,"右圈道路100%"+str(p))
 _check(FS.is_walkable(Vector2(906,636)) and FS.terrain_multiplier(Vector2(906,636))==0.65,"左圈补齐浅水65%")
 var seam_ok := true
 var checked := 0
 for i in 181:
  var p := Vector2(1290,427).lerp(Vector2(1438,447),float(i)/180.0)
  for dy in range(-5,6):
   var sample := p+Vector2(0,dy)
   checked += 1
   if not FS.is_walkable(sample) or FS.terrain_multiplier(sample)!=1.0: seam_ok=false
 _check(seam_ok,"道路接缝连续扫描1991点",{"samples":checked})
 var n := 0
 for polygon in FS.WATER_EDGES:
  var found := false
  for vertex in polygon:
   if found: break
   var center := Vector2.ZERO
   for p in polygon: center += p
   center /= polygon.size()
   var sample: Vector2 = vertex.lerp(center,0.55)
   if not FS.is_water_edge(sample,4.1): continue
   maze.player.position = sample
   maze.player.input_locked = false
   Input.action_press("ui_right")
   maze.player._physics_process(0.01)
   Input.action_release("ui_right")
   _check(maze.player.position.distance_to(sample)>0.1,"绿圈实际可移动"+str(n))
   _check(FS.terrain_multiplier(sample)==0.65,"绿圈浅水速度"+str(n))
   found = true
  _check(found,"绿圈存在安全脚底站位"+str(n))
  n+=1
 for p in [Vector2(650,245),Vector2(1000,337),Vector2(544,381),Vector2(1373,326)]:
  _check(not FS.is_walkable(p),"岛体主体仍阻挡"+str(p))
 for gate in maze.FenshuiGates.GATES:
  _check(not FS.is_walkable(maze.FenshuiGates.center(gate)),"栅栏仍阻挡"+gate.name)
 maze.player.position = Vector2(1188,793)
 maze.camera.snap_to_target()
 await _capture_image("water_edge_south")
 if suffix == "_1152x648":
  var base: Image = load("res://assets/maps/fenshui_fences.png").get_image()
  base.resize(1715,917)
  base.convert(Image.FORMAT_RGBA8)
  for y in range(0,917,3):
   for x in range(0,1715,3):
    var p := Vector2(x,y)
    var c := Color(0.75,0.08,0.24,0.4)
    if FS.is_walkable(p): c = Color(0.0,0.65,1.0,0.45) if FS.terrain_multiplier(p)<1 else Color(1.0,0.85,0.0,0.45)
    for yy in range(y,mini(y+3,917)):
     for xx in range(x,mini(x+3,1715)): base.set_pixel(xx,yy,base.get_pixel(xx,yy).blend(c))
  base.save_png("res://output/fenshui/water_edges_updated.png")
 await _close_scene()
