extends "res://tools/tests/enjoy_audio.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(_heard)
 _check(GameAudio.STREAMS[&"order_accepted"]==GameAudio.STREAMS[&"serve_correct"] and GameAudio._players[&"order_accepted"].volume_db==-6.0,"接单复用交付素材及-6dB")
 _seed_cycle()
 sm.data.restaurant_arrival_lesson_v1={"phase":"done"}
 sm.data[Day.KEY].arrival_left=0.0
 var order: Dictionary=sm.ensure_restaurant_customer().order
 sm.advance_restaurant_customer(order.id,"arriving","front")
 scene=RESTAURANT.instantiate()
 get_tree().root.add_child(scene)
 get_tree().current_scene=scene
 await get_tree().create_timer(0.5).timeout
 var player=scene.get_node("Player")
 player.position=_stand(scene.get_node("InteractPoints/Register"))
 player.last_valid=player.position
 await get_tree().create_timer(0.2).timeout
 var path: String=sm._active_save_path
 sm._active_save_path=""
 cues.clear()
 await _send_key(KEY_E)
 _check(cues.count(&"order_accepted")==0,"接单保存失败不响")
 sm._active_save_path=path
 await _send_key(KEY_E)
 _check(cues.count(&"order_accepted")==1,"真实E接单成功只响一次")
 await _send_key(KEY_E)
 _check(cues.count(&"order_accepted")==1,"重复E不重播接单提示")
 await get_tree().create_timer(3.0).timeout
 _check(cues.count(&"food_enjoy")==0 and cues.count(&"water_enjoy")==0,"接单提示不触发赞叹")
 await _shot("order_accepted")
 scene.queue_free()
 await get_tree().process_frame
 var guest=load("res://scenes/guest_placeholder.tscn").instantiate()
 get_tree().root.add_child(guest)
 cues.clear()
 guest.settle_prone()
 guest.play_seating()
 _check(guest.seating_phase=="rising" and cues.count(&"customer_seated")==1,"铁山从地上起身立即播放音效")
 guest.play_seating()
 await get_tree().create_timer(7.0).timeout
 _check(guest.seating_completed and cues.count(&"customer_seated")==1,"铁山完整落座仅响一次")
 guest.play_seating()
 guest.settle_seated()
 _check(cues.count(&"customer_seated")==1,"重复播放和读档坐姿不补播")
 guest.settle_prone()
 guest.play_seating()
 await get_tree().create_timer(0.1).timeout
 guest.settle_seated()
 await get_tree().create_timer(2.0).timeout
 _check(cues.count(&"customer_seated")==2,"再次起身响一次，中途取消不补播")
 guest.queue_free()
 await get_tree().process_frame
 await _first_order()
 _check(sm.audio_guard_blocked==0,"写盘仅在隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
