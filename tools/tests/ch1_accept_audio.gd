extends "res://tools/tests/ch1_order_explain_input.gd"
var heard: Array[StringName]=[]
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"正式存档隔离")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 sm._active_save_path="user://ch1-accept-audio.json"
 GameAudio.cue_played.connect(func(cue: StringName): heard.append(cue))
 await _prepare_scene()
 # 首章步骤已调整，按阶段/类型推进，不依赖旧夹具的固定索引6、8。
 var deadline=Time.get_ticks_msec()+10000
 while not (_is_stage_type(3,"move_to") or _is_stage_type(3,"interact")) and Time.get_ticks_msec()<deadline:
  if scene.get_node("UIOverlay/TutorialGuide").dialog.visible:
   await _send_key(KEY_E)
  await get_tree().process_frame
 _check(_is_stage_type(3,"move_to") or _is_stage_type(3,"interact"),"对白进入前台教学")
 var player=scene.get_node("Player")
 player.global_position=_stand(scene.get_node("InteractPoints/Register"))
 _check(await _wait_until(func(): return _is_stage_type(3,"interact"),240),"真实前台接单步骤")
 var path: String=sm._active_save_path
 sm._active_save_path=""
 heard.clear()
 await _send_key(KEY_E)
 _check(heard.count(&"order_accepted")==0,"铁山接单保存失败无提示音")
 sm._active_save_path=path
 await _send_key(KEY_E)
 _check(sm.has_active_order() and heard.count(&"order_accepted")==0,"铁山真实E接单成功不播放接单音")
 _check(heard.count(&"interact")>0,"铁山接单保留E点击音")
 await _send_key(KEY_E)
 _check(heard.count(&"order_accepted")==0,"重复E也不播放接单音")
 await _capture(_arg("--output-dir="),"ch1_order_accept")
 tm._cancel_current_run()
 scene.queue_free()
 await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"写盘限制在隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var f=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 f.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
