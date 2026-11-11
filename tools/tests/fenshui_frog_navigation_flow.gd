extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const FIXTURES="res://tools/tests/fixtures/fenshui_frog_navigation/"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实七怪场景完成原入场")
 var frog: Node=maze.capture_flow.monsters[Boss.ID]
 _check(frog.enable_frog_front24(),"复用当前已认可双前向动作，不换美术")
 for point in [Vector2(880,565),Vector2(881,594),Vector2(857,659),Vector2(836,739),Vector2(840,746),Vector2(920,782),Vector2(956,778)]:
  _check(await walk_to(point,7.0),"真实内部输入沿既有岸路到达"+str(point),{"hero":str(maze.player.position)})
  if failures: return
 await picture("shallow_arrival")
 var shallow:=await observe("浅滩实走",8.0)
 _check(shallow.zero_jumps==0,"七怪浅滩实走没有零距离起落",shallow)
 _check(actor().mode=="idle" and actor().frog_phase=="dormant" and Boss.allowed(Run.Combat.vec(actor().position)),"玩家停在保护区时巨蛙在合法水面落稳待机，新版不要求回中央",shallow)
 var rest:=Run.Combat.vec(actor().position)
 await picture("shallow_returned")
 _check(await walk_to(Vector2(920,782),4.0),"从浅滩实走到明确干岸")
 await observe("相邻干岸",3.0)
 _check(actor().mode=="idle" and actor().frog_phase=="dormant" and Boss.allowed(Run.Combat.vec(actor().position)) and Run.Combat.vec(actor().position).distance_to(rest)<0.01,"相邻干岸保持合法待机落点，不反复回中央或无故位移")
 # 此用例验重新入水追击，不要求直穿已经落在(880,496)附近的实体巨蛙。
 _check(Boss.water(Vector2(880,540)),"返回检查点本身是原合法水域，不靠放宽地形")
 for point in [Vector2(840,746),Vector2(836,739),Vector2(857,659),Vector2(881,594),Vector2(880,565),Vector2(880,540)]:
  _check(await walk_to(point,7.0),"玩家真实走回原合法水域"+str(point),{"hero":str(maze.player.position)})
  if failures: return
 _check(await until_true(func(): return actor().mode=="chase" and actor().frog_phase=="airborne" and actor().frog_origin!=actor().frog_target,5.0),"离开保护区后恢复真实非零距离追击和起跳")
 await picture("water_chase_resumed")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"真实地图按钮暂停导航")
 var frozen: Dictionary=actor().duplicate(true)
 var clock: float=state().combat.elapsed
 await get_tree().create_timer(0.3).timeout
 _check(actor()==frozen and state().combat.elapsed==clock,"暂停时原位置、跳跃剩时和战斗时钟全部冻结")
 await key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"关闭地图恢复")
 _check(await until_true(func(): return state().combat.elapsed>clock,1.0),"恢复后真实战斗时钟继续推进")
 # 恢复完整原档而非单独挪动/清除怪物，覆盖用户北部实际卡住检查点。
 maze.capture_flow.set_process(false)
 sm.data=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"north.json"))
 maze.player.position=Run.Combat.vec(state().combat.hero)
 maze.camera.snap_to_target()
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 var north:=await observe("北部真实档恢复",10.0)
 _check(north.zero_jumps==0 and north.max_displacement>24.0 and north.closest_to_hero<north.start_distance-24.0,"北部同档在真实七怪场景实际绕行追近，不用回家或永久待机代替",north)
 _check(north.return_samples==0,"北部真实场景到达合法攻击位置后等待原冷却，不反复回家",north)
 _check(maze.capture_flow.monsters.size()==7 and Run.valid(state()),"场景末尾七只怪物仍在且原状态合法")
 await picture("north_recovered")

func release_move() -> void:
 for action in ["ui_up","ui_down","ui_left","ui_right"]: Input.action_release(action)

func walk_to(target: Vector2,seconds: float) -> bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
 while maze.player.position.distance_to(target)>4.0 and Time.get_ticks_msec()<deadline:
  var direction: Vector2=maze.player.position.direction_to(target)
  Input.action_press("ui_right",maxf(direction.x,0.0))
  Input.action_press("ui_left",maxf(-direction.x,0.0))
  Input.action_press("ui_down",maxf(direction.y,0.0))
  Input.action_press("ui_up",maxf(-direction.y,0.0))
  await get_tree().physics_frame
 release_move()
 await get_tree().physics_frame
 return maze.player.position.distance_to(target)<=5.0

func observe(label: String,seconds: float) -> Dictionary:
 var start:=Run.Combat.vec(actor().position)
 var distance:=start.distance_to(maze.player.position)
 var closest:=distance
 var maximum:=0.0
 var zeros:=0
 var returning:=0
 for i in int(seconds*10.0):
  await get_tree().create_timer(0.1).timeout
  var a:=actor()
  if a.mode=="return": returning+=1
  var pos:=Run.Combat.vec(a.position)
  maximum=maxf(maximum,start.distance_to(pos))
  closest=minf(closest,pos.distance_to(maze.player.position))
  if a.frog_phase in ["warning","airborne","landing"] and a.frog_origin==a.frog_target: zeros+=1
  trace.append({"case":label,"time":(i+1)*0.1,"hero":str(maze.player.position),"frog":a.duplicate(true)})
 var result:={"case":label,"max_displacement":maximum,"closest_to_hero":closest,"start_distance":distance,"zero_jumps":zeros,"return_samples":returning,"end":actor().duplicate(true)}
 trace.append(result)
 return result
