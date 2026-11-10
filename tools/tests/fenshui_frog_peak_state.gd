extends "res://tools/tests/fenshui_frog_counter.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 _check(_verify_isolation(),"最高点反击与落地伤害使用隔离存档")
 for sample in [[0.0,false],[0.10,false],[0.299,false],[0.30,true],[0.40,true],[0.50,true],[0.501,false],[0.70,false],[0.78,false]]:
  var run:=airborne()
  tick(run,float(sample[0]))
  var a: Dictionary=run.combat.actors[Boss.ID]
  var hp: float=a.hp
  Combat.Skills.damage(run,Boss.ID,8)
  _check(a.hp<hp,"真实伤害入口仍正常扣血："+str(sample[0]))
  _check((a.frog_phase=="toppling")==sample[1],"只在最高点前后0.10秒实际命中打翻："+str(sample[0]),{"phase":a.frog_phase,"left":a.frog_left})
 landing_rules()
 attack_arrival_rules()
 legacy_window()
 _finish()

func attack_arrival_rules() -> void:
 for slot in 3:
  for sample in [[0.10,false],[0.29,true],[0.49,false]]:
   var run:=airborne()
   tick(run,float(sample[0]))
   run.members=[{"id":"yaya","level":1},{"id":"tieshan","level":1}]
   var a: Dictionary=run.combat.actors[Boss.ID]
   _check(Combat.Skills.select(run,slot),"按原入口选择实际命中时机对照招式："+str(slot))
   _check(Combat.attack(run,HERO,HERO.direction_to(Combat.vec(a.position))),"真实出手而非直接调用反击："+str(sample[0]))
   var observed:=false
   for i in 100:
    var at_hit:=0.8-float(a.frog_left)
    Combat.advance(run,HERO,0.005)
    if run.combat.hits==0: continue
    observed=true
    _check((a.frog_phase=="toppling")==sample[1],"以实际到达时刻而非按键时刻决定打翻",{"slot":slot,"pressed_at":sample[0],"hit_at":at_hit,"phase":a.frog_phase,"expected_flip":sample[1]})
    _check(a.hp<96.0,"窗内外的真实命中都沿原规则扣血")
    break
   _check(observed,"原弹道/近战在对照用例真实命中一次")

func legacy_window() -> void:
 for sample in [[0.0,false],[0.074,false],[0.075,true],[0.175,true],[0.275,true],[0.276,false],[0.34,false]]:
  var run:=airborne()
  var a: Dictionary=run.combat.actors[Boss.ID]
  a.erase("frog_air_duration")
  a.frog_left=0.35
  a.position=a.frog_origin.duplicate()
  tick(run,float(sample[0]))
  Combat.Skills.damage(run,Boss.ID,8)
  _check((a.frog_phase=="toppling")==sample[1],"旧0.35秒腾空档沿原轨迹应用最高点前后各0.10秒",{"elapsed":sample[0],"phase":a.frog_phase})

func landing_rules() -> void:
 var run:=airborne()
 var a: Dictionary=run.combat.actors[Boss.ID]
 var hp: float=run.combat.hp
 _check(Boss.line(vec_point(a.frog_target),HERO) and vec_point(a.frog_target).distance_to(HERO)<=65.0,"原自然落点能实际砸中玩家")
 tick(run,0.78)
 _check(a.frog_phase=="airborne" and run.combat.hp==hp,"起跳和整个空中接触不扣玩家生命")
 tick(run,0.02)
 _check(a.frog_phase=="landing" and run.combat.hp==hp-6.0,"真正落地砸中只结算原6点伤害")
 tick(run,0.5)
 _check(run.combat.hp==hp-6.0,"落地动作持续期间不重复砸伤")
 run=airborne()
 tick(run,0.4)
 Combat.Skills.damage(run,Boss.ID,8)
 hp=run.combat.hp
 tick(run,0.56)
 _check(run.combat.actors[Boss.ID].frog_phase=="exposed" and run.combat.hp==hp,"反击成功翻落不会再造成砸击伤害")

func vec_point(p: Array) -> Vector2:
 return Vector2(p[0],p[1])
