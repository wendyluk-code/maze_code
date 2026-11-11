extends "res://tools/tests/elder_01_flow.gd"
var reward_sounds := 0
func _run() -> void:
 sm=get_node("/root/SaveManager")
 evidence=_arg("--output-dir=")
 _check(_isolation(),"隔离正式存档")
 if failures: _finish(); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 GameAudio.cue_played.connect(func(cue: StringName):
  if cue==&"capture_success" and is_instance_valid(maze) and maze.elder.ingredient_reward.visible:
   reward_sounds+=1
   _check(GameAudio._players[cue].playing,"食材奖励弹窗显示时启动捕获成功播放器")
   if reward_sounds==1: maze.elder.ingredient_reward.present())
 _seed(12)
 sm.data["first_exploration_gate_v1"]="done"
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 _check(sm.accept_elder_firewood(NEAR).success,"实际接取木材任务")
 _check(sm.deliver_elder_firewood(NEAR).success,"实际交付保存奖励")
 maze=MazeScene.instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 await get_tree().create_timer(0.5).timeout
 var elder=maze.elder
 # 等价于已完成聚焦的奖励检查点，提供关闭弹窗所需的镜头/输入恢复上下文。
 elder._player=maze.player
 elder._camera=maze.camera
 elder._camera_before=maze.camera.global_position
 elder._camera_zoom_before=maze.camera.zoom
 elder._camera_process_before=maze.camera.is_processing()
 elder._locked_before=maze.player.input_locked
 elder._physics_before=maze.player.is_physics_processing()
 elder._shield.show()
 elder._reward_step=-1
 for i in Elder.REWARD_STEPS.size():
  elder._next_reward_step()
  if elder.phase=="ingredient_reward": break
 _check(elder.ingredient_reward.visible and elder.phase=="ingredient_reward","真实场景奖励阶段显示食材弹窗")
 await get_tree().create_timer(0.5).timeout
 await _shot("elder_ingredient_audio")
 await _click(elder.ingredient_reward._confirm_button)
 await get_tree().create_timer(0.6).timeout
 _check(not elder.ingredient_reward.visible,"收下关闭食材弹窗")
 await _close_maze()
 _check(reward_sounds==1,"实际奖励显示一次音效，重复展示及收下不重播")
 _check(sm.audio_guard_blocked==0,"写盘仅限隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 _finish()
