extends "res://tools/tests/audio_interactions.gd"
var completed_count := 0
func _j(attempt: Control) -> void:
 var event := InputEventKey.new()
 event.keycode=KEY_J
 attempt._input(event)
 event.pressed=true
 attempt._input(event)
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(_heard)
 _completed()
 sm.data["first_exploration_gate_v1"]="done"
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 tm.active=false
 sm.cancel_maze_entry()
 maze=load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 await get_tree().create_timer(0.7).timeout
 var flow=maze.capture_flow
 sm.data[Run.KEY].combat.actors.slime_1.hp=0
 flow._encounter("slime_1")
 await get_tree().create_timer(0.3).timeout
 await flow._choose(true)
 flow._start_attempt()
 var attempt=flow.attempt
 _check(not attempt.struggle_audio.playing and attempt.mode=="throw","开始撒网时不播放挣扎")
 await get_tree().create_timer(0.7).timeout
 _check(not attempt.struggle_audio.playing and attempt.mode=="throw","撒网未完全罩住时持续无挣扎音")
 await get_tree().create_timer(0.5).timeout
 _check(attempt.struggle_audio.playing and attempt.mode=="restrain","撒网完成进入束缚时开始挣扎音")
 await get_tree().create_timer(1.5).timeout
 _check(attempt.struggle_audio.playing and attempt.mode=="suppress","进入镇压时挣扎不中断")
 # 每次有效J一个短音，按键轮换音高，两声部保留自然尾音。
 _check(attempt.press_audio.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED,"短ding不循环")
 for i in 9:
  _j(attempt)
  var voice=attempt.press_audio if i%2==0 else attempt.press_audio_second
  _check(voice.playing and voice.stream==attempt.PRESS_CLIPS[i%3] and attempt.press_index==(i+1)%3,"有效J按三种短音轮换："+str(i))
  await get_tree().create_timer(0.04).timeout
 _check(attempt.press_audio.playing and attempt.press_audio_second.playing,"快速连按最多两声部叠加")
 var held := InputEventKey.new()
 held.keycode=KEY_J
 held.pressed=true
 var before: int=attempt.press_index
 attempt._input(held)
 held.echo=true
 attempt._input(held)
 _check(attempt.press_index==before,"按住及系统重复键不额外响")
 await get_tree().create_timer(0.25).timeout
 _check(not attempt.press_audio.playing and not attempt.press_audio_second.playing,"停按后短音自然结束，无循环和排队")
 _j(attempt)
 _check(attempt.press_index==(before+1)%3,"停按后再次J播放下一种短音")
 attempt._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 _check(not attempt.press_audio.playing and not attempt.press_audio_second.playing,"失焦停止两个ding声部")
 attempt._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
 _j(attempt)
 attempt.set_process(false)
 attempt.phase_time=attempt.TIMEOUT-0.01
 attempt.guaranteed=true
 attempt._process(0.02)
 _check(attempt.mode=="complete" and attempt.flash_audio.playing,"满进度进入闪光并播放附件22")
 _check(not attempt.press_audio.playing and not attempt.press_audio_second.playing and not attempt.struggle_audio.playing,"闪光时过程音立即停止")
 attempt._process(0.6)
 _check(attempt.mode=="complete" and not flow.reward.visible,"原0.55秒动画结束仍等待完成音，不提前结算")
 await _shot("capture_flash_audio")
 await get_tree().create_timer(1.95).timeout
 attempt._process(0.02)
 _check(flow.reward.visible and not attempt.visible,"完成音结束后真实结算弹窗出现")
 _check(cues.count(&"capture_success")==2,"胜利与捕获成功各一次，原结果音保留")
 flow.reward.hide()
 attempt.present(Run.monster_for(Run.snapshot(sm),"slime_1"),Run.snapshot(sm),true,3)
 attempt.start()
 attempt.close()
 _check(not attempt.struggle_audio.playing and not attempt.flash_audio.playing and not attempt.press_audio.playing,"关闭立即停止全部过程音")
 maze.queue_free()
 await get_tree().process_frame
 await _capture_audio(false)
 _check(sm.audio_guard_blocked==0,"保存写入仅限隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
