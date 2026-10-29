extends "res://tools/tests/fenshui_borrow_lightning.gd"
const EEL="fenshui_thunder_eel_1"

func formal() -> Dictionary:
 var run:=fresh()
 run.combat.fs01_trial=false
 for id in run.monsters: run.monsters[id].status="alive" if id==EEL else "skipped"
 run.combat.actors[EEL].position=[860.0,485.0]
 return run

func run_tests() -> void:
 var run:=formal()
 Combat.Skills.damage(run,EEL,8)
 check(run.combat.actors[EEL].hp==28,"正式雷鳗水中8点攻击只造成2点")
 Combat.Skills.damage(run,EEL,1)
 check(run.combat.actors[EEL].hp==27,"正式雷鳗水中有效攻击最低1点")
 run.combat.actors[EEL].position=[781.0,475.0]
 Combat.Skills.damage(run,EEL,8)
 check(run.combat.actors[EEL].hp==19,"正式雷鳗岸上承受完整8点")
 shore_cycle()
 recovery_contract()
 electricity_edges()
 coarse_shore()
 short_limit()
 print("雷鳗岸水：",checks,"项，失败",failures)
 quit(1 if failures else 0)

func shore_cycle() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 var trail: Array=[]
 for i in 200:
  Combat.advance(run,Vector2(781,475),0.02)
  trail.append(a.position.duplicate())
  if a.get("eel_phase","")=="stranded": break
 print("岸线轨迹：",JSON.stringify(trail))
 check(a.get("eel_phase","")=="stranded","正式雷鳗追击真实岸线后全身上岸停顿")
 if not a.has("eel_phase"): return
 var shore: Array=a.position.duplicate()
 var hp: float=run.combat.hp
 tick(run,Vector2(781,475),2.4)
 check(a.position==shore and a.eel_phase=="stranded" and run.combat.hp==hp,"岸停2.5秒不追击不放电")
 Combat.Skills.damage(run,EEL,4)
 check(a.hp==26,"岸停真实受伤完整扣血")
 tick(run,Vector2(781,475),0.2)
 check(a.eel_phase=="returning","岸停结束开始沿合法短段回水")
 before_return_damage(run)
 for i in 200:
  Combat.advance(run,Vector2(781,475),0.02)
  if a.eel_phase=="forming": break
 check(a.eel_phase=="forming" and Catalog.Fenshui.water(Combat.vec(a.position)),"完整回水才凝膜")
 var before: float=a.hp
 Combat.Skills.damage(run,EEL,4)
 check(a.hp==before-4,"凝膜中仍承受完整伤害")
 tick(run,Vector2(781,475),1.1)
 before=a.hp
 Combat.Skills.damage(run,EEL,4)
 check(a.hp==before-1,"凝膜1秒完成后恢复25%承伤")

func before_return_damage(run: Dictionary) -> void:
 var before: float=run.combat.actors[EEL].hp
 Combat.Skills.damage(run,EEL,1)
 check(run.combat.actors[EEL].hp==before-1,"合法回水途中仍可被玩家攻击扣血")

func recovery_contract() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 a.hp=7.0
 tick(run,Vector2(1560,218),0.1)
 check(a.hp==7 and Combat.valid(run.combat),"旧雷鳗缺新字段推进后不回血且可保存")
 tick(run,Vector2(1560,218),3.0)
 check(a.hp==7,"普通雷鳗脱战巡游保留本趟伤害")
 var restored: Dictionary=JSON.parse_string(JSON.stringify(run))
 check(Combat.valid(restored.combat),"雷鳗岸水状态可JSON恢复")
 restored.combat.actors[EEL].eel_left="1"
 check(not Combat.valid(restored.combat),"拒绝字符串剩余时间损坏档")
 restored=JSON.parse_string(JSON.stringify(run))
 restored.combat.actors[EEL].eel_phase="unknown"
 check(not Combat.valid(restored.combat),"拒绝未知雷鳗阶段")
 restored=JSON.parse_string(JSON.stringify(run))
 restored.combat.actors[EEL].erase("eel_origin")
 check(not Combat.valid(restored.combat),"拒绝部分新状态缺失而非按旧档重置")
 run.monsters[EEL].status="captured"
 var before: Dictionary=a.duplicate(true)
 tick(run,Vector2(781,475),2.0)
 check(a==before,"本趟已捕获雷鳗不重生不推进")

func electricity_edges() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 tick(run,Vector2(890,485),0.02)
 check(a.get("eel_phase","")=="charging","水中沿原70范围和0.8前摇开始蓄电")
 var hp: float=run.combat.hp
 tick(run,Vector2(890,485),0.8)
 check(run.combat.hp==hp-5,"水中原蓄电结束仅扣原5点攻击")
 tick(run,Vector2(890,485),0.3)
 check(run.combat.hp==hp-5,"放电余段不重复扣血")
 run=formal()
 a=run.combat.actors[EEL]
 tick(run,Vector2(890,485),0.02)
 a.position=[781.0,475.0]
 hp=run.combat.hp
 tick(run,Vector2(781,475),0.1)
 check(a.get("eel_phase","")=="stranded" and a.windup==0 and a.mode!="windup","蓄电中离水当次推进即取消前摇及预警")
 tick(run,Vector2(781,475),0.9)
 check(run.combat.hp==hp,"已取消的蓄电不能在岸上补结算")
 run=formal()
 a=run.combat.actors[EEL]
 a.position=[920.0,337.0]
 var legal:=true
 for i in 300:
  Combat.advance(run,Vector2(1000,337),0.02)
  if not Roads.is_walkable(Combat.vec(a.position),15): legal=false
 check(legal and Combat.vec(a.position).x<950,"实际受岛体阻挡不穿障追击")
 check(Combat.valid(run.combat),"受阻追击仍可保存")

