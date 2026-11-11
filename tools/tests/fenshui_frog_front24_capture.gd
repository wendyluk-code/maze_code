extends "res://tools/tests/fenshui_frog_capture.gd"

func battle() -> void:
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(frog.enable_frog_front24(),"捕获从同一个双前向真实巨蛙节点开始")
 await super.battle()
 if failures==0: await belly_capture()
 if failures==0: await retry_capture()

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
 _check(await until_true(func(): return actor().frog_phase=="airborne"),"候选保存重试前自然起跳")
 await key(KEY_SPACE)
 await click()
 _check(await until_true(func(): return maze.capture_flow.dialog.visible),"重试前通过真实攻击击败")
 await until_true(func(): return not maze.capture_flow.dialog.flipping)
 await control_click(maze.capture_flow.dialog._confirm_button)
 var attempt: Control=maze.capture_flow.attempt
 _check(await until_true(func(): return attempt.visible and attempt.mode=="ready"),"捕获确认窗实际可用")
 await control_click(attempt.yes_button)
 var paid: float=state().satiety
 var path: String=sm._active_save_path
 var deadline:=Time.get_ticks_msec()+15000
 while attempt.mode not in ["complete","closed"] and Time.get_ticks_msec()<deadline:
  await key(KEY_J)
 _check(attempt.mode=="complete","候选真实镇压到结算阶段")
 sm._active_save_path=""
 _check(await until_true(func(): return attempt.mode=="retry",2.0),"保存失败仍进入原重试界面")
 _check(state().satiety==paid and state().bag.is_empty(),"保存失败不重复扣费不发奖")
 _check(attempt.frames[0].atlas.resource_path.ends_with("front24.png"),"保存重试保持新素材")
 sm._active_save_path=path
 await control_click(attempt.yes_button)
 _check(await until_true(func(): return maze.capture_flow.reward.visible),"恢复可写后实际重试成功")
 _check(state().satiety==paid and state().monsters[Boss.ID].status=="captured","重试保留已付费成功结论")
 if maze.capture_flow.reward.visible: await control_click(maze.capture_flow.reward._confirm_button)
 _check(await until_true(func(): return not maze.capture_flow.busy) and not maze.player.input_locked,"候选保存恢复后输入解锁")

func picture(label: String) -> void:
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 if frog.action=="defeated":
  _check(frog.frog_front24.current_pose==21,"站立击败0.72秒后停在新伏地末态")
 if maze.capture_flow.dialog.visible and maze.capture_flow.dialog.victory:
  _check(maze.capture_flow.dialog.illustration_frames[0].atlas.resource_path.ends_with("front24.png"),"胜利图不切回旧图")
 await super.picture(label)

func control_click(control: Control) -> void:
 await super.control_click(control)
 var attempt: Control=maze.capture_flow.attempt
 if attempt.visible and not attempt.frames.is_empty():
  _check(attempt.frames[0].atlas.resource_path.ends_with("front24.png"),"捕获待机与绳网使用新双前向身体")

func belly_capture() -> void:
 maze.capture_flow.set_process(false)
 sm.data=baseline.duplicate(true)
 maze.player.position=Vector2(880,490)
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return actor().frog_phase=="airborne"),"露腹击败前自然起跳")
 await key(KEY_SPACE)
 _check(await until_true(func(): return actor().frog_phase=="airborne" and float(actor().frog_left)<=0.5 and float(actor().frog_left)>=0.3,2.0),"等待巨蛙腾空最高点附近的真实反击窗口")
 if failures: return
 await click()
 _check(await until_true(func(): return actor().frog_phase=="exposed"),"真实命中反击进入露腹")
 if failures: return
 _check(await until_true(func(): return state().combat.cooldown<=0.00001),"露腹击败等待真实攻击冷却")
 var run:=state()
 run.combat.actors[Boss.ID].hp=1.0
 run.monsters[Boss.ID].capture_roll=0.0
 run.monsters[Boss.ID].copy_roll=0.99
 sm.data[Run.KEY]=run
 sm.save()
 await click()
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(await until_true(func(): return frog.action=="defeated"),"第二次真实攻击击败露腹巨蛙")
 _check(frog.frog_defeated_belly and frog.frog_front24.current_pose in [22,23],"露腹失力不切回站立击败")
 _check(await until_true(func(): return maze.capture_flow.dialog.visible),"露腹击败进入原捕获入口")
 _check(frog.frog_front24.current_pose==23,"露腹击败停新侧卧末态")
 _check(maze.capture_flow.dialog.illustration_frames[0].region.position==Vector2(7*181,5*181)+Vector2(frog.frog_front24.entries[47].bounds.position) if frog.frog_front24.current_direction==1 else maze.capture_flow.dialog.illustration_frames[0].region.position==Vector2(7*181,2*181)+Vector2(frog.frog_front24.entries[23].bounds.position),"胜利图保留对应方向露腹击败末态")
 await until_true(func(): return not maze.capture_flow.dialog.flipping)
 await super.picture("belly_defeated")
 await control_click(maze.capture_flow.dialog._confirm_button)
 var attempt: Control=maze.capture_flow.attempt
 _check(await until_true(func(): return attempt.visible and attempt.mode=="ready"),"露腹击败后原捕获流程可用")
 await super.picture("belly_capture")
 await control_click(attempt.no_button)
 _check(await until_true(func(): return not maze.capture_flow.busy),"露腹捕获取消后输入恢复")
