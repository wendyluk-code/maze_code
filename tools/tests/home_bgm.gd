extends "res://tools/tests/enjoy_audio.gd"
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 _seed_cycle()
 scene=RESTAURANT.instantiate()
 get_tree().root.add_child(scene)
 get_tree().current_scene=scene
 await get_tree().create_timer(0.5).timeout
 GameAudio._sync_maze_music()
 var hud=get_tree().get_first_node_in_group("restaurant_hud")
 hud._open_confirmation("冒险者之家")
 _check(GameAudio.restaurant_music.playing and not GameAudio.home_music.playing,"确认前保留餐厅音乐")
 var early := [false]
 var observe: Callable=func(node: Node):
  if node.scene_file_path=="res://scenes/adventurer_home.tscn":
   early[0]=GameAudio.home_music.playing and not GameAudio.restaurant_music.playing and not node.is_node_ready()
 get_tree().node_added.connect(observe)
 hud._confirm_destination()
 _check(early[0],"之家尚未ready时已经切换音乐")
 get_tree().node_added.disconnect(observe)
 var page=get_tree().get_first_node_in_group("adventurer_home")
 _check(is_instance_valid(page) and GameAudio.home_music.playing and not GameAudio.maze_music.playing,"页面打开音乐独占播放")
 _check(GameAudio.mix.cue_db("music_home")==-6.0,"之家音乐设置-6dB")
 _check(GameAudio.home_music.stream.loop and absf(GameAudio.home_music.stream.get_length()-180)<0.1,"三分钟素材循环")
 await get_tree().create_timer(0.4).timeout
 var pos: float=GameAudio.home_music.get_playback_position()
 GameAudio._sync_maze_music()
 preload("res://scripts/ui/adventurer_home.gd").open_page(get_tree())
 await get_tree().create_timer(0.2).timeout
 _check(GameAudio.home_music.get_playback_position()>pos,"同步及重复打开不重播")
 await _shot("adventurer_home_music")
 page.close_page()
 _check(is_instance_valid(page) and page.is_inside_tree() and GameAudio.restaurant_music.playing and not GameAudio.home_music.playing,"返回操作时页面尚在即切回餐厅")
 await get_tree().process_frame
 _check(not is_instance_valid(page) and scene.process_mode!=Node.PROCESS_MODE_DISABLED,"关闭恢复餐厅")
 GameAudio.music_for_destination("res://scenes/maze_entry.tscn")
 _check(GameAudio.maze_music.playing and not GameAudio.home_music.playing and not GameAudio.restaurant_music.playing,"迷宫切换仍独占播放")
 scene.queue_free()
 await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"写盘仅隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
