extends "res://tools/tests/ch2_entry_state.gd"
const Combat=preload("res://scripts/maze/combat_simulation.gd")
const Catalog=preload("res://data/maze/capture_catalog.gd")
const Boss=preload("res://data/maze/fenshui_boss.gd")
const Frog=preload("res://scripts/maze/wind_frog_combat.gd")
const HERO=Vector2(880,490)

func fresh_frog() -> Dictionary:
 var rows: Array=Catalog.all()+Catalog.Fenshui.all()+[Boss.row()]
 var c: Dictionary=Combat.create(8,100,HERO,rows)
 Combat.Skills.ensure(c)
 c.layout=[]
 c.region="fenshui"
 c.fenshui_encounters=true
 c.frog_encounter=true
 c.frog_unlocked=true
 c.fs01_trial=false
 var run: Dictionary={"combat":c,"monsters":{},"members":[],"pending":""}
 for row in rows: run.monsters[row.id]={"status":"alive" if row.id==Boss.ID else "skipped","refresh_count":0}
 Frog.initialize(c.actors[Boss.ID])
 return run

func tick(run: Dictionary, seconds: float) -> void:
 var remaining:=seconds
 while remaining>0.000001:
  var delta:=minf(0.02,remaining)
  Combat.advance(run,HERO,delta)
  remaining-=delta

func airborne() -> Dictionary:
 var run:=fresh_frog()
 for i in 80:
  Combat.advance(run,HERO,0.02)
  if run.combat.actors[Boss.ID].frog_phase=="airborne": break
 return run

func _run() -> void:
 sm=get_node("/root/SaveManager")
 _check(_verify_isolation(),"正式巨蛙单元检查使用独立存档")
 var run:=airborne()
 var actor: Dictionary=run.combat.actors[Boss.ID]
 _check(actor.frog_phase=="airborne","原正常推进自然进入腾空，不直接写反击阶段")
 tick(run,0.4)
 Combat.Skills.damage(run,Boss.ID,8)
 _check(actor.frog_phase=="toppling","实际玩家伤害入口打断腾空并触发一次失衡翻落")
 if failures==0:
  protection_and_phases(run)
  real_player_attacks()
  environment_damage()
  compatibility_and_corruption()
  local_hitstop_clock()
  refresh_and_boundaries()
 _finish()

func protection_and_phases(run: Dictionary) -> void:
 var a: Dictionary=run.combat.actors[Boss.ID]
 _check(a.hp==94,"水中保护将8点玩家命中减至2点，但仍可反击")
 _check(is_equal_approx(float(a.frog_left),0.56) and Combat.valid(run.combat),"翻落保存完整剩时和合法轨迹")
 var from: Array=a.frog_counter_from.duplicate()
 tick(run,0.12)
 var left: float=a.frog_left
 Combat.Skills.damage(run,Boss.ID,8)
 _check(a.frog_phase=="toppling" and a.frog_counter_from==from and a.frog_left==left,"重复命中翻落不重新触发或延长")
 tick(run,left)
 _check(a.frog_phase=="exposed" and is_equal_approx(float(a.frog_left),3.0) and a.position==a.frog_target,"沿原跳线翻落至合法终点并开始完整3秒露腹")
 var hp: float=a.hp
 Combat.Skills.damage(run,Boss.ID,8)
 _check(a.hp==hp-16 and a.frog_left==3.0,"露腹取消保护，8点普通伤害变16且不刷新弱点")
 tick(run,2.98)
 _check(a.frog_phase=="exposed" and a.hp==hp-16,"露腹仍有效且期间不回血")
 tick(run,0.02)
 _check(a.frog_phase=="recovering" and is_equal_approx(float(a.frog_left),0.84),"3秒到期进入连续起身而非再次翻倒")
 tick(run,0.84)
 _check(a.frog_phase=="active" and Combat.valid(run.combat),"起身结束恢复正常活动且状态可存")
 hp=a.hp
 Combat.Skills.damage(run,Boss.ID,8)
 _check(a.hp==hp-2,"起身后位于水中且无破膜时恢复25%伤害")

