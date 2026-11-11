extends "res://tools/tests/rock_lunge_flow.gd"
const Terrain=preload("res://scripts/maze/rock_charge_terrain.gd")
var cases: Dictionary={}
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"真实盐池入口")
 baseline=Run.snapshot(sm).duplicate(true)
 _find_cases()
 _check(Run.Combat.Rock.LUNGE_DISTANCE==160.0,"冲撞行程改为160")
 for kind in ["early","front","graze","late"]:
  _check(cases.has(kind),"真实水晶找到对照："+kind)
  if not cases.has(kind): continue
  var row: Dictionary=cases[kind]
  var run:=_setup(row)
  var a: Dictionary=run.combat.actors[Boss.ID]
  for i in 80:
   Run.Combat.Rock.advance(run,Vector2(200,200),0.01)
   if a.rock_phase!="lunge": break
  _check(a.rock_phase==("stunned" if kind=="front" else "lunge_recover"),"正面重撞才晕，其余收势："+kind,{"phase":a.rock_phase,"case":row})
  _check(Boss.allowed(Run.Combat.vec(a.position)),"撞击不穿障碍："+kind)
  if kind=="front": _check(a.rock_chain_left==0 and not a.rock_combo and a.rock_left==1.5,"重撞终止四连、弱点1.5秒")
  if kind=="early":
   run=_setup(row)
   a=run.combat.actors[Boss.ID]
   a.rock_phase="active"
   a.rock_combo=false
   Run.Combat.Rock.begin_lunge(a,row.origin+row.aim*120.0)
   _check(a.rock_phase!="lunge_charge","前方立即受阻不开始蓄力")
   var old: Vector2=row.origin
   run.combat.hero=Run.Combat.pack(row.origin+row.aim*8.0)
   for i in 20: Run.Combat.Rock.advance(run,Run.Combat.vec(run.combat.hero),0.01)
   _check(Run.Combat.vec(a.position).distance_to(old)>1.0 and a.rock_phase!="stunned","贴墙实际换站位而非原地自晕",{"origin":old,"position":a.position,"phase":a.rock_phase})
  if kind=="front":
   run=_setup(row)
   a=run.combat.actors[Boss.ID]
   Run.Combat.Rock.begin_lunge(a,row.origin+row.aim*120.0)
   _check(a.rock_phase=="lunge_charge","足够助跑仍可诱导正面撞击")
   var locked: Array=a.rock_aim.duplicate()
   Run.Combat.Rock.advance(run,row.origin-row.aim*120.0,0.2)
   _check(a.rock_aim==locked,"蓄力锁向后玩家侧移不追踪转向")
 var open:={"origin":Vector2(800,425),"aim":Vector2.RIGHT}
 var run:=_setup(open)
 var a: Dictionary=run.combat.actors[Boss.ID]
 for i in 80: Run.Combat.Rock.advance(run,Vector2(700,425),0.01)
 _check(Run.Combat.vec(a.position).distance_to(Vector2(960,425))<0.1 and a.rock_phase=="lunge_recover","真实空地完整160单位后收势")
 _check(Boss.TYPE.width==120.0,"显示仍为1.0倍")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"cases":cases},"  "))
 print("ROCK_IMPACT ",checks," checks; failures=",failures)
 get_tree().quit(1 if failures else 0)
func _setup(row: Dictionary) -> Dictionary:
 var run: Dictionary=baseline.duplicate(true)
 for id in run.monsters:
  if id!=Boss.ID: run.monsters[id].status="skipped"
 run.combat.hero=[200.0,200.0]
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.position=Run.Combat.pack(row.origin)
 a.mode="chase"
 a.rock_phase="lunge"
 a.rock_left=Run.Combat.Rock.LUNGE_DURATIONS.lunge
 a.rock_distance=0.0
 a.rock_aim=Run.Combat.pack(row.aim)
 a.rock_combo=true
 a.rock_chain_left=4
 a.rock_hit=false
 return run
func _find_cases() -> void:
 for y in range(260,481,12):
  for x in range(350,691,12):
   var origin:=Vector2(x,y)
   if not Boss.allowed(origin): continue
   for i in 16:
    var aim:=Vector2.RIGHT.rotated(i*TAU/16.0)
    var end:=Boss.move(origin,aim*Run.Combat.Rock.LUNGE_DISTANCE)
    var distance:=origin.distance_to(end)
    if distance>=Run.Combat.Rock.LUNGE_DISTANCE-0.1: continue
    var nearest:=INF
    var cosine:=0.0
    for group in Terrain.Crystals.SHAPES:
     for shape in group:
      for j in shape.size():
       var q:=Geometry2D.get_closest_point_to_segment(end,shape[j],shape[(j+1)%shape.size()])
       if end.distance_squared_to(q)<nearest:
        nearest=end.distance_squared_to(q)
        cosine=absf(aim.dot(end.direction_to(q)))
    if nearest>144: continue
    var kind:="early" if distance>2 and distance<20 else ("front" if distance>60 and distance<95 and cosine>0.85 else ("graze" if distance>60 and distance<110 and cosine<0.55 else ("late" if distance>Run.Combat.Rock.LUNGE_DISTANCE*0.92 and cosine>0.85 else "")))
    if kind!="" and not cases.has(kind): cases[kind]={"origin":origin,"aim":aim,"clearance":distance,"cosine":cosine}
    if cases.size()==4: return
