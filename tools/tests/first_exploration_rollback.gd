extends "res://tools/tests/first_exploration.gd"
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Progress := preload("res://scripts/characters/character_progression.gd")
const Guide := preload("res://scripts/ch2_exploration_guide.gd")
func _capture_and_reward() -> void:
 var id="slime_1"
 sm.data[Run.KEY].combat.actors[id].hp=0
 _check(Run.defeat(sm,id,Run.monster_for(Run.snapshot(sm),id).position).success,"击败首只史莱姆")
 _check(Run.start_capture(sm,id).success,"捕获扣饱腹")
 _check(Run.finish_capture(sm,id,false).success and Run.resolve(sm,id,true).caught,"首探捕获成功")
 _check(sm.accept_elder_firewood(Vector2(839,503)).success,"重新接取白虎任务")
 sm.data[sm.INVENTORY_KEY]["wood"]=12
 _check(sm.deliver_elder_firewood(Vector2(839,503)).success,"交付采集夹具的木材并领取真实奖励")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"隔离存档")
 if failures: get_tree().quit(1); return
 sm.set_script(preload("res://tools/tests/audio_guard_save.gd"))
 sm.audio_guard_root=OS.get_environment("MAZE_QTE03_PROFILE").replace("\\","/").simplify_path().to_lower()
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  DisplayServer.window_set_size(resolution)
  suffix=str(resolution.x)
  _completed()
  sm.complete_chapter_1()
  tm.active=false
  var original_stock: Dictionary=sm.warehouse_snapshot()
  for attempt in range(2):
   _check(Run.begin(sm,Roads.SPAWN).success,"首探重试入场")
   var baseline: Dictionary=sm.data[Gate.CHECKPOINT].duplicate(true)
   _check(sm.data[Guide.KEY].seen.is_empty() and Run.snapshot(sm).first_eligible,"重试恢复首探资格及全部未读教学")
   await _capture_and_reward()
   sm.data[Guide.KEY].seen={"05_power":true,"06_absorb":true,"07_capture":true,"11_suppress":true,"13_bag":true}
   sm.data[Run.KEY].combat.hp=0
   sm.save()
   sm.load_data()
   _check(sm.data.has(Gate.CHECKPOINT),"退出重进保留入场快照")
   var path: String=sm._active_save_path
   var failed: Dictionary=sm.data.duplicate(true)
   sm._active_save_path=""
   _check(not Run.finish(sm,false,Roads.SPAWN).success and sm.data==failed,"回档保存失败完整回滚")
   sm._active_save_path=path
   _check(Run.finish(sm,false,Roads.SPAWN).success,"首探战败原子回档")
   _check(sm.data[Progress.FOOD_KEY].values==baseline[Progress.FOOD_KEY].values,"战败不扣任何饱腹度")
   _check(sm.warehouse_snapshot()==original_stock and not sm.elder_backpack_unlocked(),"撤销本趟奖励和白虎任务完成")
   _check(not sm.data.has(Guide.KEY) and Gate.departure(sm) and Day.pending_loot(sm).is_empty(),"清空教学、返程结算并保持首探门禁")
   _check(not Run.finish(sm,false,Roads.SPAWN).success,"重复回档不重复处理")
   sm.load_data()
   var restaurant=load("res://scenes/restaurant_map_2d.tscn").instantiate()
   get_tree().root.add_child(restaurant)
   get_tree().current_scene=restaurant
   await get_tree().create_timer(0.6).timeout
   var hud=get_tree().get_first_node_in_group("restaurant_hud")
   _check(hud.exploration_guide.reading and hud.exploration_guide.lesson_id=="first_defeat_retry","每次战败返店显示芽芽提示")
   _check(not hud.day_menu.visible,"战败返店不弹第一天菜单")
   await _send_key(KEY_E)
   await _shot_gate("retry_notice_"+suffix+"_"+str(attempt))
   await _send_key(KEY_E)
   _check(not sm.data.has(Gate.RETRY_NOTICE) and not hud._player.input_locked,"读完保存提示状态并恢复输入")
   restaurant.queue_free()
   await get_tree().process_frame
  _check(Run.begin(sm,Roads.SPAWN).success,"最终重试")
  await _capture_and_reward()
  var saved_bag: Dictionary=sm.data[Run.KEY].bag.duplicate(true)
  sm.data[Run.KEY].bag={}
  _check(not Run.finish(sm,true,Vector2(116,724)).success,"白虎完成但无捕获食材不能完成首探")
  sm.data[Run.KEY].bag=saved_bag
  _check(Run.finish(sm,true,Vector2(116,724)).success,"成功带回食材完成首探")
  _check(not sm.data.has(Gate.CHECKPOINT) and not Gate.pending(sm),"成功后释放回档快照及门禁")
  _check(sm.warehouse_snapshot().get("moondew_honey")==3 and Day.validate_menu(sm,{"slime_candy":1}).success,"连续失败无奖励叠加且保证一份料理")
  var restaurant=load("res://scenes/restaurant_map_2d.tscn").instantiate()
  get_tree().root.add_child(restaurant)
  get_tree().current_scene=restaurant
  await get_tree().create_timer(0.6).timeout
  var hud=get_tree().get_first_node_in_group("restaurant_hud")
  _check(hud.return_loot.visible,"成功返店先显示结算")
  await _click(hud.return_loot._confirm_button)
  await get_tree().create_timer(0.2).timeout
  _check(hud.exploration_guide.reading,"成功后进入经营教学")
  hud.exploration_guide._read_done()
  await get_tree().create_timer(0.2).timeout
  _check(hud.day_menu.visible and not hud.day_menu.cancel_button.visible,"第一天菜单隐藏稍后")
  await _send_key(KEY_ESCAPE)
  _check(hud.day_menu.visible,"Esc不能绕过第一天菜单")
  await _click(hud.day_menu.list.get_node("Recipe_slime_candy/RecipeRow/Selected"))
  _check(not hud.day_menu.confirm_button.disabled,"真实点选料理可开始营业")
  await _shot_gate("first_day_required_"+suffix)
  await _click(hud.day_menu.confirm_button)
  _check(not hud.day_menu.visible and Day.snapshot(sm).status=="open" and not hud._player.input_locked,"营业提交成功后关闭菜单恢复输入")
  restaurant.queue_free()
  await get_tree().process_frame
  _check(Run.begin(sm,Roads.SPAWN).success,"后续探索仍可进入")
  sm.data[Run.KEY].combat.hp=0
  _check(Run.finish(sm,false,Roads.SPAWN).success and not sm.data.has(Gate.RETRY_NOTICE) and not Gate.pending(sm),"后续战败不启用首探回档")
 # 旧首探档无快照：按授权恢复首章完成基线。
 _completed()
 sm.complete_chapter_1()
 Run.begin(sm,Roads.SPAWN)
 await _capture_and_reward()
 sm.data.erase(Gate.CHECKPOINT)
 sm.data[Run.KEY].combat.hp=0
 _check(Run.finish(sm,false,Roads.SPAWN).success,"旧首探无快照允许重置")
 _check(sm.can_enter_maze() and not sm.elder_backpack_unlocked() and sm.warehouse_snapshot().get("moondew_honey",0)==0,"旧档保留首章完成并清除首探奖励")
 _check(Run.begin(sm,Roads.SPAWN).success and Run.snapshot(sm).first_eligible,"旧档重置后重新进入全部教学")
 maze=load("res://scenes/maze_entry.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 await get_tree().create_timer(0.7).timeout
 var guide=maze.exploration_guide
 var flow=maze.capture_flow
 sm.data[Run.KEY].combat.actors.slime_1.hp=0
 flow._encounter("slime_1")
 _check(await _wait_until(func(): return guide.reading and guide.lesson_id=="06_absorb",240),"重试实景重新播放吸收教学")
 await get_tree().create_timer(0.1).timeout
 await _send_key(KEY_E)
 await _send_key(KEY_E)
 await get_tree().create_timer(0.1).timeout
 _check(guide.gate and guide.lesson_id=="06_yes","重试再次强制确认捕获")
 await _click(flow.dialog._confirm_button)
 _check(await _wait_until(func(): return guide.reading and guide.lesson_id=="07_capture",180),"重试重新播放饱腹消耗教学")
 await get_tree().create_timer(0.1).timeout
 await _send_key(KEY_E)
 await _send_key(KEY_E)
 await get_tree().create_timer(0.1).timeout
 await _click(flow.attempt.no_button)
 _check(flow.attempt.visible and flow.attempt.mode=="ready","重试仍不能跳过强制捕获")
 await _shot_gate("retry_forced_capture")
 maze.queue_free()
 await get_tree().process_frame
 _check(sm.audio_guard_blocked==0,"全部实际写盘均在隔离目录")
 GameAudio.set_world_music(&"")
 await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
 var file=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"\t"))
 get_tree().quit(1 if failures else 0)
