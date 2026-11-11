extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Boss=preload("res://data/maze/salt_boss.gd")
var maze: Node2D
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"主区真实场景隔离存档")
 if failures==0:
  _completed()
  sm.cancel_maze_entry()
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  _check(Run.begin(sm,Roads.SPAWN).success,"初始化真实探索")
  _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"进入真实盐池")
  maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
  add_child(maze)
  await get_tree().process_frame
  await get_tree().process_frame
  maze.capture_flow.set_process(false)
  var node: Node=maze.capture_flow.monsters[Boss.ID]
  var c: Dictionary=sm.data[Run.KEY].combat
  var actor: Dictionary=c.actors[Boss.ID]
  actor.rock_phase="charge"
  actor.rock_left=1.1
  actor.rock_aim=[1.0,0.0]
  node.sync_action(actor,c)
  _check("roar_visual" in node and node.get("roar_visual")!=null,"前摇存在真实范围显示组件")
  if "roar_visual" in node and node.get("roar_visual")!=null:
   var visual: Node=node.roar_visual
   var before: Dictionary=visual.snapshot()
   _check(before.danger_visible and before.phase=="charge","前摇显示危险区")
   actor.rock_phase="lunge_charge"
   actor.rock_left=Run.Combat.Rock.LUNGE_DURATIONS.lunge_charge
   node.sync_action(actor,c)
   _check(not visual.snapshot().danger_visible and node.action=="charge" and node.frame_index()==0,"咆哮转冲撞前摇立即清除预警并消费真实时钟")
   actor.rock_phase="lunge"
   actor.rock_left=Run.Combat.Rock.LUNGE_DURATIONS.lunge*0.5
   node.sync_action(actor,c)
   _check(node.action=="rush" and node.frame_index()==2,"真实冲撞阶段使用冲刺图集")
   actor.rock_phase="stunned"
   actor.rock_left=1.5
   node.sync_action(actor,c)
   _check(node.action=="charge" and node.frame_index()==3,"撞障碍眩晕保持蓄力末帧")
   actor.rock_phase="charge"
   actor.rock_left=1.1
   node.sync_action(actor,c)
   _check(before.origin==Run.Combat.vec(actor.position),"预警中心与真实脚底相同")
   var shape:=Run.Combat.Rock.RoarArea.polygon(before.origin,Vector2.RIGHT)
   var same: bool=shape.size()==before.shape.size()
   for i in shape.size(): same=same and shape[i].is_equal_approx(before.shape[i]+before.origin)
   _check(same,"真实显示轮廓与伤害轮廓逐点相同")
   actor.rock_phase="rush"
   actor.rock_left=0.3
   node.sync_action(actor,c)
   _check(visual.snapshot().shape==before.shape,"释放与前摇共用同一轮廓")
   actor.rock_phase="rest"
   actor.rock_left=1.5
   node.sync_action(actor,c)
   _check(visual.snapshot().rest_visible and not visual.snapshot().danger_visible,"休息显示机会且不留危险区")
   var frozen: Dictionary=visual.snapshot()
   get_tree().paused=true
   await get_tree().create_timer(0.1,true).timeout
   get_tree().paused=false
   _check(visual.snapshot()==frozen,"暂停不自行推进显示时钟")
   actor.hp=0
   node.sync_action(actor,c)
   _check(not visual.snapshot().rest_visible and not visual.snapshot().danger_visible,"死亡清理范围及机会")
   actor.hp=120
   actor.rock_phase="charge"
   node.sync_action(actor,c)
   node.hide()
   _check(not visual.snapshot().danger_visible,"隐藏立即清理范围")
   node.show()
   actor.rock_phase="active"
   actor.rock_left=0.0
   actor.mode="chase"
   actor.position=[850.0,425.0]
   actor.hit_remaining=0.0
   # 咆哮不再是唯一攻击；将其冷却设为到期以单独验证原咆哮行为。
   actor.rock_reuse=0.0
   var run: Dictionary=sm.data[Run.KEY]
   var point:=Vector2(980,425)
   var hp: float=c.hp
   Run.Combat.Rock.advance(run,point,0.01)
   _check(actor.rock_phase=="charge" and is_equal_approx(actor.rock_left,1.1),"真实进入1.1秒前摇")
   var locked: Array=actor.rock_aim.duplicate()
   Run.Combat.Rock.advance(run,Vector2(850,555),1.1)
   _check(c.hp==hp and actor.rock_aim==locked,"锁向后侧移避开且朝向不追踪")
   Run.Combat.Rock.advance(run,point,0.45)
   var rest: float=Run.Combat.Rock.Tuning.number("rock.roar","rest",1.5)
   _check(actor.rock_phase=="rest" and is_equal_approx(actor.rock_left,rest),"释放后进入当前配置的休息")
   Run.Combat.Rock.advance(run,point,rest-0.01)
   _check(actor.rock_phase=="rest" and c.hp==hp,"休息期不攻击")
   Run.Combat.Rock.advance(run,point,0.01)
   _check(actor.rock_phase=="active","休息结束恢复")
   actor.rock_reuse=0.0
   Run.Combat.Rock.advance(run,point,0.01)
   Run.Combat.Rock.advance(run,point,1.1)
   _check(c.hp<hp,"正前方真实结算扣血")
   _check(node.hit_visual.WIDTHS=={"hero":42.0,"yaya":42.0,"tieshan":54.0} and node.hit_visual.ratio==1.0,"岩鬃兽同招命中特效不随体型放大")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"  "))
 print("ROCK_FLOW ",checks," checks, ",failures," failures")
 get_tree().quit(1 if failures else 0)
