extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const FS=preload("res://data/maze/fenshui_roads.gd")
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
const Water=preload("res://data/maze/fenshui_encounters.gd")
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const Electric=preload("res://scripts/maze/fenshui_electric_area.gd")
const LOW=[0,4,5,2,6,10,11]
var navigation: Array=[]

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"v4真实七怪入口完成")
 maze.capture_flow.set_process(false)
 _check(maze.get_child(0).texture.resource_path=="res://assets/maps/fenshui_v4.png","正式场景加载已认可v4，而非旧底图")
 var fences: Node=maze.get_node("FenshuiFences")
 _check(fences.get_child_count()==5,"正式地图显示原五处已认可栅栏")
 for i in 5:
  var fence: Sprite2D=fences.get_child(i)
  _check(fence.position==FS.Gates.center(FS.Gates.GATES[i]) and fence.scale.x==fence.scale.y and fence.rotation==0,"五栏沿用原中心与等比朝向："+str(i))
  _check(fence.texture.resource_path.ends_with("fence-"+str(i+1)+".png"),"五栏独立切图接入："+str(i))
 for index in LOW:
  sm.data=entry_snapshot.duplicate(true)
  var island: Vector4=FS.ISLANDS[index]
  var center:=Vector2(island.x,island.y)
  maze.player.position=center+Vector2(0,island.w+18)
  var start: Vector2=maze.player.position
  Input.action_press("ui_up")
  var reached:=await until_true(func(): return maze.player.position.y<=center.y+2.0,1.6)
  Input.action_release("ui_up")
  _check(reached and absf(maze.player.position.x-center.x)<0.1,"真实内部持键可直接走上低台："+str(index),{"from":str(start),"actual":str(maze.player.position)})
  _check(FS.terrain_multiplier(maze.player.position)==1.0,"实机落脚为干地："+str(index))
  maze.camera.snap_to_target()
  await picture("platform-"+str(index))
  await lure_fish(index)
  await lure_eel(index)
  if failures: return
 await gates_and_restore()

func lure_fish(index: int) -> void:
 sm.data=entry_snapshot.duplicate(true)
 var island: Vector4=FS.ISLANDS[index]
 var center:=Vector2(island.x,island.y)
 var origin:=Vector2.ZERO
 for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
  var candidate: Vector2=center+direction*Vector2(island.z+35,island.w+35)
  if Water.water(candidate) and Fish.allowed(candidate):
   origin=candidate
   break
 _check(not origin.is_zero_approx(),"台外存在完整鱼体的合法浅水引怪点："+str(index))
 if origin.is_zero_approx(): return
 var run:=state()
 var fish: Dictionary=run.combat.actors["fenshui_silverfish_1"]
 fish.position=Run.Combat.pack(origin)
 fish.fish_phase="warning"
 fish.fish_left=0.1
 fish.windup=0.1
 fish.mode="windup"
 fish.fish_origin=fish.position.duplicate()
 fish.fish_aim=Run.Combat.pack(origin.direction_to(center))
 fish.fish_hit=false
 sm.data[Run.KEY]=run
 _check(Run.valid(state()),"七怪合法引鱼检查点："+str(index))
 var stranded:=false
 var okay:=true
 for i in 40:
  var result:=Run.combat_tick(sm,center,0.05,Rect2(0,0,1715,917))
  if not result.success:
   okay=false
   break
  if state().combat.actors["fenshui_silverfish_1"].get("fish_phase","")=="stranded":
   stranded=true
   break
 _check(okay and stranded,"真实锁向鱼冲上低台进入原搁浅阶段："+str(index),{"fish":state().combat.actors["fenshui_silverfish_1"]})
 if not stranded: return
 _check(not Fish.shielded(state().combat,"fenshui_silverfish_1"),"上台实际失去保护膜："+str(index))
 # 引鱼可能真实撞中玩家；等待原受击恢复，不为测试清除控制状态。
 for i in 12:
  if not Run.Combat.PlayerHurt.recovering(state().combat) and state().combat.cooldown<=0.00001: break
  if not Run.combat_tick(sm,center,0.05).success: okay=false
 var a: Dictionary=state().combat.actors["fenshui_silverfish_1"]
 var hp: float=a.hp
 var throws: int=state().combat.throws
 var attack:=Run.combat_attack(sm,center,center.direction_to(Run.Combat.vec(a.position)))
 _check(attack.success and state().combat.throws==throws+1,"干地上使用真实锅铲出手："+str(index))
 for i in 20:
  if state().combat.actors["fenshui_silverfish_1"].hp<hp: break
  if not Run.combat_tick(sm,center,0.02).success: okay=false
 _check(okay and state().combat.actors["fenshui_silverfish_1"].hp<hp,"石台目标可被真实投射物命中，不撞旧岛墙："+str(index))
 var phases: Array=[]
 var reformed:=false
 # 玩家移离脚底，验证原2.5秒搁浅及回水，不把玩家占位当寻路故障。
 var hero:=FS.SPAWN
 for i in 95:
  var result:=Run.combat_tick(sm,hero,0.05)
  if not result.success:
   okay=false
   break
  var current: Dictionary=state().combat.actors["fenshui_silverfish_1"]
  var phase: String=current.fish_phase
  if phases.is_empty() or phases.back()!=phase: phases.append(phase)
  if phase=="forming":
   reformed=true
   break
 _check(okay and reformed,"台上原停留结束后可实际回水并凝膜："+str(index),{"phases":phases,"fish":state().combat.actors["fenshui_silverfish_1"],"actors":state().combat.actors})
 var shape:=Electric.polygon(origin,"v4-platform-"+str(index))
 _check(not Electric.contains(shape,center),"真实范围电与干地共用裁切，不覆盖石台："+str(index))
 navigation.append({"platform":index,"origin":str(origin),"phases":phases,"returned":reformed})

