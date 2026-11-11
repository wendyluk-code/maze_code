extends "res://tools/tests/fenshui_frog_counter_flow.gd"
var baseline: Dictionary

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"正式场景可操作")
 baseline=sm.data.duplicate(true)
 for case in ["success","failure","cancel"]:
  await capture(case)

func control_click(control: Control) -> void:
 await get_tree().process_frame
 var point:=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=point
 viewport.push_input(motion)
 await get_tree().process_frame
 await mouse(point)

func capture(case: String) -> void:
 maze.capture_flow.set_process(false)
 sm.data=baseline.duplicate(true)
 var run:=state()
 # 仅把本次待击败目标设为非零低血前置，不直接写死亡或反击阶段。
 run.combat.actors[Boss.ID].hp=1.0
 run.monsters[Boss.ID].capture_roll=0.0
 run.monsters[Boss.ID].copy_roll=0.99
 sm.data[Run.KEY]=run
 sm.save()
 maze.player.position=Vector2(880,490)
 maze.camera.snap_to_target()
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return actor().frog_phase=="airborne"),"低血前置仍由正常追击进入可攻击腾空："+case)
 await key(KEY_SPACE)
 await click()
 _check(await until_true(func(): return maze.capture_flow.dialog.visible),"真实左键击败巨蛙进入捕获入口："+case)
 if not maze.capture_flow.dialog.visible: return
 _check(actor().hp==0,"实际命中将非零生命归零："+case)
 _check(await until_true(func(): return not maze.capture_flow.dialog.flipping),"原捕获窗翻转完成："+case)
 await picture("frog_capture_"+case)
 await control_click(maze.capture_flow.dialog._confirm_button)
 var attempt: Control=maze.capture_flow.attempt
 _check(await until_true(func(): return attempt.visible),"原捕获操作窗可用："+case)
 if not attempt.visible: return
 if case=="cancel":
  var satiety: float=state().satiety
  await control_click(attempt.no_button)
  _check(await until_true(func(): return not maze.capture_flow.busy),"取消捕获恢复探索")
  _check(state().satiety==satiety,"取消不扣捕获费用")
 else:
  await control_click(attempt.yes_button)
  _check(await until_true(func(): return attempt.mode=="suppress",6.0),"抛绳束缚后进入镇压："+case)
  var end:=Time.get_ticks_msec()+12000
  while attempt.visible and Time.get_ticks_msec()<end:
   if case=="success": await key(KEY_J)
   else: await get_tree().process_frame
  if case=="success":
   _check(maze.capture_flow.reward.visible and state().monsters[Boss.ID].status=="captured","真实J镇压成功并保存巨蛙捕获")
   _check(not state().bag.is_empty(),"捕获食材进入原暂存袋")
   await picture("frog_reward")
   if maze.capture_flow.reward.visible: await control_click(maze.capture_flow.reward._confirm_button)
  else:
   _check(maze.capture_flow.dialog.visible and state().monsters[Boss.ID].status=="failed","不镇压产生原失败结果")
   await until_true(func(): return not maze.capture_flow.dialog.flipping)
   if maze.capture_flow.dialog.visible: await control_click(maze.capture_flow.dialog._confirm_button)
  _check(await until_true(func(): return not maze.capture_flow.busy),"结果关闭后恢复探索："+case)
  var bag: Dictionary=state().bag.duplicate(true)
  _check(not Run.resolve(sm,Boss.ID,true).success and state().bag==bag,"重复捕获结算拒绝且不重奖："+case)
 _check(not maze.player.input_locked and Run.valid(state()),"巨蛙捕获流程后输入解锁且状态合法："+case)
 var before: Vector2=maze.player.position
 var event:=InputEventKey.new()
 event.keycode=KEY_LEFT
 event.physical_keycode=KEY_LEFT
 event.pressed=true
 Input.parse_input_event(event)
 await get_tree().create_timer(0.2).timeout
 event=InputEventKey.new()
 event.keycode=KEY_LEFT
 event.physical_keycode=KEY_LEFT
 event.pressed=false
 Input.parse_input_event(event)
 _check(maze.player.position.distance_to(before)>5.0,"内部方向输入仍能移动："+case)
