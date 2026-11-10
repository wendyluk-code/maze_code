extends "res://tools/tests/fenshui_area_flow.gd"
## 正常六怪场景，从真实攻击击败开始检查死亡动作等待，不靠帧率碰巧耗过体力。
const SprintAim=preload("res://scripts/maze/auto_aim.gd")

func _area_scene(size: Vector2i) -> void:
 # 常见60帧下也要保持战斗时间，不借高绘制帧率掩盖提前退出。
 Engine.max_fps=60
 for pair in [[KEY_SPACE,0],[KEY_1,1],[KEY_2,2]]:
  await _sprint_after_defeat(size,pair[0],pair[1])

func _sprint_after_defeat(size: Vector2i, key: Key, selected: int) -> void:
 section="击败后冲刺"+str(size)+"招式"+str(selected)
 await _reset(Vector2(880,440))
 var run: Dictionary=Run.snapshot(sm)
 run.combat.selected=selected
 run.combat.cooldown=0.0
 run.combat.actors[FISH].hp=1
 sm.data[Run.KEY]=run
 recording=true
 last_frame=0
 await _send_key(key)
 _check(SprintAim.target(Run.snapshot(sm),maze.player.position)==FISH,"攻击入口确实选中本次低血目标，而非等环境电补刀")
 var throws: float=run.combat.throws
 var hits: float=run.combat.hits
 await _attack_click()
 _check(Run.snapshot(sm).combat.throws>throws,"真实左键发射当前招式："+str(selected))
 var defeated: bool=await _wait_until(func(): return Run.snapshot(sm).combat.actors[FISH].hp<=0,180)
 _check(defeated and Run.snapshot(sm).combat.hits>hits,"真实玩家攻击击败鱼，非直接设置死亡状态")
 if not defeated: return
 var node: Node=maze.capture_flow.monsters[FISH]
 _check(node.action=="defeated" and node.action_time<0.3 and not maze.capture_flow.busy,"从死亡动作初段开始，捕获窗尚未打开",{"action":node.action,"time":node.action_time})
 var start: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 var point: Vector2=maze.player.position
 _check(maze.player.terrain.move_on_road(point,Vector2(0,20)).distance_to(point)>10,"冲刺检查方向确实可走，不以碰岸停止代替故障")
 var shift:=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=true
 Input.parse_input_event(shift)
 Input.action_press("ui_down")
 await get_tree().create_timer(0.2).timeout
 var after: Dictionary=Run.snapshot(sm).combat
 _check(maze.player.sprint_held and maze.player.sprinting and maze.player.position.distance_to(point)>5,"死亡动作期间实际收到Shift并保持冲刺移动",{"held":maze.player.sprint_held,"sprinting":maze.player.sprinting,"distance":maze.player.position.distance_to(point),"before":str(point),"after":str(maze.player.position)})
 _check(not maze.capture_flow.combat_paused() and node.action_time<0.72,"检查仍处于可操作死亡动作等待，未跨捕获暂停")
 _check(after.elapsed-start.elapsed>=0.15,"死亡动作等待期间正常战斗计时继续",{"before":start.elapsed,"after":after.elapsed,"selected":selected})
 _check(after.sprint<start.sprint,"死亡动作等待期间冲刺实际消耗体力",{"before":start.sprint,"after":after.sprint})
 _check(start.cooldown>0 and after.cooldown<start.cooldown,"其他已发招式的冷却不会随死亡动作冻结",{"before":start.cooldown,"after":after.cooldown})
 _check(start.actors[EEL].eel_phase=="charging" and after.actors[EEL].eel_phase=="charging" and after.actors[EEL].eel_left<start.actors[EEL].eel_left,"存活雷鳗的蓄电仍继续，不随另一只鱼死亡冻结",{"before":start.actors[EEL].eel_left,"after":after.actors[EEL].eel_left})
 Input.action_release("ui_down")
 shift=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=false
 Input.parse_input_event(shift)
 await get_tree().process_frame
 _check(not maze.player.sprint_held and not maze.player.sprinting,"松开Shift立即结束冲刺")
 await _image("sprint_during_defeat_%d_%dx%d" % [selected,size.x,size.y])
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible,180),"死亡动作完成后仍进入原捕获窗")
 _check(maze.capture_flow.current==FISH,"捕获对象仍是实际击败的鱼")
 var paused: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 await _hold(KEY_LEFT,0.15)
 _check(Run.snapshot(sm).combat==paused and not maze.player.sprint_held,"捕获窗期间战斗与输入保持原暂停规则")
 await _close_pending_captures()
 _check(Run.snapshot(sm).monsters[FISH].status=="skipped" and not maze.capture_flow.busy and not maze.player.input_locked,"取消捕获后只结算一次并恢复输入")
 await _click(maze.map_ui.mini_button)
 _check(maze.map_ui.expanded,"击败恢复后实际打开地图")
 paused=Run.snapshot(sm).combat.duplicate(true)
 await get_tree().create_timer(0.15).timeout
 _check(Run.snapshot(sm).combat==paused,"地图仍冻结战斗计时和体力")
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"关闭地图恢复正常探索")
 start=Run.snapshot(sm).combat.duplicate(true)
 shift=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=true
 Input.parse_input_event(shift)
 await _hold(KEY_LEFT,0.15)
 _check(Run.snapshot(sm).combat.sprint<start.sprint,"捕获与地图恢复后重新按Shift仍消耗体力")
 shift=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=false
 Input.parse_input_event(shift)
 await get_tree().process_frame
 _check(Run.valid(Run.snapshot(sm)) and not maze.player.sprint_held,"阶段恢复后状态合法且无残留按键")
 recording=false
