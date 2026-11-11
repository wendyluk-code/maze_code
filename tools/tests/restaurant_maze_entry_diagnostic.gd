extends "res://tools/tests/ch2_entry_state.gd"
const Settlement=preload("res://data/maze/settlement_exit.gd")
const Salt=preload("res://data/maze/salt_pool_roads.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"使用隔离存档")
 if failures>0: _finish(); return
 _completed()
 sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 var walk_case: bool=_arg("--phase=") in ["walk","walkfight"]
 sm.data.freezer_unlock_notice_seen=true
 var prepared: Dictionary=sm.data.duplicate(true)
 var slot: Dictionary=sm.create_new_game()
 _check(slot.success,"建立隔离正式存档槽")
 if not slot.success: _finish(); return
 var meta: Dictionary=sm.data[sm.SLOT_META_KEY].duplicate(true)
 sm.data=prepared
 sm.data[sm.SLOT_META_KEY]=meta
 _check(sm.save(),"保存已完成第一章的餐厅检查点")
 var start=load("res://scenes/start_screen.tscn").instantiate()
 get_tree().root.add_child(start)
 get_tree().current_scene=start
 await get_tree().process_frame
 await _click(start.continue_button)
 _check(await _until(func(): return start.save_modal.visible and start.save_modal._rows.has(slot.id),5.0),"封面列出餐厅存档")
 if not start.save_modal.visible: _finish(); return
 await _click(start.save_modal._rows[slot.id])
 await _click(start.save_modal._confirm_button)
 _check(await _until(func(): return is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path=="res://scenes/restaurant_map_2d.tscn",15.0),"正式封面续档进入餐厅")
 scene=get_tree().current_scene
 if not is_instance_valid(scene) or scene.scene_file_path!="res://scenes/restaurant_map_2d.tscn": _finish(); return
 _check(await _until(func(): return get_tree().get_nodes_in_group("prologue_transition").is_empty(),10.0),"续档转场释放输入")
 var player=scene.get_node("Player")
 var target=scene.get_node("DepartureEntrance")
 player.global_position=_stand(target)
 player.last_valid=player.global_position
 _check(player.nearest_interactable()==target,"隔离检查点定位到餐厅迷宫入口")
 var hud=get_tree().get_first_node_in_group("restaurant_hud")
 await get_tree().physics_frame
 await _send_key(KEY_E)
 _check(await _until(func(): return hud.confirmation.visible,4.0),"餐厅实际E键打开迷宫出发确认",{"locked":player.input_locked,"physics":player.is_physics_processing(),"tutorial":tm.active,"nearest":str(player.nearest_interactable()),"busy":hud._player_lock_depth})
 if not hud.confirmation.visible: _finish(); return
 if hud.confirmation.selected.is_empty():
  await _click(hud.confirmation.slots[0])
  _check(await _until(func(): return hud.confirmation.selector.visible and not hud.confirmation.checks.is_empty(),4.0),"真实队伍选择器打开")
  if not hud.confirmation.selector.visible or hud.confirmation.checks.is_empty(): _finish(); return
  var id: String=str(hud.confirmation.checks.keys()[0])
  await _click(hud.confirmation.checks[id])
  await _click(hud.confirmation.selection_done)
  _check(hud.confirmation.selected.has(id) and not hud.confirm_button.disabled,"实际选中队员并允许出发")
 await _click(hud.confirm_button)
 _check(await _until(func(): return is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path=="res://scenes/maze_entry.tscn",12.0),"实际确认进入枯水渠")
 var maze=get_tree().current_scene
 if is_instance_valid(maze) and maze.scene_file_path=="res://scenes/maze_entry.tscn":
  _check(await _until(func(): return maze._entry_ready and not maze.player.input_locked,8.0),"枯水渠入口初始化并恢复输入")
  _check(sm.maze_exploration_state().region=="maze_entry","餐厅出发写入隔离探索存档")
  maze.capture_flow.window_focused=true
  if walk_case:
   var entry_points: Array=[]
   var roads: Array=Roads.roads()
   for i in range(2,roads[0].points.size()): entry_points.append(roads[0].points[i])
   for i in range(1,10): entry_points.append(roads[1].points[i])
   for i in range(1,4): entry_points.append(roads[2].points[i])
   entry_points.append(Vector2(135,720))
   var entry_walk: bool=await _walk_path(maze,entry_points,120.0)
   _check(entry_walk,"枯水渠从出生点不传送走到分水庭出口",{"position":str(maze.player.position),"busy":maze.capture_flow.busy})
   if not entry_walk: _finish(); return
  else:
   maze.capture_flow.set_process(false)
   maze.player.position=Settlement.FRONT
   _check(sm.record_maze_location("maze_entry",Settlement.FRONT).success,"隔离检查点定位至枯水渠出口")
  maze._update_prompts()
  _check(maze.settlement_prompt.visible,"枯水渠分水庭路标显示")
  await _click(maze.settlement_prompt.button)
  _check(await _until(func(): return maze.confirmation.visible,3.0),"枯水渠路标打开分水庭确认")
  if not maze.confirmation.visible: _finish(); return
  await _click(maze.confirmation.confirm_button)
  _check(await _until(func(): return is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path=="res://scenes/maze_fenshui.tscn",12.0),"确认后实际进入分水庭")
  maze=get_tree().current_scene
  if not is_instance_valid(maze) or maze.scene_file_path!="res://scenes/maze_fenshui.tscn": _finish(); return
  maze.capture_flow.window_focused=true
  _check(await _until(func(): return maze._entry_ready and not maze.player.input_locked and not maze._busy,8.0),"分水庭入场恢复输入")
  if walk_case:
   var fenshui_points: Array=[Vector2(1495,250),Vector2(1399,283),Vector2(1295,317),Vector2(1214,352),Vector2(1100,350),Vector2(1000,320),Vector2(900,300),Vector2(850,296),Vector2(877,230),Vector2(911,160),Vector2(887,118),Salt.FENSHUI_RETURN]
   var fenshui_walk: bool=await _walk_path(maze,fenshui_points,60.0)
   _check(fenshui_walk,"分水庭从出生点不传送走到盐池入口",{"position":str(maze.player.position),"locked":maze.player.input_locked})
   if not fenshui_walk: _finish(); return
  else:
   maze.capture_flow.set_process(false)
   maze.player.position=Salt.FENSHUI_RETURN
   _check(sm.record_maze_location("fenshui",Salt.FENSHUI_RETURN).success,"隔离检查点定位至盐池路标")
  maze._update_prompts()
  _check(maze.settlement_prompt.visible,"分水庭盐池路标显示")
  await _click(maze.settlement_prompt.button)
  _check(await _until(func(): return maze.confirmation.visible,3.0),"路标打开盐池确认")
  if not maze.confirmation.visible: _finish(); return
  await _click(maze.confirmation.confirm_button)
  _check(await _until(func(): return is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path=="res://scenes/maze_salt_pool.tscn",12.0),"确认后实际进入盐池")
  maze=get_tree().current_scene
  if is_instance_valid(maze) and maze.scene_file_path=="res://scenes/maze_salt_pool.tscn":
   _check(await _until(func(): return maze._entry_ready and not maze.player.input_locked,8.0),"盐池入口恢复输入")
   _check(maze.capture_flow.monsters.size()==7 and sm.maze_exploration_state().region=="salt_pool","盐池七怪与探索存档真实建立")
 _finish()

func _walk_path(maze: Node,points: Array,seconds: float) -> bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
 var next_attack:=0
 for target: Vector2 in points:
  while maze.player.position.distance_to(target)>5.0 and Time.get_ticks_msec()<deadline:
   if maze.capture_flow.busy:
    for action in ["ui_right","ui_left","ui_down","ui_up"]: Input.action_release(action)
    var dialog=maze.capture_flow.dialog
    if dialog.visible and not dialog.flipping:
     if not dialog.victory: return false
     await _click(dialog._cancel_button)
    await get_tree().process_frame
    continue
   var direction: Vector2=maze.player.position.direction_to(target)
   if _arg("--phase=")=="walkfight" and Time.get_ticks_msec()>=next_attack:
    var attack:=InputEventMouseButton.new()
    attack.button_index=MOUSE_BUTTON_LEFT
    attack.position=Vector2(640,360)
    attack.pressed=true
    get_viewport().push_input(attack)
    next_attack=Time.get_ticks_msec()+650
   Input.action_press("ui_right",maxf(direction.x,0.0))
   Input.action_press("ui_left",maxf(-direction.x,0.0))
   Input.action_press("ui_down",maxf(direction.y,0.0))
   Input.action_press("ui_up",maxf(-direction.y,0.0))
   await get_tree().physics_frame
  for action in ["ui_right","ui_left","ui_down","ui_up"]: Input.action_release(action)
  if maze.player.position.distance_to(target)>6.0: return false
 return true

func _until(predicate: Callable,seconds: float) -> bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
 while not predicate.call() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
 return predicate.call()

func _finish() -> void:
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)