func coarse_shore() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 for i in 3: Combat.advance(run,Vector2(781,475),0.5)
 print("半秒步长上岸位置：",a.position)
 check(a.get("eel_phase","")=="stranded" and a.position[0]>790,"合法最大步长内首次完整上岸即停，不继续滑到玩家脚下")

func short_limit() -> void:
 var run:=formal()
 var a: Dictionary=run.combat.actors[EEL]
 var geometry:=short_limit_geometry()
 print("短追几何前提：",JSON.stringify(geometry))
 check(geometry.valid,"由正式直线岸段推导的射线先满足完整水中起点、连续交界至少55与玩家合法前提")
 if not geometry.valid: return
 var start:=Combat.vec(geometry.start)
 var target:=Combat.vec(geometry.target)
 a.position=geometry.start.duplicate()
 check(Catalog.Fenshui.water(Combat.vec(a.position)),"短追上限样例从已验证完整水中位置开始")
 var previous:=start
 var distance:=0.0
 var partial:=false
 var legal:=true
 var within_limit:=true
 var trail: Array=[]
 for i in 200:
  Combat.advance(run,target,0.02)
  var current:=Combat.vec(a.position)
  if not Catalog.Fenshui.water(current):
   partial=true
   distance+=previous.distance_to(current)
  elif partial: legal=false
  if not preload("res://scripts/maze/silverfish_combat.gd").allowed(current) or preload("res://scripts/maze/silverfish_combat.gd").dry(current): legal=false
  if distance>55.001: within_limit=false
  trail.append({"position":a.position.duplicate(),"origin":a.eel_origin.duplicate(),"phase":a.eel_phase,"distance":distance})
  previous=current
  if a.get("eel_phase","") in ["returning","stranded"]: break
 print("交界短追实际轨迹：",JSON.stringify(trail))
 check(partial and a.get("eel_phase","")=="returning","沿岸交界未完整上岸时55像素即转回水，不继续追人或蓄电")
 check(within_limit and distance<=55.001 and distance>=54.9 and legal and Combat.valid(run.combat),"短追上限实际55且路径可保存")
 var hp: float=run.combat.hp
 var cancelled: bool=a.mode!="windup" and a.windup==0
 var return_trail: Array=[]
 for i in 200:
  previous=Combat.vec(a.position)
  Combat.advance(run,target,0.02)
  var current:=Combat.vec(a.position)
  if current.distance_to(previous)>1.101 or not preload("res://scripts/maze/silverfish_combat.gd").allowed(current): legal=false
  if a.mode=="windup" or a.windup>0: cancelled=false
  return_trail.append({"position":a.position.duplicate(),"phase":a.eel_phase,"windup":a.windup,"hero_hp":run.combat.hp})
  if a.eel_phase=="forming": break
 print("截断回水实际轨迹：",JSON.stringify(return_trail))
 check(a.eel_phase=="forming" and run.combat.hp==hp and cancelled and legal,"交界短追截断后合法回水且未补发电击")

func short_limit_geometry() -> Dictionary:
 # 固定使用正式中央岸路的长直线段；不是按战斗结果随机筛选绿点。
 var road: Dictionary=Roads.dry_paths()[1]
 var first: Vector2=road.points[12]
 var last: Vector2=road.points[13]
 var tangent:=first.direction_to(last)
 var normal:=Vector2(-tangent.y,tangent.x)
 var start: Vector2=first+tangent*20.0+normal*(float(road.width)+float(Catalog.Fenshui.BODY_RADIUS)+2.0)
 var target:=last-tangent*20.0+normal*float(road.width)
 var result: Dictionary={"segment":[Combat.pack(first),Combat.pack(last)],"width":road.width,"body_radius":Catalog.Fenshui.BODY_RADIUS,"tangent":Combat.pack(tangent),"normal":Combat.pack(normal),"start":Combat.pack(start),"target":Combat.pack(target),"sampling":0.5,"valid":true,"partial_length":0.0,"samples":[]}
 var Ground=preload("res://scripts/maze/silverfish_combat.gd")
 var started:=false
 var previous: Vector2=start
 if not Catalog.Fenshui.water(start): result.valid=false
 var steps:=maxi(1,ceili(start.distance_to(target)/0.5))
 for i in range(steps+1):
  var point: Vector2=start.lerp(target,float(i)/steps)
  var wet: bool=Catalog.Fenshui.water(point)
  var dry: bool=Ground.dry(point)
  var allowed: bool=Ground.allowed(point)
  if not allowed or not Roads.is_walkable(point,Roads.FOOT_RADIUS) or Catalog.Fenshui.protected(point): result.valid=false
  if not wet:
   started=true
   result.partial_length+=previous.distance_to(point)
  elif started: result.valid=false
  if dry: result.valid=false
  result.samples.append({"position":Combat.pack(point),"water":wet,"dry":dry,"allowed":allowed})
  previous=point
 result.valid=result.valid and started and result.partial_length>=57.0
 return result
