extends "res://tools/tests/ch2_entry_state.gd"
## 同一真实入口的激活前后最小对照；不改游戏状态，不运行整段动作。
const Run=preload("res://scripts/maze/capture_run.gd")
const Aim=preload("res://scripts/maze/auto_aim.gd")
const Frog=preload("res://data/maze/fenshui_boss.gd")
var entry: Node
var maze: Node2D
var controls: Node
var trace: Array=[]
var started:=0

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 started=Time.get_ticks_usec()
 _check(_verify_isolation(),"最小激活验证使用隔离存档")
 _check(get_window().mode==Window.MODE_MINIMIZED and get_window().unfocusable,"测试启动即最小化不可聚焦")
 entry=load("res://tools/previews/fenshui_frog_motion.tscn").instantiate()
 get_tree().root.add_child(entry)
 # 地图同步加载后入口还需两帧初始化；加载耗时不能吃掉这两帧。
 var loading_started:=Time.get_ticks_msec()
 var loading_frames:=0
 var until:=loading_started+15000
 while entry.controls==null and loading_frames<90 and Time.get_ticks_msec()<until:
  await get_tree().process_frame
  loading_frames+=1
 _check(entry.controls!=null,"相同真实演示入口完成加载",{"loading_ms":Time.get_ticks_msec()-loading_started,"loading_frames":loading_frames})
 if entry.controls==null:
  _finish()
  return
 maze=entry.maze
 controls=entry.controls
 controls.playing=false
 # 入口会自动展示第一姿态；同步退出，不经过一帧推进，再观察本次F7前。
 maze.capture_flow.window_focused=true
 controls.resume_combat()
 _sample("本次F7前，入口自动演示已同步退出且未推进")
 var baseline: Dictionary=Run.snapshot(sm)
 _key(KEY_F7)
 _check(controls.active and not maze.capture_flow.is_processing(),"真实F7暂停战斗，仅显示单姿态")
 _key(KEY_F9)
 _sample("F9后立即，尚未推进")
 var immediate: Dictionary=Run.snapshot(sm)
 _check(immediate==baseline and not controls.active and not maze.player.input_locked,"F9保持原状态并释放演示锁")
 _check(immediate.combat.actors[Frog.ID].frog_phase=="dormant" and Aim.target(immediate,maze.player.position).is_empty(),"负向检查：待机仍不可选中，不强设活动")
 var first:=false
 var active:=false
 until=Time.get_ticks_msec()+3000
 while Time.get_ticks_msec()<until:
  await get_tree().process_frame
  var state: Dictionary=Run.snapshot(sm)
  if not first and float(state.combat.elapsed)>float(baseline.combat.elapsed):
   first=true
   _sample("首个成功普通推进")
  if state.combat.actors[Frog.ID].frog_phase not in ["dormant","emerging"]:
   active=true
   _sample("原规则自然激活")
   break
 _check(first and active,"有界等待中由原规则自然激活，不写阶段或站位")
 var ready: Dictionary=Run.snapshot(sm)
 _check(Aim.target(ready,maze.player.position)==Frog.ID,"自然激活后同一巨蛙可自动瞄准")
 if not active or Aim.target(ready,maze.player.position)!=Frog.ID:
  _finish()
  return
 var hp: float=ready.combat.actors[Frog.ID].hp
 var throws: int=int(ready.combat.throws)
 var hits: int=int(ready.combat.hits)
 for pressed in [true,false]:
  var click:=InputEventMouseButton.new()
  click.button_index=MOUSE_BUTTON_LEFT
  click.position=Vector2(850,400)
  click.pressed=pressed
  get_viewport().push_input(click)
 _sample("真实左键出手当刻")
 var fired: Dictionary=Run.snapshot(sm)
 _check(int(fired.combat.throws)==throws+1 and fired.combat.shots.size()==1,"只发射一次原锅铲")
 var damage: float=float(fired.combat.shots[0].damage) if fired.combat.shots.size()==1 else -1.0
 until=Time.get_ticks_msec()+1200
 while Time.get_ticks_msec()<until and Run.snapshot(sm).combat.actors[Frog.ID].hp==hp: await get_tree().process_frame
 _sample("首次实际伤害或条件等待到期")
 var after: Dictionary=Run.snapshot(sm)
 _check(damage>0 and is_equal_approx(hp-float(after.combat.actors[Frog.ID].hp),damage),"一次命中扣除原弹体携带的伤害，无额外扣血",{"before":hp,"after":after.combat.actors[Frog.ID].hp,"original_projectile_damage":damage})
 _check(int(after.combat.hits)==hits+1 and int(after.combat.throws)==throws+1,"命中及出手序号各只增加一次")
 _finish()

func _key(key: Key) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=key
  event.physical_keycode=key
  event.pressed=pressed
  get_viewport().push_input(event)

func _sample(label: String) -> void:
 var run: Dictionary=Run.snapshot(sm)
 var c: Dictionary=run.combat
 var a: Dictionary=c.actors[Frog.ID]
 var terrain: RefCounted=sm.maze_terrain("fenshui")
 trace.append({"point":label,"us":Time.get_ticks_usec()-started,"phase":a.frog_phase,"hp":a.hp,"mode":a.mode,"story":sm.yufeng_salia_state(),"unlocked":c.get("frog_unlocked",false),"encounter":c.get("frog_encounter",false),"walkable":terrain.is_walkable(maze.player.position),"terrain_multiplier":terrain.terrain_multiplier(maze.player.position),"hero":[maze.player.position.x,maze.player.position.y],"frog":a.position.duplicate(),"elapsed":c.elapsed,"combat_accumulator":maze.capture_flow.combat_time,"paused":maze.capture_flow.combat_paused(),"flow_processing":maze.capture_flow.is_processing(),"focused":maze.capture_flow.window_focused,"locked":maze.player.input_locked,"player_physics":maze.player.is_physics_processing(),"busy":maze.capture_flow.busy,"map_expanded":maze.map_ui.expanded,"target":Aim.target(run,maze.player.position),"phase_targetable":Run.Catalog.targetable(c,Frog.ID),"throws":c.throws,"hits":c.hits,"selected":c.selected})

func _finish() -> void:
 if is_instance_valid(maze): maze.capture_flow.set_process(false)
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"trace":trace},"  "))
 get_tree().quit(1 if failures else 0)
