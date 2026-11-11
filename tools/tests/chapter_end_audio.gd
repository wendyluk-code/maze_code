extends "res://tools/tests/chapter_ending_input.gd"
var sounds: Array[StringName]=[]
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(func(cue: StringName): sounds.append(cue))
 _seed()
 for step in ["party","home","maze"]: sm.advance_chapter_1_outro(step)
 await _open_scene()
 _check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro._ending.visible,240),"真实章末蒙层显示")
 _check(sounds.count(&"cooking_complete")==1 and GameAudio._players[&"cooking_complete"].volume_db==-16.0,"显示时播放一次烹饪成功音，沿用-16dB")
 await get_tree().create_timer(3.0).timeout
 _check(sounds.count(&"cooking_complete")==1,"停留不重播")
 await _shot("chapter_end_audio")
 var path: String=sm._active_save_path
 sm._active_save_path=""
 await _send_key(KEY_E)
 _check(sm.chapter_1_outro_state()=="title" and sounds.count(&"cooking_complete")==1,"保存失败停留蒙层且不重播")
 sm._active_save_path=path
 await _send_key(KEY_E)
 _check(await _wait_until(func(): return not tm.active,120),"继续后正常关闭")
 _check(sounds.count(&"cooking_complete")==1,"继续不重播")
 await _close_scene()
 _check(sm.audio_guard_blocked==0,"写盘仅限隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
