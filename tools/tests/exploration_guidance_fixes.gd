extends "res://tools/tests/first_exploration.gd"
const Guide := preload("res://scripts/ch2_exploration_guide.gd")
func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  DisplayServer.window_set_size(resolution)
  suffix=str(resolution.x)
  _completed()
  sm.complete_chapter_1()
  tm.active=false
  var restaurant=load("res://scenes/restaurant_map_2d.tscn").instantiate()
  get_tree().root.add_child(restaurant)
  get_tree().current_scene=restaurant
  await get_tree().create_timer(0.6).timeout
  var hud=get_tree().get_first_node_in_group("restaurant_hud")
  hud._open_confirmation("迷宫")
  hud.show_toast("提示层级验证")
  _check(hud.exploration_guide.guide.hint_panel.get_canvas_layer_node().layer < hud.layer,"常驻提示低于弹窗")
  _check(hud.toast_label.get_canvas_layer_node().layer < hud.layer,"Toast低于弹窗")
  await _shot_gate("modal_notice_"+suffix)
  restaurant.queue_free()
  await get_tree().process_frame
  _check(Run.begin(sm,Roads.SPAWN).success,"开始首次探索")
  sm.data[Gate.KEY]="active"
  sm.data[Guide.KEY]={"step":"explore","seen":{"05_power":true,"05_switch":true},"banked":{},"revision":2}
  maze=load("res://scenes/maze_entry.tscn").instantiate()
  get_tree().root.add_child(maze)
  get_tree().current_scene=maze
  await get_tree().create_timer(0.7).timeout
  var tutorial=maze.exploration_guide
  var camera=get_viewport().get_camera_2d()
  var original: Vector2=camera.global_position
  var original_zoom: Vector2=camera.zoom
  tutorial._start_bag_lesson()
  await get_tree().create_timer(0.85).timeout
  var focused: Vector2=camera.global_position
  _check(focused.distance_to(original)>5,"教学镜头移向终点")
  await _send_key(KEY_E)
  await _send_key(KEY_E)
  await get_tree().create_timer(0.25).timeout
  _check(tutorial.returning_camera and camera.global_position.distance_to(focused)>1 and camera.global_position.distance_to(original)>1,"回程具有平移中间态")
  _check(maze.player.input_locked,"平移期间仍锁定玩家")
  await _shot_gate("camera_return_mid_"+suffix)
  await get_tree().create_timer(0.6).timeout
  _check(not tutorial.returning_camera and camera.zoom.is_equal_approx(original_zoom) and not maze.player.input_locked,"回程结束恢复镜头和输入")
  await _shot_gate("camera_restored_"+suffix)
  maze.player.position=Vector2(116,724)
  for actor in sm.data[Run.KEY].combat.actors.values(): actor.mode="idle"
  sm.data[Run.KEY].combat.shots=[]
  sm.data[Run.KEY].combat.enemy_shots=[]
  await get_tree().process_frame
  maze._open_confirmation("下一区域")
  await get_tree().process_frame
  _check(maze.confirmation.visible and tutorial.reading and tutorial.lesson_id==Guide.RETURN_LESSON,"首次打开显示结束探索教学")
  _check(tutorial.guide.dialog._lines==[Guide.RETURN_LINE],"芽芽提示语准确")
  _check(tutorial.operation_glows.size()==1 and tutorial.allowed[0]==maze.confirmation.cancel_button,"仅结束探索按钮闪烁")
  var rect: Vector4=tutorial.guide.dim.material.get_shader_parameter("ingredients_rect")
  _check(rect.z>400 and rect.w>100,"蒙层挖空整个弹窗")
  await get_tree().create_timer(0.1).timeout
  await _send_key(KEY_E)
  await _shot_gate("return_lesson_"+suffix)
  await _send_key(KEY_E)
  await get_tree().process_frame
  _check(not tutorial.reading and tutorial.operation_glows.size()==1,"对白后继续闪烁")
  var strength: float=tutorial.operation_glows[0].get_theme_stylebox("panel").shadow_color.a
  await get_tree().create_timer(0.25).timeout
  _check(absf(tutorial.operation_glows[0].get_theme_stylebox("panel").shadow_color.a-strength)>0.02,"实际高亮动画变化")
  maze._close_confirmation()
  _check(tutorial.operation_glows.is_empty() and not maze.player.input_locked,"关闭清除闪烁并恢复输入")
  sm.save()
  sm.load_data()
  maze._open_confirmation("下一区域")
  await get_tree().process_frame
  _check(not tutorial.reading and tutorial.operation_glows.size()==1,"读档后再次打开只闪烁不重复对白")
  await _shot_gate("return_repeat_"+suffix)
  maze._close_confirmation()
  sm.data[Gate.KEY]="done"
  maze._open_confirmation("下一区域")
  await get_tree().process_frame
  _check(maze.confirmation.visible and not tutorial.reading and tutorial.operation_glows.is_empty(),"后续探索没有教学或闪烁")
  maze._close_confirmation()
  tutorial._start_bag_lesson()
  await get_tree().create_timer(0.8).timeout
  tutorial._read_done()
  await get_tree().create_timer(0.2).timeout
  tutorial._clear()
  _check(not tutorial.returning_camera and not maze.player.input_locked and camera.is_processing(),"中断回程清理镜头和输入")
  maze.queue_free()
  await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"所有写档位于隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
