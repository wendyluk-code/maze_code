extends "res://tools/tests/fenshui_heal_hit_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实七怪入口解锁")
 _check(maze.capture_flow.monsters[Boss.ID].enable_frog_front24(),"沿用当前巨蛙体型")
 for slot in [0,1,2]:
  setup(Vector2(880,490))
  var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
  a.frog_phase="active"
  a.frog_left=0.0
  a.frog_origin=a.position.duplicate()
  a.frog_target=a.position.duplicate()
  a.cooldown=4.0
  var f: Node=maze.capture_flow.monsters[Boss.ID].hit_visual
  var before: int=f.received
  maze.capture_flow.set_process(true)
  await key(KEY_SPACE if slot==0 else (KEY_1 if slot==1 else KEY_2))
  for i in 8:
   await key(KEY_TAB)
   if maze.capture_flow.locked_target_id==Boss.ID: break
  await click()
  _check(await until_true(func(): return f.received>before,1.5),"原攻击实际命中："+str(slot))
  if f.effects.is_empty(): return
  var mode: int=maze.process_mode
  maze.process_mode=Node.PROCESS_MODE_DISABLED
  await get_tree().process_frame
  _check(f.z_index>maze.capture_flow.skill_visual.hero.z_index and f.z_index<maze.capture_flow.power_label.z_index,"命中在出招人物之上、战斗数值之下："+str(slot))
  RenderingServer.force_draw(false)
  var actual: Image=viewport.get_texture().get_image()
  actual.save_png(output+"/actual_"+str(slot)+".png")
  var z: int=f.z_index
  f.z_index=maze.capture_flow.skill_visual.hero.z_index+1
  await get_tree().process_frame
  RenderingServer.force_draw(false)
  var above: Image=viewport.get_texture().get_image()
  above.save_png(output+"/above_pose_"+str(slot)+".png")
  _check(actual.get_data()==above.get_data(),"正常命中画面不会因移到出招人物前面才补出笔触："+str(slot))
  f.z_index=z
  maze.process_mode=mode
  await get_tree().create_timer(0.35).timeout
  _check(f.effects.is_empty(),"正常播放结束清理本次短效："+str(slot))
 await airborne_pause()

func airborne_pause() -> void:
 setup(Vector2(880,490))
 maze.capture_flow.set_process(true)
 await key(KEY_SPACE)
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==Boss.ID: break
 _check(await until_true(func(): return actor().frog_phase=="airborne" and float(actor().frog_left)>0.6,4.0),"自然追击进入早期腾空")
 var monster: Node=maze.capture_flow.monsters[Boss.ID]
 var f: Node=monster.hit_visual
 var count: int=f.received
 await click()
 _check(await until_true(func(): return f.received>count,1.0),"早期腾空真实命中但不误触最高点反击")
 if f.effects.is_empty(): return
 _check(actor().frog_phase=="airborne" and monster.body.position.y<0.0 and f.follow_body_height,"实际腾空节点启用垂直挂点，原反击规则保持")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded and not f.effects.is_empty(),"实际命中短效期间打开原地图暂停")
 if f.effects.is_empty(): return
 var age: float=f.effects[0].age
 var height: float=monster.body.position.y
 await get_tree().create_timer(0.12).timeout
 _check(f.effects[0].age==age and monster.body.position.y==height,"暂停同步冻结短效与身体高度")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return f.effects.is_empty(),1.0),"关闭地图后短效续播正常清理")
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"暂停恢复后原输入可用")
