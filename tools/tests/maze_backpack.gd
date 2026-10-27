extends "res://tools/tests/maze_capture.gd"
func _run() -> void:
 sm = get_node("/root/SaveManager")
 tm = get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  DisplayServer.window_set_size(resolution)
  suffix = "_%dx%d" % [resolution.x,resolution.y]
  _completed()
  sm.cancel_maze_entry()
  maze = load("res://scenes/maze_entry.tscn").instantiate()
  get_tree().root.add_child(maze)
  get_tree().current_scene = maze
  await get_tree().create_timer(0.3).timeout
  _check(maze.backpack_entry.visible and maze.last_message.contains("背包已解锁"),"进入即解锁并提示")
  await _capture_image("unlock")
  await _click(maze.backpack_entry)
  var bag = maze.backpack_warehouse
  _check(bag.visible and bag._heading.text=="背包" and bag._message.text=="本趟尚未捕获食材","空背包标题与提示")
  _check(bag._slot_by_id.values().all(func(slot):return slot._quantity==0),"空袋不读取仓库存量")
  await _capture_image("empty")
  await _click(bag._cancel_button)
  var row := Run.monster_for(Run.snapshot(sm),"slime_1")
  _check(Run.defeat(sm,row.id,row.position).success,"击败当前版本史莱姆")
  var result := Run.resolve(sm,row.id,true)
  _check(result.success and result.caught,"首次捕获双产物")
  await _click(maze.backpack_entry)
  _check(bag._slot_by_id.slime_gel._quantity==int(result.items.slime_gel),"背包显示新捕获数量")
  _check(sm.inventory_snapshot().get("slime_gel",0)==0,"临时袋不写永久库存")
  await _capture_image("filled")
  await _click(bag._cancel_button)
  _check(not maze.player.input_locked,"关闭恢复输入")
  _check(Run.finish(sm,true,Roads.EXIT).success and sm.inventory_snapshot().get("slime_gel",0)==result.items.slime_gel,"出口带回入库")
  _check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).bag.is_empty(),"新趟袋清空")
  sm.data[Run.KEY].bag = {"slime_gel":2}
  var before: int = sm.inventory_snapshot().get("slime_gel",0)
  _check(Run.finish(sm,false,Roads.SPAWN).success and Run.snapshot(sm).bag.is_empty() and sm.inventory_snapshot().get("slime_gel",0)==before,"放弃清空临时物不改变永久库存")
  maze.player.position = Vector2(839,503)
  maze.elder.interact()
  await get_tree().create_timer(0.5).timeout
  _check(maze.elder.phase!="idle","真实进入爷爷对话")
  maze.elder._reward_step = maze.elder.Config.REWARD_STEPS.size()-1
  maze.elder.phase = "reward"
  maze.elder._next_reward_step()
  await get_tree().create_timer(0.6).timeout
  _check(maze.elder.phase=="idle" and not maze.elder.backpack_reward.visible,"爷爷奖励结束直接恢复不触发背包")
  _check(not str(maze.elder.Config.REWARD_STEPS).contains("背包") and not str(maze.elder.Config.REWARD_STEPS).contains("打开看看"),"爷爷背包上下文已删除")
  maze.queue_free()
  await get_tree().process_frame
 var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
