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
 _completed()
 tm.active=false
 sm.data["first_exploration_gate_v1"]="done"
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 sm.cancel_maze_entry()
 sm.data["owned_characters_v1"]=["yaya","tieshan","yufeng","salia"]
 _check(sm.request_maze_entry(["yaya","tieshan","yufeng","salia"]).success,"准备四技能队伍")
 maze=load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 await get_tree().create_timer(0.8).timeout
 var flow=maze.capture_flow
 flow.window_focused=true
 for key in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_SPACE,KEY_TAB]:
  cues.clear()
  var previous: int=flow.display_run().combat.selected
  await _send_key(key)
  _check(flow.display_run().combat.selected!=previous and cues.count(&"interact")==1,"实际按键切换只响一次同款音："+str(key))
  if key!=KEY_TAB:
   await _send_key(key)
   _check(cues.count(&"interact")==1,"重复选择当前技能不响")
  var echo:=InputEventKey.new()
  echo.keycode=key
  echo.pressed=true
  echo.echo=true
  flow._unhandled_input(echo)
  _check(cues.count(&"interact")==1,"长按重复事件不响")
 await _shot("skill_keys_audio")
 cues.clear()
 maze.player.input_locked=true
 await _send_key(KEY_SPACE)
 _check(cues.is_empty(),"输入锁期间不播放切换音")
 maze.player.input_locked=false
 var path: String=sm._active_save_path
 sm._active_save_path=""
 await _send_key(KEY_SPACE)
 _check(cues.is_empty(),"保存失败不播放切换音")
 sm._active_save_path=path
 maze.queue_free()
 await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"写盘仅在隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
