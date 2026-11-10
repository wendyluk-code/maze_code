extends "res://tools/tests/rock_lunge_flow.gd"
const Motion=preload("res://scripts/maze/rock_lunge_visual_mapping.gd")
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实盐池入口")
 var run: Dictionary=Run.snapshot(sm).duplicate(true)
 for id in run.monsters:
  if id!=Boss.ID: run.monsters[id].status="skipped"
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.position=[800.0,425.0]
 a.mode="chase"
 a.rock_phase="charge"
 a.rock_left=0.01
 a.rock_aim=[1.0,0.0]
 var point:=Vector2(900,425)
 run.combat.hero=Run.Combat.pack(point)
 Run.Combat.Rock.advance(run,point,0.02)
 _check(a.rock_combo and a.rock_chain_left==4,"真实咆哮命中建立四连")
 var charges: Array=[]
 var recovers: Array=[]
 var distance: Array=[]
 var bearings: Array=[]
 var phases: Array=[]
 var prior: String=a.rock_phase
 var clock:=0.0
 for i in 3000:
  Run.Combat.advance(run,Run.Combat.vec(run.combat.hero),0.01)
  clock+=0.01
  if a.rock_phase!=prior:
   phases.append({"time":clock,"phase":a.rock_phase,"position":a.position.duplicate(),"hero":run.combat.hero.duplicate(),"combo":a.get("rock_combo"),"target":a.get("rock_combo_target"),"stage":a.get("rock_combo_stage")})
   if a.rock_phase=="lunge_charge":
    charges.append(float(a.rock_left))
    bearings.append(Run.Combat.vec(a.rock_aim))
   if a.rock_phase=="lunge_recover":
    recovers.append(float(a.rock_left))
    distance.append(float(a.rock_distance))
  prior=a.rock_phase
  if a.rock_phase=="rest": break
 _check(charges==[1.1,0.85,0.85,1.3],"四冲蓄力有节奏差异",{"actual":charges})
 _check(recovers==[0.35,0.45,0.55,0.8],"四冲收势连续且末冲明确收尾",{"actual":recovers})
 _check(distance.size()==4 and distance.all(func(v): return v>30.0 and v<=Run.Combat.Rock.LUNGE_DISTANCE+0.001),"四冲均有真实位移且不超过160，命中时保留角色占位",{"actual":distance})
 _check(clock>=8.9 and clock<=28.0,"四连包含真实绕侧移动且有界",{"seconds":clock})
 var four_sides: bool=bearings.size()==4
 if four_sides:
  for i in 4:
   for j in range(i+1,4):
    if absf((bearings[i] as Vector2).angle_to(bearings[j]))<PI/4.0: four_sides=false
 _check(four_sides,"四冲来自不同侧面而非同向重复",{"bearings":bearings})
 _check(a.rock_phase=="rest" and a.rock_left==5.0 and not a.rock_combo,"末冲收尾后力竭5秒")
 for index in 4:
  a.rock_combo=true
  a.rock_chain_left=4-index
  var recover: float=Run.Combat.Rock.recover_duration(a)
  var pose: Dictionary=Motion.pose("lunge_recover",recover*0.1,recover,{},true,index==3)
  _check(pose.next_action==("exhausted" if index==3 else "charge"),"刹停不回待机，承接下一蓄力或力竭："+str(index))
  _check(pose.action!="idle" and pose.next_action!="idle","连段中不恢复闲置站姿："+str(index))
  var charge: float=Run.Combat.Rock.charge_duration(a)
  var source: Dictionary=Motion.pose("lunge_recover",0.0,recover,{},true,index==3)
  var entry: Dictionary=Motion.pose("rest" if index==3 else "lunge_charge",5.0 if index==3 else charge,5.0 if index==3 else charge,source,true,index==3)
  _check(entry.entry_mix==0.0,"连段衔接从前一实际姿态开始："+str(index))
 var final_charge: float=Run.Combat.Rock.charge_duration(a)
 a.rock_combo=false
 _check(Run.Combat.Rock.charge_duration(a)==1.2 and Run.Combat.Rock.recover_duration(a)==2.0,"普通冲撞时序不受四连改动影响")
 _check(final_charge==1.3,"第四冲有独立长蓄力读招")
 _check(not Run.Combat.Rock.can_lunge(Vector2(800,425),Vector2(830,425)),"贴身30单位不原地开始冲撞")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"phases":phases},"  "))
 print("ROCK_COMBO ",checks," checks; failures=",failures)
 get_tree().quit(1 if failures else 0)
