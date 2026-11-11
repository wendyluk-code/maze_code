extends "res://tools/tests/fenshui_frog_full_restart.gd"

func restore_saved() -> void:
 for phase in ["ready","paid","finished"]:
  sm._active_save_path="user://full-"+phase+".json"
  sm.load_data()
  var before:=state()
  var paid: float=before.satiety
  _check(Counter.facing(actor())==1 and Run.valid(before),"新进程恢复候选对应原战斗状态："+phase)
  viewport=SubViewport.new()
  viewport.size=Vector2i(1280,720)
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  viewport.handle_input_locally=false
  get_tree().root.add_child(viewport)
  maze=load("res://scenes/maze_fenshui.tscn").instantiate()
  viewport.add_child(maze)
  _check(maze.capture_flow.monsters[Boss.ID].enable_frog_front24(),"恢复首帧前启用相同候选，不改变恢复数据")
  maze.capture_flow.window_focused=true
  _check(await until_true(func(): return maze._entry_ready and (maze.capture_flow.dialog.visible or maze.capture_flow.attempt.visible or maze.capture_flow.reward.visible),8.0),"实际地图恢复原捕获界面："+phase)
  if phase=="ready":
   var frames: Array=maze.capture_flow.dialog.illustration_frames
   _check(not frames.is_empty() and frames[0].atlas.resource_path.ends_with("front24.png") and frames[0].region.position.y>900,"未付费恢复使用新左前击败末态")
  elif phase=="paid":
   var frames: Array=maze.capture_flow.attempt.frames
   _check(not frames.is_empty() and frames[0].atlas.resource_path.ends_with("front24.png") and frames[0].region.position.y>=543,"已付费恢复继续新左前待机")
  else:
   _check(maze.capture_flow.reward.visible and state().monsters[Boss.ID].status=="captured","已完成结论只结算一次")
  _check(state().satiety==paid and Counter.facing(actor())==1,"恢复不二次扣费或重置方向："+phase)
  await picture("restore_"+phase)
  viewport.queue_free()
  await get_tree().process_frame
