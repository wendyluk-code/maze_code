extends "res://tools/tests/fenshui_frog_counter_flow.gd"

const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Moss=preload("res://data/maze/moss_pool_roads.gd")
const GUIDE_SEEN="salt_battle_guide_seen"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"引导检查使用隔离存档")
 if failures: _finish(); return
 _completed()
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"从实际探索开始")
 _check(Run.change_region(sm,"fenshui",preload("res://data/maze/fenshui_roads.gd").SPAWN).success,"先进入分水庭")
 _check(Run.change_region(sm,"salt_pool",Salt.SPAWN).success,"从分水庭进入盐池")
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 var guide: Node=maze.get_node_or_null("SaltBattleGuide")
 _check(is_instance_valid(guide),"盐池实际入口安装首次战斗引导")
 if not is_instance_valid(guide): _finish(); return
 _check(await until_true(func(): return guide.dialog.visible),"入口安全时显示第一句")
 _check(not maze.player.input_locked and not maze.capture_flow.combat_paused(),"引导不锁玩家或暂停战斗")
 var start: Vector2=maze.player.position
 Input.action_press("ui_up")
 var moved: bool=await until_true(func(): return maze.player.position.distance_to(start)>0.1,2.0)
 Input.action_release("ui_up")
 _check(moved,"引导显示时真实移动")
 await picture("salt-guide-first")
 var held_index: int=guide.index
 maze._open_backpack()
 _check(maze._busy and maze.backpack_warehouse.visible,"真实背包打开")
 _check(await until_true(func(): return not guide.dialog.visible),"其他弹窗占用时收起引导")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return guide.dialog.visible),"弹窗结束后继续引导")
 _check(guide.index==held_index,"中断后保留当前句")
 _check(await until_true(func(): return state().combat.cooldown<=0.00001 and state().combat.action_left<=0.00001,2.0),"等待真实攻击冷却")
 var throws_before: int=state().combat.throws
 await click()
 _check(await until_true(func(): return state().combat.throws>throws_before),"引导显示时真实左键攻击")
 _check(await until_true(func(): return not guide.dialog.visible),"攻击期间引导暂时收起")
 _check(await until_true(func(): return guide.dialog.visible,6.0),"攻击结束后从原句继续")
 _check(guide.index==held_index,"攻击中断不丢当前句")
 var text: String=""
 for row in guide.lines: text+=str(row.text)
 _check(text.contains("咆哮") and text.contains("四连") and text.contains("力竭"),"文案覆盖咆哮、四连和力竭")
 _check(text.contains("冲撞") and text.contains("眩晕") and text.contains("水晶"),"文案覆盖冲撞、硬障碍与眩晕")
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  await get_tree().process_frame
  var box: Rect2=guide.dialog.get_global_rect()
  _check(box.position.y>=0 and box.end.y<size.y*0.5 and box.end.x<=size.x,"对话在画面内："+str(size))
  await picture("salt-guide-"+str(size.x))
 while guide.index<guide.lines.size()-1:
  var previous: int=guide.index
  await key(KEY_E)
  if guide.index==previous: await key(KEY_E)
  if guide.index!=previous+1:
   _check(false,"E逐句推进引导")
   _finish()
   return
  if guide.dialog._shown<str(guide.lines[guide.index].text).length(): await key(KEY_E)
  _check(guide.rich_text.get_content_height()<=guide.rich_text.size.y+1.0,"对白完整容纳：第%d句" % (guide.index+1))
  if guide.index in [2,5,7]: await picture("salt-guide-line-%d" % (guide.index+1))
 _check(not bool(sm.data.get(GUIDE_SEEN,false)),"完成最后一句前不记录已看")
 if guide.dialog._shown<str(guide.lines[-1].text).length(): await key(KEY_E)
 var save_path: String=sm._active_save_path
 sm._active_save_path=""
 await key(KEY_E)
 _check(not bool(sm.data.get(GUIDE_SEEN,false)) and not guide.completed,"保存失败不伪装为已完成")
 sm._active_save_path=save_path
 _check(await until_true(func(): return guide.dialog.visible,6.0),"保存恢复后可以重试")
 await key(KEY_E)
 await key(KEY_E)
 _check(bool(sm.data.get(GUIDE_SEEN,false)) and not guide.dialog.visible,"读完且保存成功后关闭")
 sm.load_data()
 _check(bool(sm.data.get(GUIDE_SEEN,false)),"重新读取存档保留完成记录")
 maze.queue_free()
 await get_tree().process_frame
 maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 guide=maze.get_node_or_null("SaltBattleGuide")
 _check(is_instance_valid(guide) and guide.completed and not guide.dialog.visible,"重进盐池不重复引导")
 maze.queue_free()
 await get_tree().process_frame
 sm.data[GUIDE_SEEN]=false
 _check(sm.save(),"另一路入口使用独立未读状态")
 _check(Run.change_region(sm,"moss_pool",Moss.SPAWN).success,"切换到青苔池")
 _check(Run.change_region(sm,"salt_pool",Moss.SALT_SIDE_ARRIVAL).success,"从青苔池进入盐池")
 maze=load("res://scenes/maze_salt_pool.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 guide=maze.get_node_or_null("SaltBattleGuide")
 _check(is_instance_valid(guide) and await until_true(func(): return guide.dialog.visible,6.0),"青苔池落点也能触发引导")
 if is_instance_valid(guide) and guide.dialog.visible:
  while guide.index<guide.lines.size()-1:
   var previous: int=guide.index
   await key(KEY_E)
   if guide.index==previous: await key(KEY_E)
   if guide.index!=previous+1:
    _check(false,"青苔池入口引导逐句推进")
    _finish()
    return
  if guide.dialog._shown<str(guide.lines[-1].text).length(): await key(KEY_E)
  await key(KEY_E)
  if not guide.completed: await key(KEY_E)
  _check(guide.completed and bool(sm.data.get(GUIDE_SEEN,false)),"青苔池入口完成真实保存，用于跨进程复验")
 _finish()
