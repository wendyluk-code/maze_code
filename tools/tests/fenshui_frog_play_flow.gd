extends "res://tools/tests/fenshui_frog_counter_flow.gd"

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 var entry: String="res://tools/previews/fenshui_frog_front24_play.tscn" if _arg("--phase=")=="front24" else "res://tools/previews/fenshui_frog_play.tscn"
 if _arg("--phase=")=="unified": entry="res://tools/previews/fenshui_unified_play.tscn"
 _check(ResourceLoader.exists(entry),"正式战斗试玩入口存在，不再只提供动作演示")
 if failures:
  _finish()
  return
 var bootstrap: Node=load(entry).instantiate()
 viewport.add_child(bootstrap)
 _check(await until_true(func(): return bootstrap.get("gate")!=null and bootstrap.gate.visible,8.0),"真实试玩入口显示原确认组件")
 if failures:
  _finish()
  return
 maze=bootstrap.maze
 if _arg("--phase=")=="unified":
  _check(maze.capture_flow.monsters[Boss.ID].frog_front24!=null and bootstrap._play_title().contains("统一实战"),"统一试玩使用当前1.4倍新图并有独立版本标题")
  _check(maze.capture_flow.target_marker!=null and maze.capture_flow.target_lock_enabled(),"统一试玩同时安装新占位和倒三角的正式消费者")
  _check(maze.capture_flow.monsters[Boss.ID].heal_visual!=null and maze.capture_flow.monsters[Boss.ID].hit_visual!=null and bootstrap._play_message().contains("前后各0.10秒") and bootstrap._play_message().contains("命中特效固定尺寸") and bootstrap._play_message().contains("3秒恢复总血量50%"),"统一试玩保留固定命中特效、最高点窄窗和快速回血说明")
  _check(is_instance_valid(maze.capture_flow.player_hurt_visual) and bootstrap._play_title().contains("玩家受击接入") and bootstrap._play_message().contains("人物受击新动作仅正面"),"统一试玩安装当前玩家受击版本并明示单方向限制")
  for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
   viewport.size=resolution
   await get_tree().process_frame
   var bounds: Rect2=bootstrap.gate.question.get_global_rect()
   _check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(bounds) and Rect2(Vector2.ZERO,Vector2(resolution)).encloses(bootstrap.gate.confirm_button.get_global_rect()) and Rect2(Vector2.ZERO,Vector2(resolution)).encloses(bootstrap.gate.cancel_button.get_global_rect()),"试玩说明和两个按钮完整位于视口内："+str(resolution.x),{"question":str(bounds)})
   await picture("entry_text_"+str(resolution.x))
 if _arg("--phase=")=="front24":
  _check(maze.capture_flow.monsters[Boss.ID].frog_front24!=null and bootstrap._play_title().contains("双前向24姿态"),"新试玩明确标识并启用新图，不拿旧四向窗口代替")
  _check(bootstrap._play_message().contains(String.chr(10)),"候选说明按真实换行显示，不显示转义字符")
 _check(maze.capture_flow.monsters.size()==7 and maze.get_node_or_null("FrogMotionControls")==null,"试玩为4鱼2鳗1蛙正式场景，不挂动作预览")
 var before:=state()
 await get_tree().create_timer(0.2).timeout
 _check(state().combat==before.combat and maze.player.input_locked,"等待用户开始期间不推进战斗")
 await mouse(bootstrap.gate.confirm_button.get_global_rect().get_center())
 maze.capture_flow.window_focused=true
 _check(not bootstrap.gate.visible and not maze.player.input_locked,"Godot内部点击开始进入正常战斗")
 _check(await until_true(func(): return state().combat.elapsed>before.combat.elapsed),"开始后真实探索事务继续推进")
 _check(await until_true(func(): return actor().frog_phase=="airborne" and float(actor().frog_left)<=0.50 and float(actor().frog_left)>=0.30),"试玩入口巨蛙自然追击进入最高点附近")
 await click()
 _check(await until_true(func(): return actor().frog_phase=="exposed"),"试玩入口实际攻击进入正式露腹，不是演示循环")
 await picture("play_counter")
 _finish()
