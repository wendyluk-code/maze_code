extends "res://tools/tests/rock_lunge_flow.gd"
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实盐池入口")
 baseline=Run.snapshot(sm).duplicate(true)
 var run: Dictionary=baseline.duplicate(true)
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.mode="chase"
 a.rock_phase="charge"
 a.rock_left=0.01
 a.rock_aim=[1.0,0.0]
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(50,0),0.02)
 _check(run.combat.hp<baseline.combat.hp,"咆哮真实命中")
 _check(is_equal_approx(float(run.combat.get("rock_slow_left",0)),5.0) and is_equal_approx(float(run.combat.get("rock_slow_factor",1)),0.05),"近档命中带来5秒5%剩余速度")
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(50,0),0.45)
 _check(a.rock_phase=="lunge_charge" and a.get("rock_chain_left",0)==4,"咆哮命中先进入四连而非提前力竭")
 _check(Run.Combat.valid(run.combat),"新状态可被原事务接受")
 run=baseline.duplicate(true)
 a=run.combat.actors[Boss.ID]
 a.mode="chase"
 a.rock_phase="charge"
 a.rock_left=0.01
 a.rock_aim=[1.0,0.0]
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(-50,0),0.02)
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(-50,0),0.45)
 _check(a.rock_phase=="rest" and is_equal_approx(float(a.rock_left),1.5),"咆哮未中直接力竭1.5秒")
 _check(float(run.combat.get("rock_slow_left",0))==0,"扇形外不附加减速")
 a.rock_reuse=0.0
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(-50,0),1.5)
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(50,0),0.01)
 _check(a.rock_phase=="lunge_charge","力竭后先恢复普通冲撞，不因四连耗尽冷却连续咆哮")
 _status_checks()
 _chain_checks()
 _motion_checks()
 _body_checks()
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("ROCK_FULL ",checks," checks; failures=",failures)
 get_tree().quit(1 if failures else 0)

func _status_checks() -> void:
 for sample in [[50.0,0.05],[130.0,0.15],[230.0,0.25]]:
  var run: Dictionary=baseline.duplicate(true)
  var c: Dictionary=run.combat
  Run.Combat.Rock.apply_slow(c,sample[0])
  _check(is_equal_approx(Run.Combat.Rock.slow_factor(c),sample[1]),"三档剩余速度："+str(sample[0]))
  Run.Combat.Rock.advance_status(c,2.0)
  _check(is_equal_approx(float(c.rock_slow_left),3.0),"减速独立计时")
  Run.Combat.Rock.apply_slow(c,230.0)
  _check(is_equal_approx(Run.Combat.Rock.slow_factor(c),sample[1]) and c.rock_slow_left==5.0,"重复弱档不覆盖强档，刷新5秒")
  Run.Combat.Rock.advance_status(c,5.0)
  _check(Run.Combat.Rock.slow_factor(c)==1.0,"5秒结束恢复原倍率")
 var run: Dictionary=baseline.duplicate(true)
 var c: Dictionary=run.combat
 Run.Combat.Rock.apply_slow(c,230)
 Run.Combat.Rock.apply_slow(c,50)
 _check(Run.Combat.Rock.slow_factor(c)==0.05,"更强档覆盖弱档但不相乘")
 c.rock_stun_left=2.0
 c.hurt_recovery_left=2.0
 var events: Array=[]
 c.hp-=1
 Run.Combat.PlayerHurt.record(c,c.hp+1,"physical",Boss.HOME,Boss.HOME+Vector2(10,0),events)
 _check(c.hurt_recovery_left==2.0,"其他普通受击不缩短已有冲撞眩晕")
 Run.Combat.PlayerHurt.advance(c,1.0)
 Run.Combat.Rock.advance_status(c,1.0)
 _check(c.rock_stun_left==1.0 and c.rock_slow_left==4.0,"眩晕和减速独立并行")
 c.hp=0
 Run.Combat.Rock.advance_status(c,0.0)
 _check(c.rock_slow_left==0.0 and c.rock_stun_left==0.0,"死亡清除两种控制状态")
 c.hp=36
 c.rock_slow_left=5.0
 c.rock_slow_factor=0.15
 c.region="fenshui"
 Run.Combat.Rock.advance_status(c,0.0)
 _check(c.rock_slow_left==0.0 and Run.Combat.Rock.slow_factor(c)==1.0,"离开盐池不残留减速")
 run=baseline.duplicate(true)
 run.combat.rock_slow_left=-1.0
 _check(not Run.Combat.valid(run.combat),"非法减速时钟拒绝提交")
 run.combat.rock_slow_left=2.0
 run.combat.rock_slow_factor=0.0
 _check(not Run.Combat.valid(run.combat),"非法倍率拒绝提交")

