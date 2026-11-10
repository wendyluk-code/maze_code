extends "res://tools/tests/silverfish_shore_flow.gd"
## 真实攻击击败预警中的鱼，必须播完倒地并进入捕获，而不是冻结战斗。
func _scene_check(_effects: Node) -> void:
 output = _arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 _check(get_window().unfocusable and not get_window().has_focus(), "测试窗口从启动起不可聚焦、不接管桌面输入")
 baseline = sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial = false
 baseline[Run.KEY].combat.cooldown = 0.0
 baseline[Run.KEY].combat.selected = 0
 for id in baseline[Run.KEY].monsters:
  baseline[Run.KEY].monsters[id].status = "alive" if id==Rules.IDS[0] else "skipped"
 var fish: Dictionary = baseline[Run.KEY].combat.actors[Rules.IDS[0]]
 fish.position = [860.0,485.0]
 fish.fish_origin = fish.position.duplicate()
 fish.fish_aim = [-1.0,0.0]
 fish.fish_hit = false
 fish.hp = 1
 Fish.phase(fish, "warning", 0.65)
 await _reset(Vector2(820,500))
 section = "预警鱼被真实普攻击败"
 recording = true
 last_frame = 0
 _check(Run.valid(Run.snapshot(sm)) and actor().fish_phase=="warning", "低血量预警起点是合法的正式战斗状态")
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp==0, 120), "真实鼠标普攻击败预警中的鱼")
 var defeated: Node = maze.capture_flow.monsters[Rules.IDS[0]]
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible, 120), "倒地动画结束后必须实际打开捕获窗", {"phase":actor().get("fish_phase",""), "action":defeated.action, "action_time":defeated.action_time, "paused":maze.capture_flow.combat_paused(), "save_retry":maze.capture_flow.save_retry_delay})
 if maze.capture_flow.dialog.visible:
  _check(await _wait_until(func(): return not maze.capture_flow.dialog.flipping,120), "捕获窗结束翻转")
  await _click(maze.capture_flow.dialog._cancel_button)
  _check(await _wait_until(func(): return not maze.capture_flow.busy,120), "放弃捕获后释放输入")
  var elapsed: float = Run.snapshot(sm).combat.elapsed
  var point: Vector2 = maze.player.position
  await _hold(KEY_LEFT,0.2)
  _check(maze.player.position.distance_to(point)>5 and Run.snapshot(sm).combat.elapsed>elapsed, "击败预警鱼后实际移动和战斗时间恢复")
 recording = false
 _finish_fish()
