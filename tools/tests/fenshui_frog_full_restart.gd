extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const Counter=preload("res://scripts/maze/wind_frog_counter.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"巨蛙同向捕获跨进程隔离存档")
 if _arg("--phase=")=="seed": prepare_saved()
 else: await restore_saved()
 _finish()

func prepare_saved() -> void:
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success and Run.change_region(sm,"fenshui",Vector2(880,490)).success,"建立真实巨蛙探索")
 sm.data[Run.KEY].combat.actors[Boss.ID].hp=1.0
 sm.data[Run.KEY].monsters[Boss.ID].capture_roll=0.0
 for i in 120:
  Run.combat_tick(sm,Vector2(880,490),0.02)
  if actor().frog_phase=="airborne": break
 _check(Run.combat_attack(sm,Vector2(880,490),Vector2(880,490).direction_to(Run.Combat.vec(actor().position))).success,"原攻击入口出手")
 for i in 50:
  Run.combat_tick(sm,Vector2(880,490),0.02)
  if actor().hp<=0: break
 _check(actor().hp==0 and Counter.facing(actor())==1,"实际击败保留左前朝向")
 _check(Run.defeat(sm,Boss.ID,Vector2(880,490)).success,"原击败事务进入待捕获")
 sm._active_save_path="user://full-ready.json"
 _check(sm.save(),"保存未付费捕获恢复点")
 sm._active_save_path="user://full-working.json"
 _check(Run.start_capture(sm,Boss.ID).success,"真实捕获付费")
 sm._active_save_path="user://full-paid.json"
 _check(sm.save(),"保存已付费捕获恢复点")
 sm._active_save_path="user://full-working.json"
 _check(Run.finish_capture(sm,Boss.ID,true).success,"原事务保存已完成操作结论")
 sm._active_save_path="user://full-finished.json"
 _check(sm.save(),"保存待结算恢复点")

func restore_saved() -> void:
 for phase in ["ready","paid","finished"]:
  sm._active_save_path="user://full-"+phase+".json"
  sm.load_data()
  var before:=state()
  var paid: float=before.satiety
  _check(Counter.facing(actor())==1 and Run.valid(before),"独立进程恢复同向合法演员："+phase)
  viewport=SubViewport.new()
  viewport.size=Vector2i(1280,720)
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  viewport.handle_input_locally=false
  get_tree().root.add_child(viewport)
  maze=load("res://scenes/maze_fenshui.tscn").instantiate()
  viewport.add_child(maze)
  maze.capture_flow.window_focused=true
  _check(await until_true(func(): return maze._entry_ready and (maze.capture_flow.dialog.visible or maze.capture_flow.attempt.visible or maze.capture_flow.reward.visible),8.0),"真实地图恢复捕获界面："+phase)
  if phase=="ready":
   var frames: Array=maze.capture_flow.dialog.illustration_frames
   _check(not frames.is_empty() and frames[0].region.position.y==192,"未付费恢复显示同向胜利终帧")
  elif phase=="paid":
   var attempt: Control=maze.capture_flow.attempt
   _check(not attempt.frames.is_empty() and attempt.frames[0].region.position.y>=192 and attempt.frames[0].region.position.y<384,"已付费恢复继续同向身体循环")
  else:
   _check(maze.capture_flow.reward.visible and state().monsters[Boss.ID].status=="captured","已完成结论恢复只结算一次奖励")
  _check(state().satiety==paid and Counter.facing(actor())==1,"恢复不二次扣费且方向不重置："+phase)
  await picture("restore_"+phase)
  viewport.queue_free()
  await get_tree().process_frame
