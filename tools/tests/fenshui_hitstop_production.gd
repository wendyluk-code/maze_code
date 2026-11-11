extends "res://tools/tests/fenshui_ranged_hitstop_state.gd"
## 正常场景自行安装时钟，不借助试玩控件；存档只使用隔离目录。
var maze: Node2D

func _scenarios() -> void:
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 maze.capture_flow.set_process(false)
 timing=maze.capture_flow.axe_hitstop
 _check(timing!=null,"正常分水庭入口自行安装命中停顿，无需试玩控件")
 if timing==null: return
 _check(is_equal_approx(timing.state.duration,0.07) and is_equal_approx(timing.state.ranged_duration,0.05),"正常分水庭使用已认可远程50／铁山70")
 _check(not get_tree().root.find_children("*HitstopControls*","",true,false).size(),"正常地图无试玩切档控件")
 for slot in [0,1]: _remote_case(slot,50)
 _case(70)
 _save_reload()
 _frog_target()
 _eel_target()
 _other_region()

func _eel_target() -> void:
 sm.data=baseline.duplicate(true)
 var id: String="fenshui_thunder_eel_1"
 var run: Dictionary=sm.data[Run.KEY]
 for key in run.monsters: run.monsters[key].status="alive" if key==id else "skipped"
 var eel: Dictionary=run.combat.actors[id]
 eel.position=[920.0,440.0]
 var thunder=load("res://scripts/maze/thunder_eel_combat.gd")
 eel.eel_origin=eel.position.duplicate()
 eel.eel_path=[]
 thunder.phase(eel,"idle")
 timing=maze.capture_flow.axe_hitstop
 timing.configure(70)
 timing.configure_ranged(50)
 Run.combat_command(sm,"select",1)
 _check(Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440))).success,"正常分水庭芽芽可命中雷鳗")
 for i in 60:
  _tick(0.01)
  if Run.snapshot(sm).combat.actors[id].hp<30: break
 var hit: Dictionary=Run.snapshot(sm).combat.actors[id].duplicate(true)
 _check(hit.hp<30 and timing.paused(id),"雷鳗也由实际命中触发50毫秒")
 _tick(0.02)
 var held: Dictionary=Run.snapshot(sm).combat.actors[id]
 _check(held.position==hit.position and held.hit_remaining==hit.hit_remaining,"雷鳗实际击退在暂停中保持")

func _other_region() -> void:
 sm.data=baseline.duplicate(true)
 var other: Node2D=load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(other)
 other.capture_flow.set_process(false)
 _check(other.region_id=="maze_entry" and other.capture_flow.axe_hitstop!=null,"正常迷宫入口同样安装角色共用卡肉时钟")
 other.free()

func _frog_target() -> void:
 sm.data=baseline.duplicate(true)
 var id: String=Run.Catalog.Frog.ID
 var run: Dictionary=sm.data[Run.KEY]
 for key in run.monsters: run.monsters[key].status="alive" if key==id else "skipped"
 var frog: Dictionary=run.combat.actors[id]
 frog.position=[900.0,450.0]
 frog.frog_origin=frog.position.duplicate()
 frog.frog_target=frog.position.duplicate()
 frog.frog_phase="landing"
 frog.frog_left=0.8
 frog.mode="chase"
 frog.frog_shots=[{"position":[1000.0,460.0],"direction":[1.0,0.0],"distance":0.0}]
 timing=maze.capture_flow.axe_hitstop
 timing.configure(70)
 timing.configure_ranged(50)
 Run.combat_command(sm,"select",0)
 _check(Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(900,450))).success,"正常分水庭可向巨蛙发射原锅铲")
 for i in 60:
  _tick(0.01)
  if Run.snapshot(sm).combat.actors[id].hp<96: break
 var hit: Dictionary=Run.snapshot(sm).combat.actors[id].duplicate(true)
 _check(hit.hp<96 and timing.paused(id),"巨蛙也由实际命中触发同一50毫秒窗口")
 _tick(0.02)
 var held: Dictionary=Run.snapshot(sm).combat.actors[id]
 _check(held.position==hit.position and held.hit_remaining==hit.hit_remaining,"巨蛙实际受击位移不在暂停后台走完")
 _check(held.frog_shots[0].distance>hit.frog_shots[0].distance,"巨蛙已离体水团不随目标暂停")

func _save_reload() -> void:
 sm.data=baseline.duplicate(true)
 maze.capture_flow.axe_hitstop.configure(70)
 maze.capture_flow.axe_hitstop.configure_ranged(50)
 timing=maze.capture_flow.axe_hitstop
 Run.combat_command(sm,"select",1)
 var hit:=_remote_hit()
 _check(sm.save(),"正常命中状态能保存")
 var expected: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 sm.load_data()
 var actual: Dictionary=Run.snapshot(sm).combat
 var differences: Array=[]
 for key in expected:
  if JSON.parse_string(JSON.stringify(actual.get(key)))!=JSON.parse_string(JSON.stringify(expected[key])): differences.append(key)
 _check(differences.is_empty(),"读档不重复扣血、保留原攻击和受击状态",{"changed_fields":differences})
 var copy: Node2D=load("res://scenes/maze_fenshui.tscn").instantiate()
 get_tree().root.add_child(copy)
 copy.capture_flow.set_process(false)
 timing=copy.capture_flow.axe_hitstop
 _check(timing!=null and not timing.paused(ID),"重载重新安装50／70时钟，不重放旧命中暂停")
 if timing!=null:
  for i in 30: _tick(0.01)
  _check(Run.snapshot(sm).combat.hits==hit.hits and Run.snapshot(sm).combat.actors[ID].hp==19.0,"读档后续完原受击，不重复结算")
 copy.free()
