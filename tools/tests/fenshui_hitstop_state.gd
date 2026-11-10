extends "res://tools/tests/ch2_entry_state.gd"
## 从真实探索保存事务验证局部时间线，不伪造伤害回执。
const Run = preload("res://scripts/maze/capture_run.gd")
const Fish = preload("res://scripts/maze/silverfish_combat.gd")
const ID = "fenshui_silverfish_1"
const POINT = Vector2(880,490)
var timing: RefCounted
var baseline: Dictionary
var measurements: Array=[]
@export var ranged_boundary:=false

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(), "只使用独立试玩存档")
 if failures==0:
  _completed()
  sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
  sm.cancel_maze_entry()
  _check(Run.begin(sm,Roads.SPAWN).success,"真实建立探索")
  var run: Dictionary=Run.snapshot(sm)
  Run.ensure_region(run,"fenshui")
  run.combat.fs01_trial=false
  run.combat.cooldown=0.0
  run.combat.selected=2
  for id in run.monsters: run.monsters[id].status="alive" if id==ID else "skipped"
  var a: Dictionary=run.combat.actors[ID]
  a.position=[920.0,440.0]
  a.fish_origin=a.position.duplicate()
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  Fish.phase(a,"recover",2.5)
  sm.data[Run.KEY]=run
  _check(sm.record_maze_location("fenshui",POINT).success,"实际进入分水庭合法站位")
  baseline=sm.data.duplicate(true)
  _scenarios()
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"measurements":measurements},"	"))
 print("铁山停顿事务检查：",checks,"项，失败",failures)
 get_tree().quit(1 if failures else 0)

func _scenarios() -> void:
 if ranged_boundary:
  _ranged_boundary()
 else:
  for milliseconds in [0,40,70]: _case(milliseconds)
  _miss()
  _multiple()
  _save_failure()

func _ranged_boundary() -> void:
 # 仅测当前正式行为的时钟关联；不假称远程停顿已经实现。
 for slot in [0,1]:
  _reset_clock(0)
  _check(Run.combat_command(sm,"select",slot).success,"真实选择远程攻击："+str(slot))
  _check(Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440))).success,"真实发射远程攻击："+str(slot))
  for i in 80:
   _check(_tick(0.01).success,"推进在途远程攻击："+str(slot))
   if Run.snapshot(sm).combat.actors[ID].hp<20: break
  var hit: Dictionary=Run.snapshot(sm).combat.duplicate(true)
  _check(hit.actors[ID].hp<20 and hit.actors[ID].hit_remaining>0.0,"先实际命中并出现原受击区间："+str(slot))
  if hit.actors[ID].hp>=20: continue
  for i in 3: _check(_tick(0.01).success,"观察原受击区间内技能计时："+str(slot))
  var during: Dictionary=Run.snapshot(sm).combat.duplicate(true)
  _check(is_equal_approx(during.actors[ID].fish_left,hit.actors[ID].fish_left),"当前普通鱼受击期间原技能阶段不推进："+str(slot))
  _check(during.actors[ID].position!=hit.actors[ID].position and during.actors[ID].hit_remaining<hit.actors[ID].hit_remaining,"该区间真实推进击退而非地图暂停："+str(slot))
  _check(during.cooldown<hit.cooldown and during.elapsed>hit.elapsed,"同时玩家原冷却及全场时间继续："+str(slot))
  for i in 15: _check(_tick(0.01).success,"原受击区间结束后继续模拟："+str(slot))
  var after: Dictionary=Run.snapshot(sm).combat.duplicate(true)
  _check(after.actors[ID].fish_left<during.actors[ID].fish_left,"原受击区间结束后普通鱼技能阶段才续走："+str(slot))
  measurements.append({"attack_slot":slot,"implemented_ranged_hitstop_ms":0,"hit":hit.actors[ID],"during_recoil":during.actors[ID],"after_recoil":after.actors[ID],"player_cooldown_before":hit.cooldown,"player_cooldown_during":during.cooldown})

func _tick(dt: float) -> Dictionary:
 var args: Array=[sm,POINT,dt,Rect2(),false]
 if timing!=null: args.append(timing)
 var advance: Callable=Run.combat_tick
 return advance.callv(args)

func _reset_clock(milliseconds: int) -> void:
 sm.data=baseline.duplicate(true)
 timing=null
 if ResourceLoader.exists("res://scripts/maze/axe_hitstop.gd"):
  timing=load("res://scripts/maze/axe_hitstop.gd").new()
  timing.configure(milliseconds)

func _until_hit() -> Dictionary:
 _check(Run.combat_attack(sm,POINT,Vector2.RIGHT).success,"真实旋斧出手")
 var hp: float=Run.snapshot(sm).combat.actors[ID].hp
 for i in 30:
  _check(_tick(0.01).success,"真实推进命中前事务")
  if Run.snapshot(sm).combat.actors[ID].hp<hp: break
 var hit: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 _check(hit.actors[ID].hp<hp,"先实际扣血才观察停顿")
 return hit

