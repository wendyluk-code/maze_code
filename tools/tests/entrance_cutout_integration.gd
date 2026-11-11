extends "res://tools/tests/chapter_ending_input.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离正式存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  DisplayServer.window_set_size(resolution)
  suffix="_%dx%d" % [resolution.x,resolution.y]
  _seed()
  _check(sm.advance_chapter_1_outro("party").success,"进入已保存入口介绍")
  sm.load_data()
  await _open_scene()
  for which in ["home","maze"]:
   _check(await _wait_until(func(): return is_instance_valid(tm._chapter_outro) and tm._chapter_outro.phase==which and not tm._chapter_outro._busy,240),"正式对白阶段："+which)
   var guide=tm.guide
   await get_tree().process_frame
   var glow=tm._chapter_outro._entrance_highlight
   var expected: Rect2=scene.get_node("BG").get_global_transform_with_canvas()*glow.cutout_bounds
   var local: Rect2=guide.dim.get_global_transform().affine_inverse()*expected
   var actual: Vector4=guide.dim.material.get_shader_parameter("ingredients_rect")
   _check(actual.is_equal_approx(Vector4(local.position.x,local.position.y,local.size.x,local.size.y)),"真实暗幕镂空跟随入口："+which)
   _check(guide.dim.visible and not guide.dim.material.get_shader_parameter("circle_cutouts"),"使用可见圆角矩形暗幕："+which)
   _check(not expected.intersects(guide.dialog.get_global_rect()),"镂空不覆盖对白："+which)
   if resolution==Vector2i(1280,720):
    var approved:=Rect2(899,147,371,394) if which=="home" else Rect2(36,64,385,370)
    _check(expected.position.distance_to(approved.position)<1 and expected.size.distance_to(approved.size)<1,"与已确认绿框范围一致："+which)
   await _send_key(KEY_E)
   await _shot("entrance_"+which)
   await _send_key(KEY_E)
  _check(await _wait_until(func(): return tm._chapter_outro.phase=="title" and not tm._chapter_outro._busy,240),"对白结束进入标题")
  _check(tm.guide.entrance_cutout_target==null and tm.guide.dim.material.get_shader_parameter("ingredients_rect")==Vector4.ZERO,"标题阶段清除镂空")
  await _close_scene()
 await _resume_checks()
 _check(sm.audio_guard_blocked==0,"所有保存均在隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
