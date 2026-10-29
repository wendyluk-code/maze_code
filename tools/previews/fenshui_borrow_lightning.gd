extends "res://tools/tests/ch2_entry_state.gd"
## 专用试玩入口：只在调用者显式提供的隔离目录建立体验档。
const Run = preload("res://scripts/maze/capture_run.gd")
const Rules = preload("res://scripts/maze/fenshui_borrow_lightning.gd")
var maze: Node2D
var checking := false

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 checking="--fs01-check" in OS.get_cmdline_user_args()
 if not _verify_isolation():
  push_error("试玩必须使用独立 APPDATA 和 MAZE_QTE03_PROFILE")
  get_tree().quit(1)
  return
 if "--fs01-resume" in OS.get_cmdline_user_args():
  sm._active_save_path="user://chapter-ending-test.json"
  sm.load_data()
  _check(sm.maze_exploration_state().region=="fenshui" and Run.snapshot(sm).combat.get("fs01_trial",false),"跨进程恢复隔离试玩")
 else:
  _completed()
  sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
  sm.cancel_maze_entry()
  _check(Run.begin(sm,Roads.SPAWN).success,"建立真实探索事务")
  var run: Dictionary=Run.snapshot(sm)
  Run.ensure_region(run,"fenshui")
  run.combat.fs01_trial=true
  for id in run.monsters:
   run.monsters[id].status="alive" if id in Rules.IDS else "skipped"
  for pair in [[Rules.IDS[0],Vector2(850,430)],[Rules.IDS[1],Vector2(980,470)],[Rules.IDS[2],Vector2(920,440)]]:
   _check(Rules.Water.water(pair[1]),"试玩魔物合法浅水站位："+pair[0])
   run.combat.actors[pair[0]].position=Rules.pack(pair[1])
  sm.data[Run.KEY]=run
  _check(sm.record_maze_location("fenshui",Vector2(781,475)).success,"独立试玩从岸边开始")
  _check(sm.save() and Run.valid(Run.snapshot(sm)),"试玩状态可保存")
 if failures:
  get_tree().quit(1)
  return
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 get_tree().root.add_child(maze)
 get_tree().current_scene=maze
 if checking or "--fs01-restart-check" in OS.get_cmdline_user_args(): maze.capture_flow.set_process(false)
 get_window().title="料理迷宫 · 分水庭：引鱼借电（独立试玩）"
 var effects=preload("res://scripts/maze/fenshui_trial_effects.gd").new()
 effects.maze=maze
 effects.z_index=1
 maze.add_child(effects)
 var layer:=CanvasLayer.new()
 layer.layer=100
 maze.add_child(layer)
 var hint:=preload("res://scripts/ui/components/feedback_toast.gd").new()
 hint.text="分水庭 · 引鱼借电　白箭头：鱼冲刺方向　金水纹：放电范围
横移躲鱼，上岸躲电，试着把鱼引进电区；攻击和捕获沿用原操作。"
 hint.position=Vector2(300,76)
 hint.add_theme_font_size_override("font_size",15)
 hint.add_theme_color_override("font_color",Color("fff3ce"))
 hint.add_theme_color_override("font_outline_color",Color("27392e"))
 hint.add_theme_constant_override("outline_size",5)
 hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 layer.add_child(hint)
 hint.show_message(hint.text,3600.0)
 await get_tree().create_timer(0.3).timeout
 _check(maze._entry_ready and not maze.player.input_locked,"真实分水庭场景就绪可移动")
 if checking: await _scene_check(effects)
 elif "--fs01-restart-check" in OS.get_cmdline_user_args():
  maze.capture_flow.set_process(false)
  var restored: Dictionary=Run.snapshot(sm)
  if "--fs01-warning-check" in OS.get_cmdline_user_args():
   _check(restored.combat.actors[Rules.IDS[2]].fs_phase=="warning","新进程恢复预警阶段")
   var before_hp: float=restored.combat.actors[Rules.IDS[1]].hp
   for i in 35: Run.combat_tick(sm,Vector2(900,470),0.02)
   _check(Run.snapshot(sm).combat.actors[Rules.IDS[1]].hp==before_hp-5,"恢复预警后只放电一次")
   _check(Run.snapshot(sm).combat.actors[Rules.IDS[2]].fs_phase=="discharge" and sm.save(),"保存真实结算后的放电画面阶段")
  else:
   _check(restored.combat.actors[Rules.IDS[2]].fs_phase=="discharge","新进程恢复已放电阶段")
   var hp: float=restored.combat.hp
   var fish_hp: float=restored.combat.actors[Rules.IDS[1]].hp
   for i in 5: Run.combat_tick(sm,Vector2(900,470),0.02)
   _check(Run.snapshot(sm).combat.hp==hp and Run.snapshot(sm).combat.actors[Rules.IDS[1]].hp==fish_hp,"新进程恢复放电画面不重复扣血")
  _report_and_quit()