func lure_eel(index: int) -> void:
 sm.data=entry_snapshot.duplicate(true)
 var island: Vector4=FS.ISLANDS[index]
 var center:=Vector2(island.x,island.y)
 var origin:=Vector2.ZERO
 for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
  var candidate: Vector2=center+direction*Vector2(island.z+35,island.w+35)
  if Water.water(candidate) and Fish.allowed(candidate):
   origin=candidate
   break
 var id:="fenshui_thunder_eel_2"
 var run:=state()
 var eel: Dictionary=run.combat.actors[id]
 eel.position=Run.Combat.pack(origin)
 eel.eel_origin=eel.position.duplicate()
 eel.eel_path=[]
 eel.eel_phase="chasing"
 eel.eel_left=0.0
 eel.mode="chase"
 eel.cooldown=0.0
 sm.data[Run.KEY]=run
 var okay:=true
 var stranded:=false
 for i in 60:
  if not Run.combat_tick(sm,center,0.05).success:
   okay=false
   break
  if state().combat.actors[id].get("eel_phase","")=="stranded":
   stranded=true
   break
 _check(okay and stranded,"雷鳗按原短追规则实际上低台："+str(index),{"eel":state().combat.actors[id]})
 if not stranded: return
 _check(not Eel.shielded(state().combat,id) and Eel.travelled(state().combat.actors[id])<=Eel.SHORE_LIMIT+0.001,"台上雷鳗失膜且不扩55像素岸行限制："+str(index))
 var reformed:=false
 for i in 110:
  if not Run.combat_tick(sm,FS.SPAWN,0.05).success:
   okay=false
   break
  if state().combat.actors[id].eel_phase=="forming":
   reformed=true
   break
 _check(okay and reformed,"雷鳗沿实际记录路径回水凝膜："+str(index),{"eel":state().combat.actors[id]})

func gates_and_restore() -> void:
 sm.data=entry_snapshot.duplicate(true)
 for gate in FS.Gates.GATES:
  var center: Vector2=FS.Gates.center(gate)
  var direction: Vector2=gate.a.direction_to(gate.b).orthogonal()
  var start:=center+direction*24.0
  if not FS.is_walkable(start):
   direction=-direction
   start=center+direction*24.0
  _check(FS.is_walkable(start),"栅栏近侧保留可走站位："+gate.name)
  var target:=FS.move_on_road(start,-direction*48.0)
  _check((target-center).dot(direction)>0,"接入新图后仍无法穿过原封路："+gate.name)
  maze.player.position=gate.front
  maze.camera.snap_to_target()
  await picture("gate-"+gate.name)
 var point:=Vector2(1000,337)
 _check(sm.record_maze_location("fenshui",point).success and sm.save(),"真实保存新低台站位")
 sm.load_data()
 _check(sm.maze_exploration_state().position==[point.x,point.y] and Run.valid(state()),"真实读回低台站位且保留原七怪状态")
 var old:=Vector2(1560,218)
 _check(sm.record_maze_location("fenshui",old).success and sm.save(),"原入口旧站位仍可保存")
 sm.load_data()
 _check(sm.maze_exploration_state().position==[old.x,old.y] and Run.valid(state()),"旧入口位置恢复不被新低台影响")
