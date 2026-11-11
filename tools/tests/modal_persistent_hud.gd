extends "res://tools/tests/first_exploration.gd"
func _assert_hud(label: String) -> void:
 await get_tree().create_timer(0.08).timeout
 _check(maze._task_host.is_visible_in_tree() and maze.gold_counter.is_visible_in_tree(),label+"保留任务金币")
 _check(maze.backpack_entry.is_visible_in_tree() and maze.backpack_entry.disabled,label+"背包可见且禁用")
 _check(maze.capture_flow.skill_bar.is_visible_in_tree() and maze.map_ui.mini_button.is_visible_in_tree(),label+"保留技能和小地图")
 var before: bool=maze.task_tracker._expanded
 await _click(maze.backpack_entry)
 await _click(maze.task_tracker._task_button)
 _check(not maze.backpack_warehouse.visible and maze.task_tracker._expanded==before,label+"不可穿透")
 await _shot_gate(label)
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  DisplayServer.window_set_size(size)
  _completed()
  sm.complete_chapter_1()
  tm.active=false
  Run.begin(sm,Roads.SPAWN)
  sm.data[Gate.KEY]="done"
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"revision":2}
  maze=load("res://scenes/maze_entry.tscn").instantiate()
  get_tree().root.add_child(maze)
  get_tree().current_scene=maze
  await get_tree().create_timer(0.7).timeout
  maze.task_tracker._toggle_tasks()
  await get_tree().create_timer(0.3).timeout
  var flow=maze.capture_flow
  flow._lock()
  flow.attempt.present(Run.monster_for(Run.snapshot(sm),"slime_1"),Run.snapshot(sm),true,8)
  await _assert_hud("capture_"+str(size.x))
  flow.attempt.hide()
  flow._unlock()
  flow._open_character_details("yaya")
  await _assert_hud("details_"+str(size.x))
  flow.character_details.hide()
  flow._close_character_details()
  maze.map_ui.open_map()
  await _assert_hud("map_"+str(size.x))
  maze.map_ui.close_map()
  maze.player.position=Vector2(116,724)
  for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
  sm.data[Run.KEY].combat.shots=[]
  sm.data[Run.KEY].combat.enemy_shots=[]
  maze._open_confirmation("下一区域")
  await _assert_hud("destination_"+str(size.x))
  maze._close_confirmation()
  await get_tree().create_timer(0.08).timeout
  _check(not maze.backpack_entry.disabled and not maze.player.input_locked,"关闭恢复操作")
  maze.queue_free()
  await get_tree().create_timer(0.08).timeout
 _check(sm.audio_guard_blocked==0,"未写正式档")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)