func _scene_check(effects: Node) -> void:
 maze.capture_flow.set_process(true)
 maze.capture_flow.window_focused=true
 var start: Vector2=maze.player.position
 Input.action_press("ui_left")
 await get_tree().create_timer(0.2).timeout
 Input.action_release("ui_left")
 _check(maze.player.position.distance_to(start)>5.0,"真实方向输入可沿岸移动")
 maze.player.position=start
 for reason in ["focus","map","locked"]:
  maze.capture_flow.window_focused=reason!="focus"
  maze.map_ui.expanded=reason=="map"
  maze.player.input_locked=reason=="locked"
  var frozen: Dictionary=Run.snapshot(sm).combat.duplicate(true)
  await get_tree().create_timer(0.25).timeout
  _check(Run.snapshot(sm).combat==frozen,"暂停不推进伤害与攻击阶段："+reason)
 maze.map_ui.expanded=false
 maze.player.input_locked=false
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(false)
 var run: Dictionary=Run.snapshot(sm)
 var eel: Dictionary=run.combat.actors[Rules.IDS[2]]
 eel.fs_phase="warning"
 eel.fs_left=0.65
 eel.fs_origin=eel.position.duplicate()
 eel.fs_aim=[-1.0,0.0]
 eel.fs_hit=false
 eel.mode="windup"
 eel.windup=0.65
 var fish: Dictionary=run.combat.actors[Rules.IDS[0]]
 fish.fs_phase="warning"
 fish.fs_left=0.4
 fish.fs_origin=fish.position.duplicate()
 fish.fs_aim=[-1.0,0.0]
 fish.fs_hit=false
 fish.mode="windup"
 fish.windup=0.4
 sm.data[Run.KEY]=run
 _check(sm.save(),"预警阶段保存")
 var output:=_arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  get_window().size=size
  maze.camera.snap_to_target()
  await get_tree().create_timer(0.15).timeout
  await RenderingServer.frame_post_draw
  var error:=get_viewport().get_texture().get_image().save_png(output+"/warning_%dx%d.png" % [size.x,size.y])
  _check(error==OK,"双分辨率真实预警截图："+str(size))
 _check(effects._tiles.size()>0,"电纹按局部浅水裁切")
 var before: Dictionary=sm.data.duplicate(true)
 var original: String=sm._active_save_path
 sm._active_save_path=""
 var failed: Dictionary=Run.combat_tick(sm,Vector2(900,470),0.5)
 _check(not failed.success and sm.data==before,"战斗保存失败全量回滚预警、生命与奖励")
 sm._active_save_path=original
 sm.load_data()
 _check(Run.snapshot(sm).combat.actors[Rules.IDS[2]].fs_phase=="warning","预警读档不提前放电")
 # 使用真实事务步进，保留现有角色防御和经验入口。
 var fish_hp: float=Run.snapshot(sm).combat.actors[Rules.IDS[1]].hp
 for i in 40: Run.combat_tick(sm,Vector2(900,470),0.02)
 _check(Run.snapshot(sm).combat.actors[Rules.IDS[1]].hp<fish_hp,"真实存档事务中的雷电伤鱼")
 for id in Rules.IDS:
  var a: Dictionary=sm.data[Run.KEY].combat.actors[id]
  if id.contains("silverfish"):
   a.fs_phase="recover"
   a.fs_left=0.5
 sm.save()
 await get_tree().create_timer(0.1).timeout
 # 场景显示从已提交快照读取，不额外驱动伤害。
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/after_discharge.png")
 # 受控低生命样例走正式击败、付费捕获与奖励事务，不改变生产数值和概率。
 var checkpoint: Dictionary=sm.data.duplicate(true)
 run=Run.snapshot(sm)
 var id: String=Rules.IDS[1]
 run.combat.actors[id].hp=1.0
 run.combat.actors[Rules.IDS[2]].fs_phase="warning"
 run.combat.actors[Rules.IDS[2]].fs_left=0.01
 run.monsters[id].capture_roll=0.0
 sm.data[Run.KEY]=run
 _check(Run.combat_tick(sm,Vector2(900,470),0.02).success and Run.snapshot(sm).combat.actors[id].hp==0,"借电击败鱼进入原有零生命状态")
 _check(Run.snapshot(sm).monsters[id].get("experience_generation",-1)==Run.snapshot(sm).monsters[id].refresh_count,"借电击败只记一次原有经验回执")
 _check(Run.defeat(sm,id,Vector2(900,470)).success,"借电击败进入原捕获事务")
 _check(Run.start_capture(sm,id).success and Run.finish_capture(sm,id,true).success,"原付费与捕获操作结论仍可提交")
 var reward: Dictionary=Run.resolve(sm,id,true)
 _check(reward.success and reward.caught and not reward.items.is_empty(),"原捕获概率与食材奖励链保留")
 var bag: Dictionary=Run.snapshot(sm).bag.duplicate(true)
 _check(not Run.resolve(sm,id,true).success and Run.snapshot(sm).bag==bag,"不能重复领取捕获奖励")
 sm.data=checkpoint
 run=Run.snapshot(sm)
 run.combat.actors[Rules.IDS[2]].fs_phase="warning"
 run.combat.actors[Rules.IDS[2]].fs_left=0.65
 sm.data[Run.KEY]=run
 _check(sm.save(),"保存预警阶段供第二个进程恢复")
 _report_and_quit()

func _report_and_quit() -> void:
 var report:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"user_dir":OS.get_user_data_dir()},"	"))
 print("FS01_SCENE：",checks,"项，失败",failures)
 get_tree().quit(1 if failures else 0)
