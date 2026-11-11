extends "res://tools/tests/fenshui_frog_counter_flow.gd"
var minimum:=INF
var overlaps: Array=[]
var samples:=0

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"统一七怪入口正常入场")
 _check(maze.capture_flow.monsters[Boss.ID].enable_frog_front24(),"统一七怪启用当前1.4倍双前向身体")
 maze.capture_flow.window_focused=true
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  maze.camera.snap_to_target()
  await key(KEY_TAB)
  for direction in ["ui_right","ui_down","ui_left","ui_up"]:
   Input.action_press(direction)
   for i in 45:
    await get_tree().physics_frame
    observe_occupancy()
   Input.action_release(direction)
  await picture("combined_"+str(size.x))
 _check(samples>=300,"七怪真实移动持续采样，不用静态摆图替代")
 _check(overlaps.is_empty(),"玩家/怪物及怪物彼此的落地脚底没有互穿",{"minimum_normalized_distance":minimum,"overlaps":overlaps.slice(0,10),"samples":samples})
 _check(maze.capture_flow.monsters.size()==7 and Run.valid(state()),"联合移动后真实七怪、保护膜及原战斗状态保持合法")

func observe_occupancy() -> void:
 var run:=state()
 var bodies: Array=[{"id":"hero","point":Run.Combat.vec(run.combat.hero),"size":Vector2(7,4)}]
 for id in run.combat.actors:
  if not str(id).begins_with("fenshui_") or run.monsters[id].status!="alive": continue
  var a: Dictionary=run.combat.actors[id]
  if a.hp<=0 or a.get("frog_phase","") in ["airborne","toppling"]: continue
  var size:=Vector2(38,20) if str(id).contains("wind_frog") else (Vector2(17,9) if str(id).contains("thunder_eel") else Vector2(10,7))
  bodies.append({"id":id,"point":Run.Combat.vec(a.position),"size":size})
 for i in bodies.size():
  for j in range(i+1,bodies.size()):
   var a: Dictionary=bodies[i]
   var b: Dictionary=bodies[j]
   var distance: float=((a.point-b.point)/(a.size+b.size)).length()
   minimum=minf(minimum,distance)
   if distance<0.99: overlaps.append({"a":a.id,"b":b.id,"distance":distance,"time":run.combat.elapsed})
 samples+=1
