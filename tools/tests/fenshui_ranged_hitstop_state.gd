extends "res://tools/tests/fenshui_hitstop_state.gd"
## 真实发射、扣血与保存事务；远程不冻结玩家动作。
var expected_remote_hp: float=19.0

func _scenarios() -> void:
 for slot in [0,1]:
  for ms in [0,30,50]:
   _remote_case(slot,ms)
   _remote_miss(slot,ms)
  _remote_save_failure(slot)
 _parallel_shots()
 _stage_delay()
 _without_controller()

func _remote_reset(slot: int, ms: int) -> void:
 _reset_clock(70)
 # 本组检查单颗弹体的停顿与回滚；默认/可配置多颗整轮由 yaya_burst 及 yaya_burst_flow 检查。
 var tuning=Run.Combat.Skills.Tuning
 if not tuning.values.has("effect.yaya"): tuning.values["effect.yaya"]={}
 tuning.values["effect.yaya"]["burst_count"]=1
 if timing.has_method("configure_ranged"): timing.configure_ranged(ms)
 _check(Run.combat_command(sm,"select",slot).success,"选择远程攻击："+str(slot))

func _remote_hit() -> Dictionary:
 _check(Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440))).success,"通过原入口发射远程攻击")
 # 既有水膜承受四分之一伤害、正伤至少 1；预期来自出手输入，不由扣血结果倒填。
 expected_remote_hp=20.0-maxf(1.0,float(Run.snapshot(sm).combat.shots[0].damage)*0.25)
 for i in 80:
  _tick(0.01)
  if Run.snapshot(sm).combat.actors[ID].hp<20: break
 var c: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 _check(c.actors[ID].hp==expected_remote_hp,"单颗远程攻击按出手伤害和水膜四分之一结算")
 return c

func _remote_case(slot: int, ms: int) -> void:
 _remote_reset(slot,ms)
 var hit:=_remote_hit()
 _tick(0.02)
 var after: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 _check((after.actors[ID].position==hit.actors[ID].position)==(ms>0),"远程档位决定实际目标击退停顿：%d／%d" % [slot,ms])
 _check(is_equal_approx(after.actors[ID].hit_remaining,hit.actors[ID].hit_remaining)==(ms>0),"远程档位决定受击时间线停顿：%d／%d" % [slot,ms])
 _check(is_equal_approx(after.actors[ID].flash_remaining,hit.actors[ID].flash_remaining)==(ms>0),"远程白闪跟随目标停顿：%d／%d" % [slot,ms])
 _check(after.action_left<hit.action_left and after.cooldown<hit.cooldown and after.elapsed>hit.elapsed,"远处玩家动作、冷却和全场时间继续：%d／%d" % [slot,ms])
 var used:=0.02
 while used<0.22:
  _tick(0.01)
  used+=0.01
 after=Run.snapshot(sm).combat.duplicate(true)
 _check(after.actors[ID].position!=hit.actors[ID].position and after.actors[ID].hit_remaining<=0.000001,"远程停顿结束原速完成击退：%d／%d" % [slot,ms])
 _check(after.hits==hit.hits and after.actors[ID].hp==expected_remote_hp and after.shots.is_empty(),"远程恢复不重复扣血或保留已命中弹体：%d／%d" % [slot,ms])
 measurements.append({"attack_slot":slot,"candidate_ms":ms,"hit":hit.actors[ID],"after":after.actors[ID]})

func _remote_miss(slot: int, ms: int) -> void:
 _remote_reset(slot,ms)
 _check(Run.combat_attack(sm,POINT,Vector2.LEFT).success,"打空对照从真实入口发射："+str(slot))
 for i in 70: _tick(0.01)
 var c: Dictionary=Run.snapshot(sm).combat
 _check(c.hits==0 and c.actors[ID].hp==20 and c.shots.is_empty(),"三档打空不扣血且弹体正常结束：%d／%d" % [slot,ms])
 _check(not timing.paused(ID),"三档打空不触发目标暂停：%d／%d" % [slot,ms])

func _remote_save_failure(slot: int) -> void:
 _remote_reset(slot,50)
 _check(Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440))).success,"保存失败对照真实发射")
 expected_remote_hp=20.0-maxf(1.0,float(Run.snapshot(sm).combat.shots[0].damage)*0.25)
 # 在实际命中前固定公开事务的输入，不重写伤害。
 var path: String=sm._active_save_path
 var hit_ready:=false
 for i in 60:
  var before: Dictionary=sm.data.duplicate(true)
  var clock: Dictionary=timing.state.duplicate(true)
  _tick(0.01)
  if Run.snapshot(sm).combat.actors[ID].hp<20:
   sm.data=before
   timing.state=clock
   hit_ready=true
   break
 _check(hit_ready,"找到同一实际弹体的命中边界")
 var before: Dictionary=sm.data.duplicate(true)
 var clock: Dictionary=timing.state.duplicate(true)
 sm._active_save_path=""
 _check(not _tick(0.01).success and sm.data==before and timing.state==clock,"远程命中保存失败同时回滚伤害和时钟："+str(slot))
 sm._active_save_path=path
 _check(_tick(0.01).success and Run.snapshot(sm).combat.actors[ID].hp==expected_remote_hp and timing.paused(ID),"保存恢复后同一弹体只命中一次："+str(slot))
 for i in 25: _tick(0.01)
 _check(Run.snapshot(sm).combat.hits==1 and not timing.paused(ID),"保存恢复不重复扣血或残留暂停："+str(slot))

