extends "res://tools/tests/fenshui_hitstop_state.gd"

func _scenarios() -> void:
 for slot in [0,1,2]:
  _reset_clock(70)
  _check(Run.combat_command(sm,"select",slot).success,"真实选择命中招式："+str(slot))
  _check(Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440))).success,"实际出手："+str(slot))
  var events: Array=[]
  for i in 80:
   var result:=_tick(0.01)
   events.append_array(result.get("hit_feedback",[]))
   if Run.snapshot(sm).combat.actors[ID].hp<20: break
  _check(events.size()==1,"真实有效命中返回一次临时显示事件："+str(slot))
  if events.size()!=1: continue
  var e: Dictionary=events[0]
  _check(e.id==ID and e.kind==["hero","yaya","tieshan"][slot] and e.protected,"事件关联实际招式、目标和命中时保护状态")
  _check(Run.Combat.vec(e.point).distance_to(Vector2(920,440))<20.0 and Run.Combat.vec(e.direction).dot(POINT.direction_to(Vector2(920,440)))>0.99,"事件携带实际碰撞处和受力方向")
  _check(not Run.snapshot(sm).combat.has("hit_feedback"),"显示事件不进入存档")
  _check(_tick(0.01).get("hit_feedback",[]).is_empty(),"下一次推进不重放已消费命中")
 for slot in [0,1,2]:
  _reset_clock(70)
  sm.data[Run.KEY].combat.actors[ID].electric_left=4.0
  Run.combat_command(sm,"select",slot)
  Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440)))
  var events: Array=[]
  for i in 80:
   events.append_array(_tick(0.01).get("hit_feedback",[]))
   if not events.is_empty(): break
  _check(events.size()==1 and not events[0].protected,"破膜后真实命中进入肉体反馈："+str(slot))
 _reset_clock(70)
 Run.combat_command(sm,"select",0)
 Run.combat_attack(sm,POINT,Vector2.LEFT)
 var missed: Array=[]
 for i in 70: missed.append_array(_tick(0.01).get("hit_feedback",[]))
 _check(missed.is_empty() and Run.snapshot(sm).combat.hits==0,"真实打空不产生接触反馈")
 _reset_clock(70)
 Run.combat_command(sm,"select",0)
 Run.combat_attack(sm,POINT,POINT.direction_to(Vector2(920,440)))
 sm.data[Run.KEY].combat.shots[0].damage=0
 var zero: Array=[]
 for i in 50: zero.append_array(_tick(0.01).get("hit_feedback",[]))
 _check(zero.is_empty() and Run.snapshot(sm).combat.actors[ID].hp==20,"实际零伤害命中不产生肉体反馈")
 _reset_clock(70)
 Run.combat_attack(sm,POINT,Vector2.RIGHT)
 for i in 17: _tick(0.01)
 var before: Dictionary=sm.data.duplicate(true)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 var failed:=_tick(0.01)
 _check(not failed.success and not failed.has("hit_feedback") and sm.data==before,"命中保存失败不泄漏显示事件或扣血")
 sm._active_save_path=path
 _check(_tick(0.01).get("hit_feedback",[]).size()==1,"保存恢复后仅成功命中返回一次反馈")
 _reset_clock(70)
 Run.combat_command(sm,"select",0)
 sm.data[Run.KEY].combat.actors[ID].electric_left=4.0
 var continuous: Array=[]
 for shot in 2:
  for i in 100:
   if Run.snapshot(sm).combat.cooldown<=0.00001 and Run.snapshot(sm).combat.action_left<=0.0: break
   continuous.append_array(_tick(0.01).get("hit_feedback",[]))
  var target:=Run.Combat.vec(Run.snapshot(sm).combat.actors[ID].position)
  _check(Run.combat_attack(sm,POINT,POINT.direction_to(target)).success,"按原冷却连续真实出手："+str(shot))
  for i in 50:
   continuous.append_array(_tick(0.01).get("hit_feedback",[]))
   if continuous.size()>shot: break
 _check(continuous.size()==2 and Run.snapshot(sm).combat.hits==2,"连续命中各反馈一次，不丢失也不重放旧事件")
