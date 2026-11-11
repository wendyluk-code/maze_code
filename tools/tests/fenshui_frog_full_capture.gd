extends "res://tools/tests/fenshui_frog_capture.gd"
const Counter=preload("res://scripts/maze/wind_frog_counter.gd")

func battle() -> void:
 await super.battle()
 await retry_capture()

func retry_capture() -> void:
 maze.capture_flow.set_process(false)
 sm.data=baseline.duplicate(true)
 var run:=state()
 run.combat.actors[Boss.ID].hp=1.0
 run.monsters[Boss.ID].capture_roll=0.0
 run.monsters[Boss.ID].copy_roll=0.99
 sm.data[Run.KEY]=run
 sm.save()
 maze.player.position=Vector2(880,490)
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return actor().frog_phase=="airborne"),"保存重试前仍自然起跳")
 await key(KEY_SPACE)
 await click()
 _check(await until_true(func(): return maze.capture_flow.dialog.visible),"重试前通过真实攻击击败")
 await until_true(func(): return not maze.capture_flow.dialog.flipping)
 await control_click(maze.capture_flow.dialog._confirm_button)
 var attempt: Control=maze.capture_flow.attempt
 _check(await until_true(func(): return attempt.visible and attempt.mode=="ready"),"等待原翻转结束后捕获确认窗实际可用")
 await control_click(attempt.yes_button)
 var paid: float=state().satiety
 var path: String=sm._active_save_path
 var deadline:=Time.get_ticks_msec()+15000
 while attempt.mode not in ["complete","closed"] and Time.get_ticks_msec()<deadline:
  await key(KEY_J)
 _check(attempt.mode=="complete","真实镇压进入结算前末阶段")
 sm._active_save_path=""
 _check(await until_true(func(): return attempt.mode=="retry",2.0),"保存失败进入原重试界面")
 _check(state().satiety==paid and state().bag.is_empty(),"保存失败不重复扣费不发奖")
 if attempt.mode=="retry":
  _check(attempt.frames[0].region.position.y>=Counter.facing(actor())*192,"重试界面保持同向身体")
 sm._active_save_path=path
 await control_click(attempt.yes_button)
 _check(await until_true(func(): return maze.capture_flow.reward.visible),"恢复可写后原按钮成功重试")
 _check(state().satiety==paid and state().monsters[Boss.ID].status=="captured","重试保留已付费及成功结论")
 if maze.capture_flow.reward.visible: await control_click(maze.capture_flow.reward._confirm_button)
 _check(await until_true(func(): return not maze.capture_flow.busy) and not maze.player.input_locked,"重试完成输入恢复")

func picture(label: String) -> void:
 await super.picture(label)
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 var direction: int=Counter.facing(actor())
 _check(int(frog.body.region_rect.position.y/192)==direction,"世界击败保留最后战斗方向")
 var dialog: Control=maze.capture_flow.dialog
 if dialog.visible and dialog.victory:
  _check(int(dialog.illustration_frames[0].region.position.y/192)==direction,"胜利图继承世界方向而非固定右前")

func control_click(control: Control) -> void:
 await super.control_click(control)
 var attempt: Control=maze.capture_flow.attempt
 if attempt.visible and not attempt.frames.is_empty():
  var direction: int=Counter.facing(actor())
  _check(attempt.frames[0].region.position.y>=direction*192 and attempt.frames[0].region.position.y<(direction+1)*192,"捕获身体循环保持实际方向")
