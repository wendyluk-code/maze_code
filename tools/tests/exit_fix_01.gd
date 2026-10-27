extends "res://tools/tests/maze_capture.gd"
const STONE := Vector2(116,724)
func _run() -> void:
 sm = get_node("/root/SaveManager")
 tm = get_node("/root/TutorialManager")
 _check(_verify_isolation(), "隔离存档")
 _state_cases()
 if DisplayServer.get_name() != "headless":
  for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
   DisplayServer.window_set_size(resolution)
   suffix = "_%dx%d" % [resolution.x,resolution.y]
   await _flow_cases()
 var file := FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)

func _fill_bag() -> Dictionary:
 var bag := {}
 for row in Run.monsters_for(Run.snapshot(sm)):
  for item in row.drops: bag[item] = 2
 sm.data[Run.KEY].bag = bag.duplicate()
 return bag

func _state_cases() -> void:
 _fresh()
 var bag := _fill_bag()
 var original: Dictionary = sm.data.duplicate(true)
 for point in [Roads.SPAWN,STONE+Vector2(0,44),Vector2(500,500)]:
  _check(Run.finish(sm,true,point).get("reason") == "not_exit" and sm.data == original,"远离出口拒绝结算："+str(point))
 var path: String = sm._active_save_path
 sm._active_save_path = ""
 _check(Run.finish(sm,true,STONE).get("reason") == "save_failed" and sm.data == original,"石阵保存失败完整回滚")
 sm._active_save_path = path
 _check(Run.finish(sm,true,Roads.EXIT).success,"旧出口仍可入库")
 var banked: Dictionary = sm.inventory_snapshot()
 _check(not Run.finish(sm,true,STONE).success and _same_saved(sm.inventory_snapshot(),banked),"重复结算不重复入库")
 _fresh()
 _fill_bag()
 var inventory: Dictionary = sm.inventory_snapshot()
 _check(Run.finish(sm,false,Roads.ENTRANCE).success and sm.inventory_snapshot()==inventory and Run.snapshot(sm).bag.is_empty(),"入口放弃清袋不入库")
 _fresh()
 _fill_bag()
 sm.data[Run.KEY].erase("catalog_version")
 sm.data[Run.KEY].erase("food_version")
 sm.data[Run.KEY].erase("food_cursor")
 sm.data[Run.KEY].monsters.clear()
 for row in Catalog.all(1):
  sm.data[Run.KEY].monsters[row.id] = {"status":"alive","capture_roll":0.4,"drop_roll":0.3,"copy_roll":0.5,"extra_roll":0.6,"guaranteed":false}
 var legacy := Run.snapshot(sm)
 _check(sm.save(),"保存进行中旧版本探索夹具")
 sm.load_data()
 _check(_same_saved(Run.snapshot(sm),legacy),"旧进行中存档读回不丢怪物随机值与物资")
 _check(Run.begin(sm,STONE).success and _same_saved(Run.snapshot(sm).bag,legacy.bag),"旧进行中探索可继续")
 _check(Run.finish(sm,true,STONE).success,"旧进行中探索可在石阵结算")

