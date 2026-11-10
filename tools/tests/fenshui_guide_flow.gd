extends "res://tools/tests/fenshui_frog_counter_flow.gd"

const FenshuiRoads = preload("res://data/maze/fenshui_roads.gd")
const GUIDE_NAME = "FenshuiBattleGuide"
const GUIDE_SEEN = "fenshui_battle_guide_seen"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 if not _verify_isolation():
  _check(false,"隔离用户存档")
  _finish()
  return
 _check(true,"隔离用户存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"从实际探索事务出发")
 _check(Run.change_region(sm,"fenshui",FenshuiRoads.SPAWN).success,"从入口进入分水庭")
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 var guide: Node=maze.get_node_or_null(GUIDE_NAME)
 _check(is_instance_valid(guide),"正式分水庭安装芽芽战斗引导")
 if not is_instance_valid(guide):
  _finish()
  return
 _check(await until_true(func(): return guide.dialog.visible),"入口安全时显示第一句")
 _check(guide.index==0 and guide.dialog.speaker_name.text=="主角","从主角发问开始")
 _check(not maze.player.input_locked and not maze.capture_flow.combat_paused(),"对话不锁移动或暂停战斗")
 var solid: Node=guide.dialog.get_node_or_null("GuideBackground")
 _check(is_instance_valid(solid) and solid is ColorRect and is_equal_approx(solid.color.a,1.0),"对白底色不透出背后的角色信息")
 var continue_label: Node=guide.dialog.get_node_or_null("GuideContinue")
 _check(is_instance_valid(continue_label) and continue_label is Label and continue_label.text=="继续","显示与预览一致的E继续提示")
 var start: Vector2=maze.player.position
 var movement_before={"position":str(start),"paused":maze.capture_flow.combat_paused(),"recovering":maze.capture_flow.player_recovering(),"locked":maze.player.input_locked,"physics":maze.player.is_physics_processing(),"focused":maze.capture_flow.window_focused}
 Input.action_press("ui_left")
 var moved: bool=await until_true(func(): return maze.player.position.distance_to(start)>0.1,2.0)
 Input.action_release("ui_left")
 _check(moved,"显示时可实际移动",{"before":movement_before,"after":{"position":str(maze.player.position),"paused":maze.capture_flow.combat_paused(),"recovering":maze.capture_flow.player_recovering(),"locked":maze.player.input_locked,"physics":maze.player.is_physics_processing(),"focused":maze.capture_flow.window_focused}})
 await key(KEY_E)
 await key(KEY_E)
 _check(guide.index==1 and guide.dialog.speaker_name.text=="芽芽","真实E键推进至芽芽")
 _check(not maze.confirmation.visible,"继续对话不触发附近路标")
 await key(KEY_E)
 await get_tree().process_frame
 _check(guide.rich_text.get_parsed_text()==str(guide.lines[1].text),"实际对白文本完整，非展示标记")
 _check(guide.rich_text.text.contains("[color=#ad4c16]绕过去[/color]"),"实际关键词采用确认的暖橙色")
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  await get_tree().process_frame
  await get_tree().process_frame
  var box: Rect2=guide.dialog.get_global_rect()
  _check(box.position.y>=0 and box.end.y<size.y*0.5 and box.end.x<=size.x,"对白位于画面上方并完整显示："+str(size))
  await picture("guide_"+str(size.x))
 var held_index: int=guide.index
 var previous_position: Vector2=maze.player.position
 var story: Node=maze.yf_encounter
 story.phase="unseen"
 story.record={"version":2,"phase":"unseen","line":0}
 sm.data[sm.YUFENG_SALIA_KEY]=story.record.duplicate(true)
 maze.player.position=Vector2(1517,282)
 var story_start={"focus":maze.capture_flow.window_focused,"paused":maze.capture_flow.combat_paused(),"ready":maze._entry_ready,"retry":story.retry,"position":str(maze.player.position),"save_path":sm._active_save_path}
 var triggered: bool=await until_true(func(): return story.phase=="intro")
 _check(triggered,"跨过入口线实际触发原剧情",{"before":story_start,"after":{"phase":story.phase,"focus":maze.capture_flow.window_focused,"paused":maze.capture_flow.combat_paused(),"retry":story.retry,"position":str(maze.player.position),"record":sm.yufeng_salia_record()}})
 _check(not guide.dialog.visible and story.dialog.visible,"真实剧情开始时引导收起")
 story.dialog.hide_box()
 story._unlock()
 story.phase="done"
 story.record={"version":2,"phase":"done","line":0}
 sm.data[sm.YUFENG_SALIA_KEY]=story.record.duplicate(true)
 _check(sm.save(),"隔离测试恢复剧情已结束状态")
 maze.player.position=previous_position
 _check(await until_true(func(): return guide.dialog.visible),"剧情结束后从中断处继续")
 _check(guide.index==held_index,"剧情中断不丢失当前句")
 _check(await until_true(func(): return state().combat.cooldown<=0.00001 and state().combat.action_left<=0.00001),"按真实状态等待原攻击冷却结束")
 var before: int=state().combat.throws
 await click()
 _check(await until_true(func(): return state().combat.throws>before),"对话期间左键实际攻击未被吞掉")
 _check(await until_true(func(): return not guide.dialog.visible),"进入战斗后引导收起")
 _check(await until_true(func(): return guide.dialog.visible,6.0),"战斗结束后继续对话")
 _check(guide.index==held_index,"战斗中断不丢失当前句")
 while guide.index < guide.lines.size()-1:
  var old_index: int=guide.index
  await key(KEY_E)
  if guide.index==old_index: await key(KEY_E)
  if guide.index!=old_index+1:
   _check(false,"对白逐句正常推进")
   _finish()
   return
  if guide.index in [3,8]:
   await key(KEY_E)
   await get_tree().process_frame
   _check(guide.rich_text.get_content_height()<=guide.rich_text.size.y+1.0,"较长对白完整容纳：第%d句" % (guide.index+1))
   await picture("guide_line_%d" % (guide.index+1))
 _check(not bool(sm.data.get(GUIDE_SEEN,false)),"最后一句未完成不标记已看")
 if guide.dialog._shown < str(guide.lines[-1].text).length(): await key(KEY_E)
 var save_path: String=sm._active_save_path
 sm._active_save_path=""
 await key(KEY_E)
 _check(not bool(sm.data.get(GUIDE_SEEN,false)) and not guide.completed and guide.index==guide.lines.size()-1,"保存失败保持未完成并可重试")
 sm._active_save_path=save_path
 _check(await until_true(func(): return guide.dialog.visible,6.0),"保存恢复后引导重新显示")
 await key(KEY_E)
 await key(KEY_E)
 _check(bool(sm.data.get(GUIDE_SEEN,false)) and not guide.dialog.visible,"完整阅读并保存成功后关闭")
 sm.load_data()
 _check(bool(sm.data.get(GUIDE_SEEN,false)),"重新读取真实隔离存档保留完成标记")
 maze.queue_free()
 await get_tree().process_frame
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 guide=maze.get_node_or_null(GUIDE_NAME)
 _check(is_instance_valid(guide) and not guide.dialog.visible,"重新进入不重复播放")
 _check(Run.valid(Run.snapshot(sm)),"完整引导后探索事务仍有效")
 _finish()