func _parallel_shots() -> void:
 _remote_reset(1,50)
 var other: String="fenshui_silverfish_2"
 var untouched: String="fenshui_silverfish_3"
 for pair in [[other,[850.0,440.0]],[untouched,[1100.0,440.0]]]:
  var a: Dictionary=sm.data[Run.KEY].combat.actors[pair[0]]
  sm.data[Run.KEY].monsters[pair[0]].status="alive"
  a.position=pair[1]
  a.fish_origin=pair[1].duplicate()
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  Fish.phase(a,"recover",2.5)
 _check(Run.combat_attack(sm,POINT,Vector2.UP).success,"多弹夹具来自原真实发射")
 var c: Dictionary=sm.data[Run.KEY].combat
 var shot: Dictionary=c.shots[0].duplicate(true)
 # 只布置已有弹体的在途位置，以同一物理入口验证同帧和跨帧命中。
 var first:=_near_shot(shot,ID)
 var second:=_near_shot(shot,other)
 var flying: Dictionary=shot.duplicate(true)
 flying.origin=[800.0,480.0]
 flying.position=flying.origin.duplicate()
 flying.target=[810.0,480.0]
 c.shots=[first,first.duplicate(true),second,flying]
 var untouched_before: float=c.actors[untouched].fish_left
 _tick(0.01)
 var hit: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 _check(hit.actors[ID].hp==18.0 and hit.actors[other].hp==19.0 and hit.hits==3,"多个实际弹体各结算一次原伤害")
 _check(timing.paused(ID) and timing.paused(other) and not timing.paused(untouched),"多个命中目标各自停顿，未命中目标不停")
 _check(is_equal_approx(float(timing.state.ranged_left[ID]),0.05),"同帧重复命中不累加目标停顿")
 _tick(0.02)
 var held: Dictionary=Run.snapshot(sm).combat
 _check(held.actors[ID].position==hit.actors[ID].position and held.actors[other].position==hit.actors[other].position,"双目标真实击退同时停住")
 _check(held.actors[untouched].fish_left<untouched_before and held.shots[0].time>hit.shots[0].time,"未命中鱼和其他在途弹体照常推进")
 var left: float=timing.state.ranged_left[ID]
 sm.data[Run.KEY].combat.shots.append(_near_shot(shot,ID))
 _tick(0.01)
 _check(Run.snapshot(sm).combat.actors[ID].hp==17.0 and is_equal_approx(float(timing.state.ranged_left[ID]),left-0.01),"暂停中再次实际命中扣血但不刷新截止")
 _tick(0.01)
 sm.data[Run.KEY].combat.shots.append(_near_shot(shot,ID))
 _tick(0.01)
 _check(not timing.state.ranged_left.has(ID),"原暂停截止的最后一步再中弹也不续锁")
 for dt in [0.013,0.017,0.023]: _tick(dt)
 _check(not timing.paused(ID) and not timing.paused(other),"多弹窗口按原截止结束，不形成累计锁定")
 _check(Run.valid(Run.snapshot(sm)),"多弹交互保持正式探索状态合法")

func _near_shot(template: Dictionary, id: String) -> Dictionary:
 var shot: Dictionary=template.duplicate(true)
 var p: Vector2=Run.Combat.vec(sm.data[Run.KEY].combat.actors[id].position)
 shot.origin=Run.Combat.pack(p+Vector2(0,13))
 shot.position=shot.origin.duplicate()
 shot.target=Run.Combat.pack(p)
 shot.time=0.0
 return shot

func _stage_delay() -> void:
 var phase_times: Array=[]
 for ms in [0,30,50]:
  _remote_reset(0,ms)
  _remote_hit()
  for i in 25: _tick(0.01)
  phase_times.append(Run.snapshot(sm).combat.actors[ID].fish_left)
 _check(absf(phase_times[1]-phase_times[0]-0.03)<0.00001 and absf(phase_times[2]-phase_times[0]-0.05)<0.00001,"用户确认保留的鱼技能阶段分别延后30／50毫秒",{"phase_remaining":phase_times})

func _without_controller() -> void:
 var states: Array=[]
 for enabled in [false,true]:
  _remote_reset(0,0)
  if not enabled: timing=null
  _remote_hit()
  for i in 25: _tick(0.01)
  states.append(Run.snapshot(sm).combat.duplicate(true))
 _check(states[0]==states[1],"不安装时钟的正式行为与远程0毫秒对照一致")