func real_player_attacks() -> void:
 for slot in 3:
  var run:=airborne()
  tick(run,0.30)
  run.members=[{"id":"yaya","level":1},{"id":"tieshan","level":1}]
  _check(Combat.Skills.select(run,slot),"可选择原玩家招式："+str(slot))
  var a: Dictionary=run.combat.actors[Boss.ID]
  var aim:=HERO.direction_to(Combat.vec(a.position))
  _check(Combat.attack(run,HERO,aim),"从原攻击接口实际出手："+str(slot))
  for i in 30:
   Combat.advance(run,HERO,0.02)
   if a.frog_phase=="toppling": break
  _check(a.frog_phase=="toppling" and run.combat.hits==1,"锅铲／芽芽弹体或铁山实际命中后反击："+str(slot))
 var missed:=airborne()
 _check(Combat.attack(missed,HERO,Vector2.LEFT),"打空样例实际出手")
 tick(missed,0.5)
 _check(missed.combat.actors[Boss.ID].frog_phase=="airborne" and missed.combat.hits==0,"只按攻击而未命中不触发反击；不把0.8秒腾空都当反击窗口")

func environment_damage() -> void:
 var run:=airborne()
 tick(run,0.4)
 var eel_id: String="fenshui_thunder_eel_1"
 run.monsters[eel_id].status="alive"
 run.combat.actors[eel_id].position=[980.0,440.0]
 var a: Dictionary=run.combat.actors[Boss.ID]
 var hp: float=a.hp
 var Eel=load("res://scripts/maze/thunder_eel_combat.gd")
 Eel.discharge(run,{"id":eel_id,"kind":"thunder_eel"},HERO,5,Combat.Skills)
 _check(a.hp==hp-5 and a.get("electric_left",0)==4.0,"真实范围电对巨蛙一次造成原5点电伤并破膜4秒")
 _check(a.frog_phase=="airborne","环境电不能冒充玩家反击")
 Combat.Skills.damage(run,Boss.ID,8)
 _check(a.hp==hp-13 and a.frog_phase=="toppling","破膜中玩家攻击承受完整8点并仍可触发反击")

func compatibility_and_corruption() -> void:
 var run:=airborne()
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.erase("frog_air_duration")
 a.frog_left=0.35
 a.position=a.frog_origin.duplicate()
 _check(Combat.valid(run.combat),"缺新时长字段的旧0.35秒腾空档仍合法")
 tick(run,0.1)
 _check(Combat.valid(run.combat) and is_equal_approx(float(a.frog_left),0.25),"旧腾空按原剩时继续而不重算轨迹")
 for key in ["electric_left","frog_form_left","frog_air_duration"]:
  for value in [-1,"1",NAN,10]:
   var bad:=run.duplicate(true)
   bad.combat.actors[Boss.ID][key]=value
   _check(not Combat.valid(bad.combat),"拒绝损坏阶段字段："+key+"／"+str(value))

func local_hitstop_clock() -> void:
 var run:=airborne()
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.electric_left=4.0
 var left: float=a.frog_left
 Frog.advance(run,HERO,0.02,0.02)
 _check(a.frog_left==left and is_equal_approx(float(a.electric_left),3.98),"局部命中停顿只停身体阶段，不延长外部4秒破膜")

func refresh_and_boundaries() -> void:
 var run:=airborne()
 tick(run,0.4)
 var a: Dictionary=run.combat.actors[Boss.ID]
 var eel_id: String="fenshui_thunder_eel_1"
 run.monsters[eel_id].status="alive"
 run.combat.actors[eel_id].position=[980.0,440.0]
 var Eel=load("res://scripts/maze/thunder_eel_combat.gd")
 for i in 2:
  Eel.discharge(run,{"id":eel_id,"kind":"thunder_eel"},HERO,5,Combat.Skills)
 _check(a.hp==86 and a.electric_left==4.0,"连续两次真实环境电各伤5点，破膜刷新4秒而非累加8秒")
 a.frog_form_left=0.5
 _check(Combat.Skills.FrogCounter.damage_amount(run.combat,Boss.ID,8)==8,"凝膜不能覆盖尚未结束的破膜")
 Combat.Skills.damage(run,Boss.ID,8)
 for field in ["frog_left","frog_counter_from","frog_target"]:
  var bad:=run.duplicate(true)
  bad.combat.actors[Boss.ID][field]=0.57 if field=="frog_left" else [NAN,490]
  _check(not Combat.valid(bad.combat),"反击档拒绝越界剩时或无效轨迹："+field)
 var trial:=airborne()
 trial.combat.fs01_trial=true
 Combat.Skills.damage(trial,Boss.ID,8)
 _check(trial.combat.actors[Boss.ID].frog_phase=="airborne","旧鱼鳗试玩标记不启用正式巨蛙反击")

func _finish() -> void:
 var report: Dictionary={"checks":checks,"failures":failures,"results":results}
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FROG_COUNTER ",checks," checks, ",failures," failures")
 get_tree().quit(1 if failures else 0)
