extends "res://tools/tests/audio_interactions.gd"

func _run() -> void:
 sm = get_node("/root/SaveManager")
 tm = get_node("/root/TutorialManager")
 evidence = _arg("--output-dir=")
 _check(_verify_isolation(), "隔离正式存档")
 if failures: get_tree().quit(1); return
 GameAudio.cue_played.connect(_heard)
 for kind in ["food","water","wrong","bad_water","unwanted","save_failed"]:
  await _service_audio(kind)
 await _arrival_feedback()
 await _combat_feedback()
 await _capture_audio(false)
 for player in GameAudio._players.values(): player.stop()
 await get_tree().create_timer(0.15).timeout
 var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)

func _arrival_feedback() -> void:
 _seed_cycle()
 sm.data[Day.KEY].arrival_left = 0.0
 var order: Dictionary = sm.ensure_restaurant_customer().order
 cues.clear()
 scene = RESTAURANT.instantiate()
 get_tree().root.add_child(scene)
 get_tree().current_scene = scene
 await get_tree().create_timer(0.8).timeout
 var flow = get_tree().get_first_node_in_group("restaurant_hud").customer_flow
 _check(cues.count(&"customer_arrival") == 1, "顾客到前台提示一次")
 flow._sync()
 _check(cues.count(&"customer_arrival") == 1, "刷新顾客不重播到店音")
 sm.data.restaurant_arrival_lesson_v1 = {"phase":"done"}
 flow._first_arrival_tutorial_done = true
 for reason in ["front_timeout","drink_timeout","timeout","wrong_dish","bad_drink","spoiled_drink","question"]:
  cues.clear()
  flow.show_feedback(order.id, reason)
  flow.show_feedback(order.id, reason)
  _check(cues.count(&"failure") == 1, "失败反馈重复展示不重播：" + reason)
 await _shot("customer_feedback_audio")
 scene.queue_free()
 await get_tree().process_frame

func _combat_feedback() -> void:
 _completed()
 sm.data["first_exploration_gate_v1"] = "done"
 sm.data.ch2_guide_01 = {"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 tm.active = false
 sm.cancel_maze_entry()
 maze = load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene = maze
 await get_tree().create_timer(0.7).timeout
 var flow = maze.capture_flow
 flow.set_process(false)
 flow.window_focused = true
 var baseline: Dictionary = sm.data.duplicate(true)
 var start: int = GameAudio._hit_index
 for i in 4:
  sm.data = baseline.duplicate(true)
  var c: Dictionary = sm.data[Run.KEY].combat
  for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status = "skipped"
  sm.data[Run.KEY].monsters.slime_1.status = "alive"
  var pos: Vector2 = Run.Combat.vec(c.actors.slime_1.position)
  maze.player.position = Run.Roads.move_on_road(pos, Vector2(0,-25))
  c.hero = Run.Combat.pack(maze.player.position)
  c.actors.slime_1.position = Run.Combat.pack(pos)
  c.actors.slime_1.cooldown = 10.0
  c.attack = 1
  c.cooldown = 0.0
  c.action_left = 0.0
  var fired := Run.combat_attack(sm,maze.player.position,maze.player.position.direction_to(pos))
  _check(fired.success and fired.get("fired",false), "实际出招建立弹道", {"result":fired,"valid":Run.valid(sm.data[Run.KEY]),"walkable":Run.Roads.is_walkable(maze.player.position),"pos":str(maze.player.position),"paused":flow.combat_paused()})
  cues.clear()
  for tick in 12: flow._process(0.05)
  _check(cues.count(StringName("hit_%02d" % ((start+i)%3+1))) == 1, "实际命中三音循环：" + str(i))
 sm.data = baseline.duplicate(true)
 var c: Dictionary = sm.data[Run.KEY].combat
 var pos: Vector2 = Run.Combat.vec(c.actors.lizard_1.position)
 maze.player.position = Run.Roads.move_on_road(pos,Vector2(15,0))
 c.hero = Run.Combat.pack(maze.player.position)
 for id in sm.data[Run.KEY].monsters: sm.data[Run.KEY].monsters[id].status = "skipped"
 sm.data[Run.KEY].monsters.lizard_1.status = "alive"
 c.actors.lizard_1.position = Run.Combat.pack(pos)
 c.actors.lizard_1.mode = "windup"
 c.actors.lizard_1.windup = 0.01
 cues.clear()
 var hp: float = c.hp
 flow._process(0.05)
 _check(sm.data[Run.KEY].combat.hp < hp and cues.count(&"hero_hurt") == 1, "真实扣血一次受伤音", {"hp_before":hp,"hp_after":sm.data[Run.KEY].combat.hp,"paused":flow.combat_paused(),"valid":Run.valid(sm.data[Run.KEY])})
 cues.clear()
 flow.dialog.present(false,"slime",false)
 _check(cues.count(&"failure") == 1, "战斗失败一次统一音")
 cues.clear()
 flow.dialog.present_exploration_failure("slime")
 _check(cues.count(&"failure") == 1, "探索失败不与战斗失败重复")
 await _shot("exploration_failure_audio")
 maze.queue_free()
 await get_tree().process_frame
