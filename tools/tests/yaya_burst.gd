extends Node
const Skills=preload("res://scripts/maze/team_attack.gd")
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok: failures.append(label)
func fixture() -> Dictionary:
 return {"members":[{"id":"yaya","level":1,"rank":1}],"monsters":{},"combat":{"hp":36,"attack":20,"cooldown":0.0,"selected":1,"throws":0,"shots":[],"actors":{},"region":"fenshui"}}
func _ready() -> void:
 var tuning=Skills.Tuning
 tuning.initialized=true
 tuning.values={}
 var run: Dictionary=fixture()
 check(Skills.attack(run,Vector2.ZERO,Vector2.RIGHT),"起手成功")
 check(run.combat.shots.size()==1,"起手只发一颗")
 var first: Dictionary=run.combat.shots[0].duplicate(true)
 check(is_equal_approx(float(first.flight),1.0),"未保存弹速时310射程飞行1秒")
 for i in range(1,3):
  var aim: Vector2=Vector2.RIGHT.rotated(i*PI/4.0)
  run.combat.aim=Skills.pack(aim)
  Skills.advance(run,Vector2(i*10,0),0.1)
  check(run.combat.shots.size()==i+1,"第%d颗按时发射"%(i+1))
  if run.combat.shots.size()==i+1:
   var shot: Dictionary=run.combat.shots[-1]
   check(Skills.vec(shot.origin).is_equal_approx(Vector2(i*10,0)),"读取本次发射位置")
   check(Skills.vec(shot.origin).direction_to(Skills.vec(shot.target)).dot(aim)>0.999,"读取本次朝向")
 check(run.combat.shots[0]==first,"旧弹不转弯")
 check(run.combat.throws==1,"一轮只计一次出手")
 check(Skills.valid(run.combat),"连发状态合法")
 var expected: int=maxi(1,roundi(roundi(20.0*Skills.Growth.active_skill("yaya",1).multiplier*Skills.Tuning.effect("yaya","damage_scale",100.0)/100.0)*0.25))
 check(int(first.damage)==expected,"单颗25%整数伤害")
 for reason in ["switch","hurt","dead"]:
  var cancelled: Dictionary=fixture()
  Skills.attack(cancelled,Vector2.ZERO,Vector2.RIGHT)
  if reason=="switch": Skills.select(cancelled,0)
  elif reason=="hurt": cancelled.combat.hurt_recovery_left=0.6
  else: cancelled.combat.hp=0
  Skills.advance(cancelled,Vector2.ZERO,0.2)
  check(cancelled.combat.shots.size()==1 and int(cancelled.combat.get("seed_remaining",-1))==0,"中断后不补发："+reason)
 var paused: Dictionary=fixture()
 Skills.attack(paused,Vector2.ZERO,Vector2.RIGHT)
 Skills.advance(paused,Vector2.ZERO,0.0)
 check(paused.combat.shots.size()==1,"零推进不发射")
 var zero: Dictionary=fixture()
 zero.combat.attack=0
 Skills.attack(zero,Vector2.ZERO,Vector2.RIGHT)
 check(zero.combat.shots[0].damage==0,"零攻击保持零伤害")
 check(Skills.valid(fixture().combat),"旧状态兼容")
 tuning.initialized=true
 tuning.values={"effect.yaya":{"burst_count":3,"burst_interval":0.2,"burst_damage_scale":50,"burst_cooldown":1.2}}
 var custom: Dictionary=fixture()
 Skills.attack(custom,Vector2.ZERO,Vector2.RIGHT)
 Skills.advance(custom,Vector2.ZERO,0.1)
 check(custom.combat.shots.size()==1,"0.2秒间隔不提前释放")
 for i in range(3): Skills.advance(custom,Vector2.ZERO,0.1)
 check(custom.combat.shots.size()==3 and custom.combat.seed_remaining==0,"候选数量3真实消费")
 check(is_equal_approx(float(custom.combat.cooldown),1.2),"整轮最短间隔真实消费")
 var base_damage: int=roundi(20.0*Skills.Growth.active_skill("yaya",1).multiplier)
 check(int(custom.combat.shots[0].damage)==maxi(1,roundi(base_damage*0.5)),"单颗50%倍率真实消费")
 check(tuning.validate({"effect.yaya":{"burst_count":3}}).is_empty(),"候选字段可导入")
 check(tuning.validate({"effect.yaya":{"burst_count":3}},true).is_empty(),"正式连发字段允许保存")
 check(not tuning.validate({"effect.yaya":{"burst_count":2.5}}).is_empty(),"颗数禁止小数")
 tuning.values={"effect.yaya":{"burst_count":12,"burst_interval":0.3}}
 var maximum: Dictionary=fixture()
 Skills.attack(maximum,Vector2.ZERO,Vector2.RIGHT)
 check(Skills.valid(maximum.combat),"最大连发时长状态合法")
 for i in range(66): Skills.advance(maximum,Vector2.ZERO,0.05)
 check(maximum.combat.shots.size()==12,"12颗慢速连发全部释放")
 tuning.values={"effect.hero":{"damage_scale":50,"speed":600,"distance":300,"action_scale":150,"interval_scale":200,"hitstop":100,"fx_duration":400},"effect.tieshan":{"damage_scale":50,"action_scale":150,"interval_scale":150}}
 var hero: Dictionary=fixture()
 hero.combat.selected=0
 Skills.attack(hero,Vector2.ZERO,Vector2.RIGHT)
 check(is_equal_approx(Skills.vec(hero.combat.shots[0].target).length(),300.0) and is_equal_approx(float(hero.combat.shots[0].flight),0.5),"锅铲射程与弹速真实消费")
 check(is_equal_approx(float(hero.combat.action_left),0.45) and is_equal_approx(float(hero.combat.cooldown),float(Skills.Growth.active_skill("hero",1).interval)*2.0),"锅铲时长与间隔倍率消费")
 check(hero.combat.shots[0].damage==roundi(20.0*Skills.Growth.active_skill("hero",1).multiplier*0.5),"锅铲伤害倍率消费")
 var axe: Dictionary=fixture()
 axe.members=[{"id":"tieshan","level":1,"rank":1}]
 Skills.attack(axe,Vector2.ZERO,Vector2.RIGHT)
 check(axe.combat.axe_damage==roundi(20.0*Skills.Growth.active_skill("tieshan",1).multiplier*0.5),"铁山伤害倍率消费")
 check(is_equal_approx(float(axe.combat.action_left),0.72) and is_equal_approx(float(axe.combat.cooldown),float(Skills.Growth.active_skill("tieshan",1).interval)*1.5),"铁山时长与间隔倍率消费")
 var feedback=preload("res://scripts/maze/fenshui_hit_feedback.gd").new()
 check(is_equal_approx(feedback.effect_duration("hero"),0.4),"命中特效时长消费者读取参数")
 feedback.free()
 check(preload("res://scripts/maze/player_editor.gd").hitstop("hero")==100,"局部卡肉消费者读取参数")
 tuning.values={}
 get_tree().quit(0 if failures.is_empty() else 1)

