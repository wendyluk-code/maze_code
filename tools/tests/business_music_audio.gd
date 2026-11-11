extends "res://tools/tests/feedback_audio.gd"
const FadeAudio = preload("res://scripts/ui/components/scene_transition.gd")
var switched := false
var switch_error := OK
func _switch_audio(destination: PackedScene) -> void:
 switched = false
 switch_error = await FadeAudio.change_scene(get_tree(),destination)
 switched = true

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 evidence=_arg("--output-dir=")
 _check(_verify_isolation(),"隔离目录核验")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 _check(not sm._write_atomic("C:/audio-test-outside-profile.json",{}),"写入隔离目录之外被提前拦截")
 sm.audio_guard_blocked=0
 GameAudio.cue_played.connect(_heard)
 _completed()
 tm.active=false
 sm.data["first_exploration_gate_v1"]="done"
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 sm.cancel_maze_entry()
 # 使用测试控制器常驻root，真实转场可释放current_scene。
 get_tree().current_scene=null
 for path in ["restaurant_map_2d","maze_entry","maze_fenshui","restaurant_map_2d"]:
  var old=get_tree().current_scene
  var restaurant: bool=path=="restaurant_map_2d"
  var target: AudioStreamPlayer=GameAudio.restaurant_music if restaurant else GameAudio.maze_music
  var other: AudioStreamPlayer=GameAudio.maze_music if restaurant else GameAudio.restaurant_music
  var previous: float=target.get_playback_position()
  var continuing: bool=target.playing
  _switch_audio(load("res://scenes/"+path+".tscn"))
  _check(target.playing and not other.playing,"确认转场立即切音乐："+path)
  _check(get_tree().current_scene==old,"音乐切换时旧画面尚未释放")
  while not switched: await get_tree().process_frame
  _check(switch_error==OK and target.playing,"目标场景就绪保持播放")
  if continuing: _check(target.get_playback_position()>previous,"迷宫跨地图不重播")
  if restaurant: _check(not get_tree().current_scene.get_node("RestaurantBGM").playing,"餐厅本地节点不叠播")
  await _shot("music_"+path)
 var pos: float=GameAudio.restaurant_music.get_playback_position()
 _check(await FadeAudio.change_scene(get_tree(),null)==ERR_INVALID_PARAMETER,"无效转场拒绝")
 _check(GameAudio.restaurant_music.playing and GameAudio.restaurant_music.get_playback_position()>=pos,"无效转场不改音乐")
 get_tree().current_scene.queue_free()
 await get_tree().process_frame
 _seed_cycle()
 Cycle.settle(sm,"time")
 cues.clear()
 scene=RESTAURANT.instantiate()
 get_tree().root.add_child(scene)
 get_tree().current_scene=scene
 await get_tree().create_timer(0.3).timeout
 var hud=get_tree().get_first_node_in_group("restaurant_hud")
 _check(is_instance_valid(hud.day_settlement) and cues.count(&"business_complete")==1,"营业完成实际结算弹窗响一次")
 hud.day_settlement.open(sm.data[Day.KEY].settlement)
 _check(cues.count(&"business_complete")==1,"重复刷新结算不重播")
 await _shot("business_complete_audio")
 scene.queue_free()
 await get_tree().process_frame
 # 有保存路径硬拦截后，补验上一批音效的未完成闭环。
 for kind in ["food","water","wrong","bad_water","unwanted","save_failed"]: await _service_audio(kind)
 await _arrival_feedback()
 await _combat_feedback()
 await _capture_audio(false)
 _check(sm.audio_guard_blocked==0,"全部实际写盘均在隔离目录")
 GameAudio.set_world_music(&"")
 for player in GameAudio._players.values(): player.stop()
 await get_tree().create_timer(0.15).timeout
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
