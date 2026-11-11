extends "res://tools/tests/first_exploration.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  DisplayServer.window_set_size(resolution)
  _completed()
  sm.complete_chapter_1()
  tm.active=false
  _check(Gate.departure(sm),"复现首次探索前阶段")
  var restaurant=load("res://scenes/restaurant_map_2d.tscn").instantiate()
  get_tree().root.add_child(restaurant)
  get_tree().current_scene=restaurant
  await get_tree().create_timer(0.6).timeout
  var hud=get_tree().get_first_node_in_group("restaurant_hud")
  var player=restaurant.get_node("Player")
  _check(hud._recipe_entry.is_visible_in_tree(),"菜谱按钮可见")
  await _click(hud._recipe_entry)
  _check(hud._recipe_book.visible,"实际左键点击打开菜谱")
  if hud._recipe_book.visible:
   _check(player.input_locked,"打开菜谱锁住世界操作")
   await _shot_gate("recipe_open_%d" % resolution.x)
   await _click(hud._recipe_book.close_button)
   _check(not hud._recipe_book.visible and not player.input_locked and player.is_physics_processing(),"关闭菜谱恢复操作")
   await _click(hud._recipe_entry)
   await _send_key(KEY_ESCAPE)
   _check(not hud._recipe_book.visible and not player.input_locked,"再次打开后Esc恢复操作")
  _check(not hud.exploration_guide.allows_world_interaction("冰柜") and hud.exploration_guide.allows_world_interaction("迷宫入口"),"保留首次探索世界入口限制")
  var origin: Vector2=player.position
  var key:=InputEventKey.new()
  key.keycode=KEY_D
  key.pressed=true
  Input.parse_input_event(key)
  await get_tree().create_timer(0.15).timeout
  key=InputEventKey.new()
  key.keycode=KEY_D
  Input.parse_input_event(key)
  _check(player.position.distance_to(origin)>0.1,"关闭后实际移动生效")
  hud._open_confirmation("迷宫")
  _check(hud.confirmation.visible,"仍可打开迷宫组队入口")
  restaurant.queue_free()
  await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"未写入正式存档")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)

