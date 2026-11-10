extends "res://tools/tests/thunder_eel_shore.gd"
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
var results: Array=[]

func check(ok: bool, message: String) -> void:
 super.check(ok,message)
 results.append({"label":message,"passed":ok})

func advance_until(run: Dictionary, hero: Vector2, predicate: Callable, seconds: float=12.0) -> bool:
 for i in ceili(seconds/0.02):
  if predicate.call(): return true
  Combat.advance(run,hero,0.02)
 return predicate.call()

func run_tests() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 var releases:=0
 var previous:=""
 for i in 600:
  Combat.advance(run,Vector2(890,485),0.02)
  var current: String=a.get("eel_phase","")
  if current=="discharge" and previous!="discharge": releases+=1
  previous=current
  if current=="exhausted": break
 check(releases==3 and a.get("eel_phase","")=="exhausted","真实三次放电完成才进入力竭，不由测试写入阶段")
 if a.get("eel_phase","")=="exhausted":
  check(is_equal_approx(float(a.eel_left),4.0) and not Eel.shielded(run.combat,EEL),"第三次结束立即给完整4秒无保护输出窗口")
  cycle_behavior(run)
 cancelled_charge()
 independent_and_missed()
 save_contract()
 shore_exhaustion()
 var out:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="): out=arg.trim_prefix("--report=")
 if not out.is_empty(): FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("电鳗力竭：",checks,"项，失败",failures)
 quit(1 if failures else 0)

func cycle_behavior(run: Dictionary) -> void:
 var a: Dictionary=run.combat.actors[EEL]
 var origin: Array=a.position.duplicate()
 var serial: int=run.combat.electric_serial
 var hero_hp: float=run.combat.hp
 tick(run,Vector2(890,485),2.0)
 check(a.position==origin and a.velocity==[0.0,0.0] and run.combat.electric_serial==serial and run.combat.hp==hero_hp,"力竭时玩家留在射程内也不移动、不蓄力或补放电")
 var hp: float=a.hp
 Combat.Skills.damage(run,EEL,8)
 check(a.hp==hp-8 and not Eel.shielded(run.combat,EEL),"力竭取消真实减伤，8点攻击完整扣8点")
 tick(run,Vector2(890,485),1.98)
 check(a.eel_phase=="exhausted" and a.eel_left>0 and Combat.valid(run.combat),"实际3.98秒仍保留无膜窗口且可保存")
 tick(run,Vector2(890,485),0.04)
 check(a.eel_phase=="forming" and not Eel.shielded(run.combat,EEL) and a.eel_discharges==3,"4秒结束先成泡，不能提前保护或清零")
 tick(run,Vector2(890,485),1.02)
 check(a.eel_phase!="forming" and a.eel_discharges==0 and Eel.shielded(run.combat,EEL),"沿原1秒成泡结束后恢复行动保护并清零")
 check(a.hp==hp-8,"力竭和恢复都不回血")

func cancelled_charge() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 check(advance_until(run,Vector2(890,485),func(): return a.get("eel_discharges",0)==2),"实际完成两次放电")
 check(advance_until(run,Vector2(890,485),func(): return a.eel_phase=="charging",3.0),"正常冷却后开始第三次蓄力")
 a.position=[781.0,475.0]
 var serial: int=run.combat.electric_serial
 tick(run,Vector2(781,475),0.1)
 check(a.eel_phase=="stranded" and a.eel_discharges==2 and run.combat.electric_serial==serial,"受控离水取消未释放的第三次，保持两次")
 check(advance_until(run,Vector2(1560,218),func(): return a.eel_phase=="forming",8.0),"取消后沿原合法回水路线成泡")
 tick(run,Vector2(1560,218),1.02)
 check(a.eel_discharges==2 and a.eel_phase=="idle" and Combat.valid(run.combat),"普通回水成泡不清掉已完成的两次")

