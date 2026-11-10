extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Map=preload("res://data/maze/fenshui_roads.gd")
const Skills=preload("res://scripts/maze/team_attack.gd")
var baseline: Dictionary
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离目录")
 if failures==0:
  _completed()
  sm.cancel_maze_entry()
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  _check(Run.begin(sm,Roads.SPAWN).success,"真实探索初始化")
  _check(Run.change_region(sm,"fenshui",Map.SPAWN).success,"真实分水庭初始化")
  baseline=Run.snapshot(sm).duplicate(true)
  for offset in [0.0,20.0,22.0,35.0]: _probe(offset)
  _probe(20.0,"hero")
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 print("YAYA_CONTACT ",checks," checks, ",failures," failures")
 get_tree().quit(1 if failures else 0)
func _probe(offset: float, weapon: String="yaya") -> void:
 var run: Dictionary=baseline.duplicate(true)
 var target:=Vector2(920,440)
 var hero:=Vector2(840,440+offset)
 var id: String="fenshui_silverfish_1"
 for key in run.monsters: run.monsters[key].status="alive" if key==id else "skipped"
 var c: Dictionary=run.combat
 c.actors[id].position=Skills.pack(target)
 c.hero=Skills.pack(hero)
 c.cooldown=0.0
 Skills.Tuning.initialized=true
 Skills.Tuning.values={"effect.yaya":{"burst_count":1,"speed":310}}
 Skills.select(run,1 if weapon=="yaya" else 0)
 _check(Skills.attack(run,hero,Vector2.RIGHT),"发射真实芽芽弹：偏移"+str(offset))
 var before: int=int(c.hits)
 for i in range(12):
  c.actors[id].hit_remaining=0.12
  c.actors[id].hit_velocity=[0.0,0.0]
  Run.Combat.advance(run,hero,0.05)
 var actual: bool=int(c.hits)>before
 var expected: bool=offset<=20.0 if weapon=="yaya" else offset<=14.0
 _check(actual==expected,weapon+"中心及实体边缘命中、实体外不命中：偏移"+str(offset),{"hits":c.hits-before,"hp":c.actors[id].hp,"position":c.actors[id].position,"remaining":c.shots.size()})
