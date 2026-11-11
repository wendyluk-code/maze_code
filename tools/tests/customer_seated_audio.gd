extends "res://tools/tests/audio_interactions.gd"
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(_heard)
 _check(GameAudio._players[&"customer_seated"].volume_db == -1.0,"落座音比默认提高5dB")
 for fail_save in [false,true]:
  _seed_cycle()
  sm.data.restaurant_arrival_lesson_v1={"phase":"done"}
  sm.data[Day.KEY].arrival_left=0.0
  var order: Dictionary=sm.ensure_restaurant_customer().order
  _check(sm.advance_restaurant_customer(order.id,"arriving","front").success,"顾客到前台")
  scene=RESTAURANT.instantiate()
  get_tree().root.add_child(scene)
  get_tree().current_scene=scene
  await get_tree().create_timer(0.5).timeout
  var flow=get_tree().get_first_node_in_group("restaurant_hud").customer_flow
  cues.clear()
  _check(sm.accept_restaurant_customer(order.id).success,"实际接单")
  var path: String=sm._active_save_path
  if fail_save: sm._active_save_path=""
  flow._sync()
  _check(cues.count(&"customer_seated")==0,"接单瞬间不提前播放")
  await get_tree().create_timer(0.9).timeout
  if fail_save:
   _check(cues.count(&"customer_seated")==0,"落座保存失败不响")
   sm._active_save_path=path
   flow._sync()
   await get_tree().create_timer(1.0).timeout
  _check(sm.restaurant_customer_order(order.id).phase=="waiting" and cues.count(&"customer_seated")==1,"实际落座成功一次音效")
  flow._sync()
  flow._advance(order.id,"seating","waiting")
  _check(cues.count(&"customer_seated")==1,"重复状态提交和刷新不重播")
  await _shot("seated_audio_"+str(fail_save))
  scene.queue_free()
  await get_tree().process_frame
  cues.clear()
  scene=RESTAURANT.instantiate()
  get_tree().root.add_child(scene)
  get_tree().current_scene=scene
  await get_tree().create_timer(0.5).timeout
  _check(cues.count(&"customer_seated")==0,"重入恢复已落座顾客不补播")
  scene.queue_free()
  await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"存档写入仅限隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
