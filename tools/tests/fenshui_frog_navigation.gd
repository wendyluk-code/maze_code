extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const Path=preload("res://scripts/maze/frog_water_path.gd")
const Frog=preload("res://scripts/maze/wind_frog_combat.gd")
const FIXTURES="res://tools/tests/fixtures/fenshui_frog_navigation/"

func restore(name: String) -> void:
 sm.data=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+name+".json"))

func simulate(point: Vector2,seconds: float) -> Dictionary:
 var origin:=Run.Combat.vec(actor().position)
 var progress:=origin.distance_to(point)
 var maximum:=0.0
 var zero_steps:=0
 var return_steps:=0
 var max_us:=0
 var success:=true
 var previous:=""
 for i in int(seconds/0.05):
  var started:=Time.get_ticks_usec()
  var result:=Run.combat_tick(sm,point,0.05,Rect2(0,0,1715,917))
  max_us=maxi(max_us,Time.get_ticks_usec()-started)
  if not result.success:
   trace.append({"transaction_failure":result,"time":(i+1)*0.05})
   success=false
   break
  var a:=actor()
  if a.mode=="return": return_steps+=1
  maximum=maxf(maximum,origin.distance_to(Run.Combat.vec(a.position)))
  progress=minf(progress,Run.Combat.vec(a.position).distance_to(point))
  if a.frog_phase in ["warning","airborne","landing"] and Run.Combat.vec(a.frog_origin).distance_squared_to(Run.Combat.vec(a.frog_target))<0.01: zero_steps+=1
  if a.frog_phase!=previous:
   trace.append({"time":(i+1)*0.05,"actor":a.duplicate(true)})
   previous=a.frog_phase
  # 本样例验证实际导航，不要求玩家站桩承受完整12秒；战败是原事务的合法终态。
  if state().combat.hp<=0.0:
   trace.append({"terminal":"player_defeated","time":(i+1)*0.05,"hp":state().combat.hp})
   break
 var result:={"success":success,"max_displacement":maximum,"closest_to_hero":progress,"zero_jump_steps":zero_steps,"return_steps":return_steps,"max_tick_ms":max_us/1000.0,"end":actor().duplicate(true)}
 trace.append(result)
 return result

func _run() -> void:
 sm=get_node("/root/SaveManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"导航回归隔离用户存档")
 restore("north")
 _check(Run.valid(state()),"冻结北部真实七怪检查点有效")
 var target:=Run.Combat.vec(state().combat.hero)
 var start_distance:=Run.Combat.vec(actor().position).distance_to(target)
 var north:=simulate(target,12.0)
 _check(north.success,"北部从公开事务推进成功")
 _check(north.max_displacement>24.0 and north.closest_to_hero<start_distance-24.0,"北部真实卡点实际绕行靠近玩家，不用永久待机或回家冒充追击",north)
 _check(north.zero_jump_steps==0,"北部旧零距离预警立即恢复，后续不安排零距离跳",north)
 _check(north.return_steps==0,"北部已能在水中攻击玩家时，不因吐水冷却反复回家再追出",north)
 restore("shallow")
 _check(Run.valid(state()),"冻结浅滩实走检查点有效")
 var shallow:=simulate(Run.Combat.vec(state().combat.hero),12.0)
 _check(shallow.success,"浅滩从公开事务推进成功")
 _check(actor().mode=="idle" and Run.Combat.vec(actor().position).distance_to(Boss.HOME)<2.0,"浅滩保护区玩家不再触发追击，巨蛙合法回到中央",shallow)
 _check(shallow.zero_jump_steps==0,"浅滩旧卡点及返回途中都不重复零距离跳",shallow)
 for phase in ["warning","airborne","landing"]:
  restore("north")
  var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
  a.frog_phase=phase
  a.frog_left=0.6
  _check(Run.valid(state()),"旧零跳检查点可被原存档读取："+phase)
  _check(sm.save(),"实际保存旧零跳检查点："+phase)
  sm.load_data()
  _check(actor().frog_phase==phase and Run.valid(state()),"从隔离存档重新载入旧零跳阶段："+phase)
  var legacy:=simulate(target,0.1)
  _check(legacy.success and legacy.zero_jump_steps==0 and Run.valid(state()),"实际推进恢复旧零跳检查点："+phase,legacy)
 restore("north")
 var same:=Run.Combat.vec(actor().position)
 var waiting:=simulate(same,3.0)
 _check(waiting.success and waiting.zero_jump_steps==0,"玩家贴在同一落点时也不制造零距离跳",waiting)
 _check(waiting.return_steps==0 and waiting.max_displacement<0.01,"同一合法攻击点等待完整原冷却后仍不假跳或无故回家",waiting)
 var resumed:=simulate(target,6.0)
 _check(resumed.success and resumed.max_displacement>24.0 and resumed.zero_jump_steps==0,"玩家重新进入可追击水域后自动恢复合法追击",resumed)
 _finish()
