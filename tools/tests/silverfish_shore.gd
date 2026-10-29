extends "res://tools/tests/fenshui_borrow_lightning.gd"
## 从正式战斗/伤害入口观察银鳞鱼；仅时间和初始遭遇布置受控。

func formal() -> Dictionary:
 var run:=fresh()
 run.combat.fs01_trial=false
 for id in run.monsters: run.monsters[id].status="alive" if id==IDS[0] else "skipped"
 return run

func run_tests() -> void:
 var run:=formal()
 Combat.Skills.damage(run,IDS[0],8)
 check(run.combat.actors[IDS[0]].hp==18,"正式银鳞鱼水中保护只承受8点的25%")
 Combat.Skills.damage(run,IDS[0],1)
 check(run.combat.actors[IDS[0]].hp==17,"水中有效攻击最低造成1点")
 run.combat.actors[IDS[0]].position=[781.0,475.0]
 Combat.Skills.damage(run,IDS[0],8)
 check(run.combat.actors[IDS[0]].hp==9,"上岸立即取消保护并承受完整8点伤害")
 shore_cycle()
 recovery_contract()
 print("银鳞鱼：",checks,"项，失败",failures)
 quit(1 if failures else 0)

func shore_cycle() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[IDS[0]]
 a.position=[860.0,485.0]
 tick(run,Vector2(781,475),0.02)
 check(a.get("fish_phase","")=="warning","正式岸线站位可诱导鱼锁向预警")
 if not a.has("fish_phase"): return
 var aim: Array=a.fish_aim.duplicate()
 tick(run,Vector2(780,520),0.2)
 check(a.fish_aim==aim,"预警锁向后横移不使冲刺转向")
 for i in 100:
  if a.fish_phase=="stranded": break
  Combat.advance(run,Vector2(780,520),0.02)
 check(a.fish_phase=="stranded" and not Catalog.Fenshui.water(Combat.vec(a.position),0),"冲刺真实到合法岸段进入活体搁浅")
 check(Roads.is_walkable(Combat.vec(a.position),15) and not Catalog.Fenshui.protected(Combat.vec(a.position),15),"鱼身体不穿岛栅栏或保护区")
 var shore: Array=a.position.duplicate()
 tick(run,Vector2(780,520),2.4)
 check(a.position==shore and a.fish_phase=="stranded","搁浅2.5秒窗口内不继续冲刺或瞬移")
 Combat.Skills.damage(run,IDS[0],1)
 tick(run,Vector2(755,404),0.2)
 check(a.fish_phase!="stranded","搁浅受击不把2.5秒剩余计时反复延长")
 for i in 200:
  Combat.advance(run,Vector2(755,404),0.02)
  if a.fish_phase=="forming": break
 check(a.fish_phase=="forming" and Catalog.Fenshui.water(Combat.vec(a.position)),"鱼沿合法路径回水后进入凝膜")
 var hp: float=a.hp
 Combat.Skills.damage(run,IDS[0],4)
 check(a.hp==hp-4,"回水凝膜时尚未减伤")
 # 受击只暂停位移，不改变本次1秒凝膜期限。
 tick(run,Vector2(755,404),1.2)
 hp=a.hp
 Combat.Skills.damage(run,IDS[0],4)
 check(a.hp==hp-1,"回水1秒后水膜恢复25%承伤")

func recovery_contract() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[IDS[0]]
 a.hp=7.0
 tick(run,Vector2(755,404),0.1)
 check(a.hp==7 and Combat.valid(run.combat),"缺新字段旧鱼推进后生命不重置且可保存")
 tick(run,Vector2(755,404),6.0)
 check(a.hp==7,"普通鱼脱战恢复巡游但不回血")
 run.monsters[IDS[0]].status="captured"
 var before: Dictionary=a.duplicate(true)
 tick(run,Vector2(920,440),2.0)
 check(a==before,"本趟已捕获的鱼不重生不推进")
 var copy: Dictionary=JSON.parse_string(JSON.stringify(run))
 check(Combat.valid(copy.combat) and copy.combat.actors[IDS[0]].hp==7,"JSON恢复保留鱼的生命和阶段")
 copy.combat.actors[IDS[0]].fish_left="1"
 check(not Combat.valid(copy.combat),"恢复拒绝字符串阶段剩余时间")
 copy=JSON.parse_string(JSON.stringify(run))
 copy.combat.actors[IDS[0]].fish_phase="unknown"
 check(not Combat.valid(copy.combat),"恢复拒绝未知鱼阶段")
 copy=JSON.parse_string(JSON.stringify(run))
 copy.combat.actors[IDS[0]].erase("fish_aim")
 check(not Combat.valid(copy.combat),"新阶段字段不全不冒充旧档初始化")