func independent_and_missed() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 var other:="fenshui_thunder_eel_2"
 run.monsters[other].status="alive"
 check(advance_until(run,Vector2(890,485),func(): return a.get("eel_discharges",0)==2),"双鳗存在时仍独立完成两次")
 check(advance_until(run,Vector2(890,485),func(): return a.eel_phase=="charging",3.0),"第三次蓄力开始后准备躲出范围")
 var hp: float=run.combat.hp
 check(advance_until(run,Vector2(1000,485),func(): return a.eel_phase=="exhausted",3.0),"玩家躲开第三次放电仍正常累计完成并力竭")
 check(run.combat.hp==hp and a.eel_discharges==3 and run.combat.actors[other].get("eel_discharges",0)==0,"未命中不影响计数，另一只不共用次数")

func save_contract() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 check(advance_until(run,Vector2(890,485),func(): return a.get("eel_phase","")=="exhausted"),"序列化样例由真实三次放电建立")
 tick(run,Vector2(890,485),0.7)
 var restored: Dictionary=JSON.parse_string(JSON.stringify(run))
 check(Combat.valid(restored.combat),"力竭剩时和次数允许JSON恢复")
 var left: float=restored.combat.actors[EEL].eel_left
 var serial: int=restored.combat.electric_serial
 tick(restored,Vector2(890,485),0.2)
 check(is_equal_approx(float(restored.combat.actors[EEL].eel_left),left-0.2) and restored.combat.electric_serial==serial,"读回续剩时，不重计或重放第三次")
 for bad in [-1,4,1.5,"2",INF,true]:
  var broken: Dictionary=run.duplicate(true)
  broken.combat.actors[EEL].eel_discharges=bad
  check(not Combat.valid(broken.combat),"拒绝损坏力竭次数："+str(bad))
 var partial: Dictionary=run.duplicate(true)
 partial.combat.actors[EEL].erase("eel_discharges")
 check(not Combat.valid(partial.combat),"新力竭阶段缺计数不能当旧档静默重置")
 var old:=formal()
 tick(old,Vector2(890,485),0.2)
 old.combat.actors[EEL].erase("eel_discharges")
 var before: Dictionary=old.combat.actors[EEL].duplicate(true)
 check(Combat.valid(old.combat),"旧岸水阶段缺次数仍合法")
 tick(old,Vector2(890,485),0.02)
 check(old.combat.actors[EEL].eel_discharges==0 and old.combat.actors[EEL].hp==before.hp and old.combat.actors[EEL].eel_phase==before.eel_phase,"旧档仅补零次数，不重启阶段或回血")
 run.monsters[EEL].status="captured"
 before=a.duplicate(true)
 tick(run,Vector2(890,485),1.0)
 check(a==before,"已捕获力竭电鳗不继续推进或放电")

func shore_exhaustion() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 check(advance_until(run,Vector2(890,485),func(): return a.get("eel_phase","")=="exhausted"),"岸水优先级样例先实际完成三次")
 # 受控合法岸上检查点模拟已被击退离水；不增加生产落点或改碰撞。
 a.position=[781.0,475.0]
 check(Eel.Ground.dry(Eel.vec(a.position)) and Combat.valid(run.combat),"力竭离水检查点为当前v4合法干地")
 tick(run,Vector2(1560,218),3.98)
 check(a.eel_phase=="exhausted" and a.position==[781.0,475.0] and not Eel.shielded(run.combat,EEL),"力竭未结束不被搁浅/回水或成泡抢占")
 tick(run,Vector2(1560,218),0.04)
 check(a.eel_phase=="returning" and a.eel_discharges==3 and not Eel.shielded(run.combat,EEL),"4秒后岸上先回水，不在岸上提前补膜")
 check(advance_until(run,Vector2(1560,218),func(): return a.eel_phase=="forming",5.0),"力竭岸上结束后沿原记录原点实际回水")
 var hp: float=a.hp
 tick(run,Vector2(1560,218),1.02)
 check(a.eel_discharges==0 and a.hp==hp and Eel.shielded(run.combat,EEL),"完整回水成泡才恢复保护清零，仍不回血")
