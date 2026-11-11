extends "res://tools/tests/card_art_12_party_scene.gd"
var cues: Array[StringName] = []
func _heard(cue: StringName) -> void:
 cues.append(cue)
 _check(GameAudio._players[cue].playing,"实际音效播放器启动："+str(cue))
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(_heard)
 _seed()
 await _open_scene()
 _check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and not tm._chapter_outro._busy,180),"真实入队展示完成")
 var outro=tm._chapter_outro
 _check(cues.count(&"party_join")==1 and cues.count(&"cooking_complete")==0,"入队替换为附件16，不叠加旧提示音")
 _check(GameAudio._players[&"party_join"].volume_db == -16.0,"入队沿用-16dB")
 await _shot("party_join_audio")
 await _send_key(KEY_E)
 _check(await _wait_until(func(): return outro.phase=="home" and not outro._busy,180),"展示冒险者之家对白")
 _check(cues.count(&"yaya_home_hint")==0 and cues.count(&"yaya_maze_hint")==0,"之家教学不播放专属提示音")
 var home_state: Dictionary=sm.data.duplicate(true)
 await _send_key(KEY_E)
 _check(cues.count(&"yaya_home_hint")==0,"补全文字不播放专属提示音")
 await _shot("home_hint_audio")
 var path: String=sm._active_save_path
 sm._active_save_path=""
 outro._advance("home")
 await get_tree().create_timer(1.0).timeout
 _check(outro.phase=="home" and cues.count(&"yaya_home_hint")==0,"保存失败重新显示无专属提示音")
 sm._active_save_path=path
 outro._advance("home")
 _check(await _wait_until(func(): return outro.phase=="maze" and not outro._busy,180),"展示迷宫入口对白")
 _check(cues.count(&"yaya_maze_hint")==0 and not GameAudio._players[&"yaya_home_hint"].playing,"迷宫教学不播放专属提示音")
 await _send_key(KEY_E)
 _check(cues.count(&"yaya_maze_hint")==0,"迷宫文字补全无专属提示音")
 await _shot("maze_hint_audio")
 await _close_scene()
 _check(not GameAudio._players[&"yaya_maze_hint"].playing,"取消和离场停止对白音")
 sm.data=home_state
 _check(sm.save(),"隔离保存之家检查点")
 sm.load_data()
 cues.clear()
 await _open_scene()
 _check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro.phase=="home" and not tm._chapter_outro._busy,180),"读档恢复正确对白")
 _check(cues.count(&"yaya_home_hint")==0 and cues.count(&"party_join")==0 and cues.count(&"yaya_maze_hint")==0,"读档不补播教学提示或入队音")
 await _close_scene()
 _check(sm.audio_guard_blocked==0,"所有存档写入均在隔离根内")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
