extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Settlement=preload("res://data/maze/settlement_exit.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"使用隔离存档")
 if failures>0: _finish(); return
 var from_entry: bool=_arg("--phase=")=="entry"
 var restore: bool=_arg("--phase=")=="restore"
 var slot: Dictionary={}
 if restore:
  var listed: Dictionary=sm.list_save_slots()
  _check(listed.success and listed.slots.size()==1,"新进程读取上一轮隔离存档槽")
  if not listed.success or listed.slots.size()!=1: _finish(); return
  slot={"id":listed.slots[0].id,"success":true}
 else:
  _completed()
  sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  sm.cancel_maze_entry()
  _check(Run.begin(sm,Settlement.FRONT if from_entry else Roads.SPAWN).success,"实际探索事务开始")
  if not from_entry: _check(Run.change_region(sm,"fenshui",Salt.FENSHUI_RETURN).success,"实际事务抵达分水庭路标")
  var prepared: Dictionary=sm.data.duplicate(true)
  slot=sm.create_new_game()
  _check(slot.success,"创建隔离正式存档槽")
  if not slot.success: _finish(); return
  var metadata: Dictionary=sm.data[sm.SLOT_META_KEY].duplicate(true)
  sm.data=prepared
  sm.data[sm.SLOT_META_KEY]=metadata
  _check(sm.save(),"保存迷宫检查点到隔离存档槽")
 var start=load("res://scenes/start_screen.tscn").instantiate()
 get_tree().root.add_child(start)
 get_tree().current_scene=start
 await get_tree().process_frame
 await _click(start.continue_button)
 _check(await _until(func(): return start.save_modal.visible and start.save_modal._rows.has(slot.id),5.0),"封面继续游戏列出隔离存档")
 if not start.save_modal.visible: _finish(); return
 await _click(start.save_modal._rows[slot.id])
 await _click(start.save_modal._confirm_button)
 var expected: String="res://scenes/maze_salt_pool.tscn" if restore else ("res://scenes/maze_entry.tscn" if from_entry else "res://scenes/maze_fenshui.tscn")
 _check(await _until(func(): return is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path==expected,15.0),"封面载入存档后进入预期正式迷宫")
 var maze=get_tree().current_scene
 if not is_instance_valid(maze) or maze.scene_file_path!=expected: _finish(); return
 _check(await _until(func(): return get_tree().get_nodes_in_group("prologue_transition").is_empty(),10.0),"续档转场结束并释放输入遮罩")
 maze.capture_flow.window_focused=true
 var ready: bool=await _until(func(): return maze._entry_ready and not maze.player.input_locked and not maze._busy,8.0)
 _check(ready,"当前迷宫入口实际准备就绪")
 if not ready: _finish(); return
 if restore:
  _check(sm.maze_exploration_state().region=="salt_pool" and maze.capture_flow.monsters.size()==7,"新进程从封面恢复盐池及七怪")
  _finish()
  return
 if from_entry:
  maze.capture_flow.set_process(false)
  maze._update_prompts()
  _check(maze.settlement_prompt.visible,"枯水渠路标实际显示")
  await _send_key(KEY_E)
  _check(await _until(func(): return maze.confirmation.visible,3.0),"枯水渠实际E键打开分水庭确认")
  if not maze.confirmation.visible: _finish(); return
  await _click(maze.confirmation.confirm_button)
  _check(await _until(func(): return is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path=="res://scenes/maze_fenshui.tscn",12.0),"实际确认从枯水渠切入分水庭")
  maze=get_tree().current_scene
  if not is_instance_valid(maze) or maze.scene_file_path!="res://scenes/maze_fenshui.tscn": _finish(); return
  maze.capture_flow.window_focused=true
  _check(await _until(func(): return maze._entry_ready and not maze.player.input_locked and not maze._busy,8.0),"分水庭到达后恢复输入")
  maze.capture_flow.set_process(false)
  maze.player.position=Salt.FENSHUI_RETURN
  _check(sm.record_maze_location("fenshui",Salt.FENSHUI_RETURN).success,"隔离验收定位到盐池路标检查点")
 maze.capture_flow.set_process(false)
 maze._update_prompts()
 var info={"position":str(maze.player.position),"near":maze._near_destination(),"ready":maze._entry_ready,"busy":maze._busy,"locked":maze.player.input_locked,"story":maze.yf_encounter.phase,"guide_visible":maze.get_node("FenshuiBattleGuide").dialog.visible}
 _check(maze.settlement_prompt.visible,"真实路标提示在入口就绪后显示",info)
 await _send_key(KEY_E)
 var opened: bool=await _until(func(): return maze.confirmation.visible,3.0)
 _check(opened,"实际E键打开盐池确认",{"near":maze._near_destination(),"busy":maze._busy,"guide_visible":maze.get_node("FenshuiBattleGuide").dialog.visible})
 if not opened: _finish(); return
 await _send_key(KEY_ESCAPE)
 _check(not maze.confirmation.visible and not maze.player.input_locked,"取消确认恢复输入")
 await _until(func(): return maze.settlement_prompt.visible,3.0)
 await _click(maze.settlement_prompt.button)
 _check(await _until(func(): return maze.confirmation.visible,3.0),"取消后点击路标重新打开盐池确认",{"guide_visible":maze.get_node("FenshuiBattleGuide").dialog.visible,"target":maze._near_destination(),"armed":maze._interact_armed})
 if not maze.confirmation.visible: _finish(); return
 var old_id: int=maze.get_instance_id()
 await _click(maze.confirmation.confirm_button)
 var switched: bool=await _until(func(): return is_instance_valid(get_tree().current_scene) and get_tree().current_scene.get_instance_id()!=old_id and get_tree().current_scene.get("region_id")=="salt_pool",8.0)
 _check(switched,"实际确认切换到盐池")
 if switched:
  var next: Node=get_tree().current_scene
  _check(await _until(func(): return next._entry_ready and not next.player.input_locked,8.0),"盐池新场景准备并恢复输入")
  _check(sm.maze_exploration_state().region=="salt_pool","切区结果写入隔离存档")
 _finish()

func _until(predicate: Callable,seconds: float) -> bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
 while not predicate.call() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
 return predicate.call()

func _finish() -> void:
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)
