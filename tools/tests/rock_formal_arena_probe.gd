extends "res://tools/tests/rock_lunge_flow.gd"
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _completed()
 sm.cancel_maze_entry()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 Run.begin(sm,Roads.SPAWN)
 Run.change_region(sm,"salt_pool",Salt.SPAWN)
 var baseline: Dictionary=Run.snapshot(sm)
 for id in baseline.monsters:
  if id!=Boss.ID: baseline.monsters[id].status="skipped"
 for hero_start in [Vector2(780,360),Vector2(800,360),Vector2(820,360),Vector2(850,350),Vector2(900,350),Vector2(930,380),Vector2(930,420),Vector2(930,450),Vector2(900,470),Vector2(820,450),Vector2(780,440)]:
  if not Salt.is_walkable(hero_start) or not Run.Combat.Rock.roar_clear(Boss.HOME,hero_start): continue
  var run: Dictionary=baseline.duplicate(true)
  var c: Dictionary=run.combat
  var a: Dictionary=c.actors[Boss.ID]
  a.position=Run.Combat.pack(Boss.HOME)
  a.mode="chase"
  a.rock_phase="active"
  a.rock_reuse=0.0
  var hero: Vector2=hero_start
  for i in 600:
   Run.Combat.advance(run,hero,0.05)
   hero=Run.Combat.vec(c.hero)
   if a.rock_phase in ["rest","stunned"] or c.hp<=0: break
  print("ARENA_PROBE start=",hero_start," releases=",a.get("rock_combo_released",0)," phase=",a.rock_phase," hp=",c.hp," note=",a.get("rock_combo_note",""))
  if int(a.get("rock_combo_released",0))==4 and a.rock_phase=="rest": break
 get_tree().quit()