func _flow_cases() -> void:
 _completed()
 _check(sm.request_maze_entry().success,"预留一次真实入场")
 var stamina_before: int = sm.stamina()
 maze = load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene = maze
 await get_tree().create_timer(0.5).timeout
 _check(maze._entry_ready and sm.stamina()==stamina_before-20,"真实入场仅扣20体力")
 var bag := _fill_bag()
 var inventory: Dictionary = sm.inventory_snapshot()
 var warehouse_before: Dictionary = sm.warehouse_snapshot()
 maze.player.position = STONE + Vector2(44,0)
 await get_tree().process_frame
 _check(not maze.settlement_prompt.visible,"石阵43像素之外隐藏提示")
 maze.player.position = STONE
 await get_tree().create_timer(0.4).timeout
 _check(maze.settlement_prompt.visible,"石阵范围内提示可见")
 _check(maze._save_position(),"保存石阵进行中位置")
 await get_tree().process_frame
 # 先经过石阵选择，再切回普通通行，验证组件模式不会串用。
 maze.confirmation.open_choice("选择", "前往", "结束")
 maze.confirmation.hide()
 maze.player.position = Roads.EXIT
 await get_tree().process_frame
 await _send_key(KEY_E)
 _check(maze.confirmation.visible,"旧出口真实确认仍出现")
 await _click(maze.confirmation.cancel_button)
 _check(not maze.confirmation.visible and Run.snapshot(sm).active and not maze.player.input_locked,"旧出口继续探索不结算")
 maze.player.position = Roads.ENTRANCE
 await get_tree().process_frame
 await _send_key(KEY_E)
 _check(maze.confirmation.visible,"入口放弃确认仍出现")
 await _send_key(KEY_ENTER)
 _check(not maze.confirmation.visible and Run.snapshot(sm).active and not maze.player.input_locked,"普通确认默认Enter仍取消")
 maze.player.position = STONE
 await get_tree().create_timer(0.4).timeout
 var before: Dictionary = sm.data.duplicate(true)
 await _send_key(KEY_E)
 _check(maze.confirmation.visible and maze.player.input_locked,"石阵E打开并锁定移动")
 var buttons := [maze.confirmation.cancel_button,maze.confirmation.confirm_button]
 for button in buttons:
  var rect: Rect2 = button.get_global_rect()
  _check(rect.size.x>0 and rect.size.y>0 and get_viewport().get_visible_rect().encloses(rect),"按钮在可视区域："+button.text)
 _check(not buttons[0].get_global_rect().intersects(buttons[1].get_global_rect()),"两按钮不重叠")
 await _capture_image("stone_confirmation")
 await _send_key(KEY_ESCAPE)
 _check(not maze.confirmation.visible and not maze.player.input_locked and sm.data==before,"Esc仅关闭不结算并恢复输入")
 await _send_key(KEY_E)
 await _click(maze.confirmation.confirm_button)
 _check(maze.last_message=="下一区域制作中，等做了再接入" and sm.data==before and not maze.player.input_locked,"下一区域仅toast不改体力物资")
 await _capture_image("next_region_toast")
 await _send_key(KEY_E)
 var path: String = sm._active_save_path
 sm._active_save_path = ""
 await _click(maze.confirmation.cancel_button)
 _check(maze.last_message=="返回进度未保存，请重试" and sm.data==before and not maze.player.input_locked,"结束保存失败全量回滚并可操作重试")
 await _capture_image("save_failed")
 sm._active_save_path = path
 await _send_key(KEY_E)
 if resolution_keyboard():
  await _send_key(KEY_ENTER)
 else:
  await _click(maze.confirmation.cancel_button)
 await get_tree().create_timer(1.5).timeout
 _check(sm.maze_exploration_state().region=="restaurant" and not Run.snapshot(sm).active and Run.snapshot(sm).bag.is_empty(),"结束探索状态落盘且清空临时袋")
 _check(is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")),"实际切入餐厅场景")
 for item in bag:
  _check(sm.warehouse_snapshot().get(item,0)==warehouse_before.get(item,0)+bag[item],"每项物资精确入库："+item)
 _check(sm.stamina()==stamina_before-20,"结束不重复扣体力")
 var banked: Dictionary = sm.inventory_snapshot()
 _check(not Run.finish(sm,true,STONE).success and _same_saved(sm.inventory_snapshot(),banked),"重复结束调用不再次入库")
 await _capture_image("restaurant_return")
 var finished := Run.snapshot(sm)
 sm.load_data()
 _check(sm.resume_scene_path()==sm.RESTAURANT_SCENE and _same_saved(Run.snapshot(sm),finished) and _same_saved(sm.inventory_snapshot(),banked),"重新读档仍在餐厅且结算物资保留")
 get_tree().current_scene.queue_free()
 await get_tree().process_frame
 var restaurant = load(sm.resume_scene_path()).instantiate()
 get_tree().root.add_child(restaurant)
 get_tree().current_scene = restaurant
 await get_tree().create_timer(0.5).timeout
 _check(is_instance_valid(get_tree().get_first_node_in_group("restaurant_hud")) and _same_saved(sm.inventory_snapshot(),banked),"读档后真实餐厅重进")
 await _capture_image("restaurant_reload")
 restaurant.queue_free()
 await get_tree().process_frame

func resolution_keyboard() -> bool:
 return suffix.contains('1280')
