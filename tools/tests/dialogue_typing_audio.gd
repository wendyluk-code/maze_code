extends "res://tools/tests/card_art_12_party_scene.gd"
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 var parent := Control.new()
 add_child(parent)
 var dialog=load("res://scenes/ui/dialog_box.tscn").instantiate()
 parent.add_child(dialog)
 var audio: AudioStreamPlayer=dialog._typing_audio
 _check(audio.volume_db==2.0,"对白循环音提高8dB至+2dB")
 var capture := AudioEffectCapture.new()
 capture.buffer_length=2.0
 AudioServer.add_bus_effect(0,capture)
 var effect_index := AudioServer.get_bus_effect_count(0)-1
 dialog.start("",["这是一段用于验证循环打字音效的较长对白。".repeat(8),"第二句对白同样应该开始播放声音。"])
 _check(audio.playing and audio.stream.loop,"对白出现开始循环音")
 await get_tree().create_timer(0.8).timeout
 var peak:=0.0
 for sample in capture.get_buffer(capture.get_frames_available()): peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
 _check(peak>0.00001,"实际混音非静音")
 await _send_key(KEY_E)
 _check(not audio.playing,"按E补全立即停止")
 await _send_key(KEY_E)
 _check(audio.playing and dialog._line_idx==1,"下一句重新播放")
 var click:=InputEventMouseButton.new()
 click.button_index=MOUSE_BUTTON_LEFT
 click.pressed=true
 dialog._input(click)
 _check(not audio.playing,"鼠标补全立即停止")
 dialog.start("",["测试"])
 await get_tree().create_timer(0.2).timeout
 _check(dialog._shown==2 and not audio.playing,"自然显示完毕停止")
 dialog.start("",[""])
 _check(not audio.playing,"空对白不播放")
 dialog.start("",["用于隐藏父窗口的较长对白文字。"])
 parent.hide()
 _check(not audio.playing,"父窗口隐藏立即停止")
 parent.show()
 _check(audio.playing,"重新显示未完成文字恢复播放")
 dialog.hide_box()
 _check(not audio.playing,"关闭对白立即停止")
 dialog.start("",["用于测试离开窗口后的长对白。"])
 dialog._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 _check(not audio.playing,"失焦停止")
 dialog._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
 _check(audio.playing,"回到窗口未完成文字继续")
 await _shot("dialogue_audio_component")
 parent.queue_free()
 await get_tree().process_frame
 _check(not is_instance_valid(audio),"离场释放循环播放器")
 AudioServer.remove_bus_effect(0,effect_index)
 capture = null
 # 实际首章教程对白（同组件的父级接管输入场景）。
 _seed()
 sm.advance_chapter_1_outro("party")
 await _open_scene()
 _check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro.phase=="home" and not tm._chapter_outro._busy,180),"真实餐厅之家对白出现")
 var live=tm.guide.dialog
 _check(live._typing_audio.playing,"教程共用对白循环音实际启动")
 _check(GameAudio._players[&"yaya_home_hint"].playing,"原剧情提示音保留")
 await _send_key(KEY_E)
 _check(not live._typing_audio.playing,"真实教程E补全停止循环音")
 await _shot("dialogue_audio_tutorial")
 await _close_scene()
 _check(sm.audio_guard_blocked==0,"写盘始终在隔离目录")
 GameAudio.set_world_music(&"")
 for player in GameAudio._players.values(): player.stop()
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)

