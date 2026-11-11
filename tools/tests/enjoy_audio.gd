extends "res://tools/tests/audio_interactions.gd"
func _seed_cycle() -> void:
 super._seed_cycle()
 # 本用例验收已完成教学后的交付；首次甘露水教学会锁定E输入。
 sm.data["ganlu_lessons_v1"] = {"warm":true,"iced":true,"ready":true,"spoiled":true}

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(_heard)
 GameAudio.cue_played.connect(func(cue: StringName):
  if cue in [&"food_enjoy",&"water_enjoy"]:
   _check(not GameAudio._players[&"serve_correct"].playing,"前置提示播完后才播放赞叹")
   _check(GameAudio._players[cue].volume_db==(-6.0 if cue==&"food_enjoy" else 0.0),"料理赞叹-6dB，喝水赞叹0dB"))
 for kind in ["food","water","wrong","bad_water","unwanted","save_failed"]: await _service_audio(kind,true)
 # 并发两笔交付仍按完整序列排队，离场取消待播。
 var owner_scene:=Node.new()
 get_tree().root.add_child(owner_scene)
 get_tree().current_scene=owner_scene
 cues.clear()
 GameAudio.play_served(&"food")
 GameAudio.play_served(&"water")
 await get_tree().create_timer(7.0).timeout
 _check(cues==[&"serve_correct",&"serve_correct"],"连续交付只按先后播放原提示，不追加赞叹")
 GameAudio._cancel_serve_sequence()
 cues.clear()
 GameAudio.play_served(&"food")
 owner_scene.queue_free()
 await get_tree().process_frame
 await get_tree().create_timer(2.7).timeout
 _check(cues==[&"serve_correct"] and GameAudio._serve_queue.is_empty(),"离开场景不遗留后续赞叹音")
 _check(sm.audio_guard_blocked==0,"写盘仅在隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