func _case(milliseconds: int) -> void:
 _reset_clock(milliseconds)
 var start: float=Run.snapshot(sm).combat.elapsed
 var hit:=_until_hit()
 _check(_tick(0.02).success,"命中后真实事务继续推进")
 var after: Dictionary=Run.snapshot(sm).combat
 var held: bool=is_equal_approx(after.action_left,hit.action_left) and after.actors[ID].position==hit.actors[ID].position
 _check(held==(milliseconds>0),"档位实际决定是否同时停住动作与击退："+str(milliseconds),{"before_action":hit.action_left,"after_action":after.action_left,"before_position":hit.actors[ID].position,"after_position":after.actors[ID].position})
 _check(is_equal_approx(after.actors[ID].flash_remaining,hit.actors[ID].flash_remaining)==(milliseconds>0),"白闪跟随同一局部时钟："+str(milliseconds))
 _check(after.elapsed>hit.elapsed and after.cooldown<hit.cooldown,"场景时间和原攻击冷却继续")
 var ticks:=0
 while Run.snapshot(sm).combat.action_left>0.000001 and ticks<70:
  _tick(0.01)
  ticks+=1
 var end: Dictionary=Run.snapshot(sm).combat
 var actual: float=end.elapsed-start
 _check(absf(actual-(0.48+float(milliseconds)/1000.0))<0.01001,"旋斧原速续播的模拟总时长："+str(milliseconds),{"simulation_seconds":actual})
 _check(end.hits==hit.hits and end.actors[ID].hp==hit.actors[ID].hp,"恢复不重复伤害："+str(milliseconds))
 _check(end.actors[ID].hit_remaining<=0.000001 and end.actors[ID].flash_remaining<=0.000001,"击退和白闪正常结束："+str(milliseconds))
 _check(Run.valid(Run.snapshot(sm)),"局部时钟不破坏探索状态："+str(milliseconds))
 measurements.append({"candidate_ms":milliseconds,"simulation_action_seconds":actual,"damage":baseline[Run.KEY].combat.actors[ID].hp-hit.actors[ID].hp})

func _miss() -> void:
 _reset_clock(70)
 sm.data[Run.KEY].combat.actors[ID].position=[1080.0,440.0]
 var before: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 _check(Run.combat_attack(sm,POINT,Vector2.RIGHT).success,"打空样例真实出手")
 for i in 48: _tick(0.01)
 var c: Dictionary=Run.snapshot(sm).combat
 _check(c.hits==before.hits and c.actors[ID].hp==before.actors[ID].hp,"打空不扣血、不新增命中")
 _check(c.action_left<0.000001 and timing.state.serial==-1,"打空不增加动作时长或触发停顿")

func _multiple() -> void:
 _reset_clock(70)
 var run: Dictionary=sm.data[Run.KEY]
 var other: String="fenshui_silverfish_2"
 var outside: String="fenshui_silverfish_3"
 for pair in [[other,[850.0,440.0]],[outside,[1100.0,440.0]]]:
  run.monsters[pair[0]].status="alive"
  var a: Dictionary=run.combat.actors[pair[0]]
  a.position=pair[1]
  a.fish_origin=a.position.duplicate()
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  Fish.phase(a,"recover",2.5)
 var hit:=_until_hit()
 _check(hit.actors[other].hp<20 and timing.state.ids.size()==2,"原周身规则同时命中前后两只鱼")
 _check(is_equal_approx(timing.state.left,0.07),"同击两目标只启动一次70毫秒停顿")
 _tick(0.02)
 var held: Dictionary=Run.snapshot(sm).combat
 _check(held.actors[ID].position==hit.actors[ID].position and held.actors[other].position==hit.actors[other].position,"多个命中目标同步保持位置")
 _check(held.actors[outside].fish_left<hit.actors[outside].fish_left,"未命中目标继续自身行动")
 for dt in [0.013,0.017,0.023]: _tick(dt)
 var resumed: Dictionary=Run.snapshot(sm).combat
 _check(timing.state.left<=0.000001 and resumed.action_left<hit.action_left,"不规则时间步按秒消耗、越过70毫秒即续播")
 _check(resumed.actors[ID].position!=hit.actors[ID].position,"恢复后实际击退继续，不加速追赶")

func _save_failure() -> void:
 _reset_clock(40)
 _check(Run.combat_attack(sm,POINT,Vector2.RIGHT).success,"保存失败对照先真实出手")
 for i in 17: _tick(0.01)
 var before: Dictionary=sm.data.duplicate(true)
 var clock: Dictionary=timing.state.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 var result:=_tick(0.01)
 _check(not result.success and sm.data==before and timing.state==clock,"命中事务保存失败同时保留原生命与局部时钟")
 sm._active_save_path=path
 _check(_tick(0.01).success and timing.state.left>0.0,"保存恢复后同一命中正常触发一次停顿")
 _check(not sm.data[Run.KEY].combat.has("axe_hitstop"),"对照状态不新增探索存档字段")
