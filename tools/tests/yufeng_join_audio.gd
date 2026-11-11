extends "res://tools/tests/yufeng_sitting_flow.gd"
var join_sounds := 0
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(func(cue: StringName):
  if cue==&"party_join":
   join_sounds+=1
   _check(is_instance_valid(maze) and maze.yf_encounter.join_overlay.visible,"双卡出现时触发入队音")
   _check(GameAudio._players[cue].playing and GameAudio._players[cue].volume_db==-16.0,"同款入队播放器启动，沿用-16dB"))
 await _story_flow()
 _check(join_sounds==1,"完整御风萨莉亚入队流程只播放一次")
 _check(sm.audio_guard_blocked==0,"写盘仅在隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