func _chain_checks() -> void:
 var start:=Vector2.INF
 for y in range(150,850,10):
  for x in range(150,1350,10):
   var p:=Vector2(x,y)
   if Boss.allowed(p) and Boss.allowed(p+Vector2(180,0)) and Boss.line(p,p+Vector2(180,0),Boss.BODY):
    start=p
    break
  if start!=Vector2.INF: break
 _check(start!=Vector2.INF,"真实盐池存在完整180直线测试地段")
 if start==Vector2.INF: return
 var run: Dictionary=baseline.duplicate(true)
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.mode="chase"
 a.position=Run.Combat.pack(start)
 a.rock_phase="rush"
 a.rock_left=0.01
 a.rock_combo=true
 a.rock_chain_left=4
 var target:=start+Vector2(230,0)
 Run.Combat.Rock.advance(run,target,0.02)
 for i in 4:
  _check(a.rock_phase=="lunge_charge" and a.rock_chain_left==4-i,"四连第%d次有真实前摇"%(i+1))
  var locked: Array=a.rock_aim.duplicate()
  Run.Combat.Rock.advance(run,target+Vector2(0,100),0.7)
  _check(a.rock_phase=="lunge" and a.rock_aim==locked,"前摇完成起冲，冲刺不追踪转向")
  for step in 24: Run.Combat.Rock.advance(run,target+Vector2(0,100),1.0/60.0)
  _check(a.rock_phase=="lunge_recover","完整距离后进入收势而非撞晕")
  target=start+Vector2(-50,0) if i%2==0 else start+Vector2(230,0)
  Run.Combat.Rock.advance(run,target,0.45)
  if i<3: _check(signf(float(a.rock_aim[0]))==(-1.0 if i%2==0 else 1.0),"下一次冲撞重新瞄准")
 _check(a.rock_phase=="rest" and a.rock_left==1.5 and a.rock_chain_left==0,"只在四次完成后力竭")
 run=baseline.duplicate(true)
 a=run.combat.actors[Boss.ID]
 a.mode="chase"
 a.rock_phase="lunge"
 a.rock_left=0.4
 a.rock_aim=[1.0,0.0]
 a.rock_combo=true
 a.rock_chain_left=4
 for i in 30:
  for id in run.monsters:
   if id!=Boss.ID: run.monsters[id].status="skipped"
  run.combat.hero=Run.Combat.pack(Boss.HOME+Vector2(0,100))
  Run.Combat.Rock.advance(run,Boss.HOME+Vector2(0,100),0.02)
  if a.rock_phase=="stunned": break
 _check(a.rock_phase=="stunned" and a.rock_chain_left==0 and not a.rock_combo,"撞障碍中断连段并清除剩余次数")

func _motion_checks() -> void:
 var run: Dictionary=baseline.duplicate(true)
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.mode="chase"
 a.rock_phase="lunge"
 a.rock_left=0.4
 a.rock_distance=0.0
 a.rock_aim=[1.0,0.0]
 Run.Combat.Rock.advance(run,Boss.HOME+Vector2(0,100),0.04)
 _check(float(a.rock_distance)<12.0,"冲撞起步有加速而非首帧满速滑动")
 var Mapping=preload("res://scripts/maze/rock_lunge_visual_mapping.gd")
 var pose: Dictionary=Mapping.pose("lunge_recover",0.45,0.45)
 _check(pose.get("action","")=="rush" and pose.get("frame",-1)==3,"收势从冲刺末姿开始而非跳回蓄力倒放")
 pose=Mapping.pose("charge",0.1,1.1)
 _check(pose.get("action","")=="charge" and pose.get("frame",-1)==3,"咆哮前摇末段保持蓄力不循环重来")
 pose=Mapping.pose("rush",0.0,0.45)
 _check(pose.get("action","")=="attack" and pose.get("frame",-1)==3,"咆哮释放按真实0.45秒完成收口帧")
 pose=Mapping.pose("rest",0.8,1.5)
 _check(pose.get("action","")=="charge","力竭使用低伏而非普通待机")

func _body_checks() -> void:
 var Bodies=preload("res://scripts/maze/rock_bodies.gd")
 var run: Dictionary=baseline.duplicate(true)
 var center:=Boss.HOME
 _check(not Bodies.step(run,"hero",center+Vector2(60,0),center+Vector2(30,0)),"角色不能走入兽的落地体积")
 _check(Bodies.step(run,"hero",center+Vector2(60,0),center+Vector2(70,0)),"角色可远离实体")
 _check(Bodies.step(run,"hero",center+Vector2(20,0),center+Vector2(30,0)),"旧重叠站位允许退出而非卡死")
 _check(Bodies.hero_contact(center,center+Vector2(10,0),center+Vector2(50,0)),"冲撞按实体前沿接触，不等待穿入中心")
 _check(Bodies.move(run,"hero",center+Vector2(80,0),center-Vector2(80,0)).x>center.x,"大步移动不能穿过实体")
