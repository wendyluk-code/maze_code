extends "res://tools/tests/fenshui_hitstop_flow.gd"
## 真实场景内部按键／鼠标与最小化独立视口，不接管桌面输入。
@export var tools_only:=false

func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 _check(get_window().mode==Window.MODE_MINIMIZED and get_window().unfocusable,"远程测试启动即最小化且不可聚焦")
 maze.reparent(render_view)
 for layer in maze.get_children():
  if layer is CanvasLayer and layer.layer==100:
   for old_hint in layer.get_children():
    if old_hint.has_method("dismiss"): old_hint.dismiss()
 baseline=sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial=false
 baseline[Run.KEY].combat.cooldown=0.0
 baseline[Run.KEY].combat.selected=0
 for id in baseline[Run.KEY].monsters: baseline[Run.KEY].monsters[id].status="alive" if id==Rules.IDS[0] else "skipped"
 var a: Dictionary=baseline[Run.KEY].combat.actors[Rules.IDS[0]]
 a.position=[920.0,440.0]
 a.fish_origin=a.position.duplicate()
 a.fish_aim=[0.0,1.0]
 a.fish_hit=false
 Fish.phase(a,"recover",2.5)
 await _reset(Vector2(880,490))
 trial=load("res://tools/previews/fenshui_hitstop_controls.gd").new()
 trial.set("ranged_trial",true)
 render_view.add_child(trial)
 trial.attach(maze)
 await _send_key(KEY_F5)
 _check(trial.hint.text.contains("30毫秒") and trial.hint.text.contains("铁山"),"远程F5切到30毫秒，常驻说明同时告知铁山档位")
 if failures==0:
  RenderingServer.frame_post_draw.connect(_sample_frame)
  if tools_only:
   await _remote_tools()
  else:
   for slot in [KEY_SPACE,KEY_1]:
    for choice in 3:
     await _remote_candidate(slot,choice,true)
     await _remote_candidate(slot,choice,false)
   for slot in [KEY_SPACE,KEY_1]:
    for choice in 3: await _remote_candidate(slot,choice,true,false)
  _check(not invalid_seen,"远程场景交互始终保持探索状态合法")
  _check(not frame_ms.is_empty() and frame_ms.max()<250.0,"远程专项保留250毫秒长帧门槛",{"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
 _finish_hitstop()

func _remote_choose(choice: int, slot: Key) -> void:
 for i in 3:
  if trial.choice==choice: break
  await _send_key(KEY_F5)
 await _send_key(KEY_F6)
 maze.capture_flow.window_focused=true
 await _send_key(slot)
 _check(trial.choice==choice and trial.hint.text.contains(str([0,30,50][choice])+"毫秒"),"真实切换远程档位并显示："+str(choice))

func _sample_frame() -> void:
 if not sampling: return
 var c: Dictionary=Run.snapshot(sm).combat
 var a: Dictionary=c.actors[Rules.IDS[0]]
 var node: Node=maze.capture_flow.monsters[Rules.IDS[0]]
 samples.append({"us":Time.get_ticks_usec()-sample_start,"hp":a.hp,"position":a.position.duplicate(),"action_left":c.action_left,"cooldown":c.cooldown,"held_left":maze.capture_flow.axe_hitstop.state.get("ranged_left",{}).get(Rules.IDS[0],0.0),"hit_left":a.get("hit_remaining",0.0),"flash_left":a.get("flash_remaining",0.0),"flash":node.body.material.get_shader_parameter("flash"),"monster_action_time":node.action_time,"fish_left":a.fish_left,"hero_position":[maze.player.position.x,maze.player.position.y],"throws":c.throws})
 if capture_pixels: frame_images.append(render_view.get_texture().get_image())

func _remote_end() -> void:
 sampling=false
 recording=false
 var dir:=output+"/"+case_name
 DirAccess.make_dir_recursive_absolute(dir)
 for i in frame_images.size(): frame_images[i].save_png(dir+"/frame_%03d.png" % i)
 var held: Array=samples.filter(func(row): return row.held_left>0.000001)
 var resumed: Array=[] if held.is_empty() else samples.filter(func(row): return row.us>held[-1].us)
 var windows: Array=[]
 var groups: Dictionary={}
 for row in held:
  if not groups.has(row.throws): groups[row.throws]=[]
  groups[row.throws].append(row)
 for serial in groups:
  var group: Array=groups[serial]
  var after: Array=samples.filter(func(row): return row.throws==serial and row.us>group[-1].us)
  windows.append({"attack_serial":serial,"first_held_to_first_resumed_sample_ms":float(after[0].us-group[0].us)/1000.0 if not after.is_empty() else -1.0})
 traces.append({"case":case_name,"candidate_ms":[0,30,50][trial.choice],"frames":samples.duplicate(true),"first_held_to_first_resumed_sample_ms":float(resumed[0].us-held[0].us)/1000.0 if groups.size()==1 and not resumed.is_empty() else -1.0,"windows":windows,"pixel_readback_each_frame":capture_pixels})
 frame_images=[]

func _remote_candidate(slot: Key, choice: int, hit: bool, pixels: bool=true) -> void:
 await _remote_choose(choice,slot)
 if not hit:
  maze.player.position=Vector2(781,475)
  maze.player.facing=Vector2.LEFT
  var miss_actor: Dictionary=sm.data[Run.KEY].combat.actors[Rules.IDS[0]]
  miss_actor.position=[1100.0,440.0]
  miss_actor.fish_origin=miss_actor.position.duplicate()
  maze.camera.snap_to_target()
  _check(preload("res://scripts/maze/auto_aim.gd").target(Run.snapshot(sm),maze.player.position)=="","打空初始目标确实在当前招式范围外")
 var hp: float=actor().hp
 _begin_trace("remote_%d_%d_%s_%d%s" % [slot,[0,30,50][choice],"hit" if hit else "miss",render_view.size.x,"" if pixels else "_light"],pixels and hit)
 RenderingServer.force_draw(false)
 await _attack_click()
 if hit: _check(await _wait_until(func(): return actor().hp<hp,180),"真实远程弹体命中："+case_name)
 _check(await _wait_until(func(): return Run.snapshot(sm).combat.shots.is_empty() and Run.snapshot(sm).combat.action_left<=0.000001,180),"远程动作和弹体正常结束："+case_name)
 await get_tree().create_timer(0.22).timeout
 _remote_end()
 _check(hp-actor().hp==(1.0 if hit else 0.0),"三档同伤害，打空零伤害："+case_name)
 var held: Array=samples.filter(func(row): return row.held_left>0.000001)
 _check(not held.is_empty() if hit and choice>0 else held.is_empty(),"真实画面目标停顿只在非零档命中出现："+case_name)
 if not held.is_empty():
  var first: Dictionary=held[0]
  _check(held.all(func(row): return row.position==first.position and is_equal_approx(row.hit_left,first.hit_left)),"暂停期间目标位置和受击时间一致："+case_name)
  _check(held.all(func(row): return row.flash and is_equal_approx(row.monster_action_time,first.monster_action_time)),"目标白闪和动作一起停顿："+case_name)
  _check(held.all(func(row): return is_equal_approx(first.action_left-row.action_left,first.held_left-row.held_left) and is_equal_approx(first.cooldown-row.cooldown,first.held_left-row.held_left)),"目标暂停时每个实际模拟步仍推进玩家动作和冷却："+case_name)
 _check(not maze.capture_flow.monsters[Rules.IDS[0]].action_paused and actor().get("hit_remaining",0.0)<=0.000001,"结束后没有暂停或击退残留："+case_name)

func _remote_tools() -> void:
 await _remote_choose(2,KEY_1)
 _check(trial.hint.is_visible_in_tree() and trial.heal_button.visible,"远程对照保留常驻说明和独立回血工具")
 recording=true
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp<20,120),"远程移动对照先实际命中")
 var point: Vector2=maze.player.position
 Input.action_press("ui_right")
 await get_tree().physics_frame
 await get_tree().physics_frame
 Input.action_release("ui_right")
 _check(maze.player.position.x>point.x,"远程目标停顿不锁住玩家移动")
 await _click(maze.map_ui.mini_button)
 var before: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 var clock: Dictionary=maze.capture_flow.axe_hitstop.state.duplicate(true)
 await get_tree().create_timer(0.15).timeout
 _check(maze.map_ui.expanded and Run.snapshot(sm).combat==before and maze.capture_flow.axe_hitstop.state==clock,"地图暂停同时保留战斗及目标侧时钟")
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"关闭地图恢复原输入")
 recording=false
 await _remote_choose(2,KEY_1)
 recording=true
 await _attack_click()
 await _wait_until(func(): return actor().hp<20,120)
 await _send_key(KEY_F5)
 _check(trial.choice==0 and actor().hp==20 and not maze.capture_flow.axe_hitstop.paused(Rules.IDS[0]),"命中中切远程档位清空旧窗口并恢复生命")
 recording=false
 for slot in [KEY_SPACE,KEY_1]: await _remote_consecutive(slot)
 var saved: Dictionary=trial.baseline.duplicate(true)
 trial.baseline[Run.KEY].combat.actors[Rules.IDS[0]].hp=1
 await _remote_choose(2,KEY_SPACE)
 recording=true
 await _attack_click()
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible,240),"真实致命远程命中后倒地和捕获正常")
 _check(not maze.capture_flow.axe_hitstop.paused(Rules.IDS[0]),"倒地等待能消耗远程停顿，不锁死")
 trial.baseline=saved
 await _click(trial.heal_button)
 _check(actor().hp==20 and trial.choice==2 and not maze.capture_flow.dialog.visible and not maze.player.input_locked,"致命命中后点击回血可继续50毫秒对照")
 recording=false
 for slot in [KEY_SPACE,KEY_1]:
  render_view.size=Vector2i(1152,648)
  await _remote_candidate(slot,2,true)
 _check(trial.hint.get_global_rect().end.x<=1152 and trial.heal_button.get_global_rect().end.x<=1152,"小分辨率提示和回血工具不出屏")
 RenderingServer.force_draw(false)
 render_view.get_texture().get_image().save_png(output+"/remote_tools_1152.png")
 render_view.size=Vector2i(1280,720)
 await _remote_choose(2,KEY_2)
 _begin_trace("iron_70_regression",false)
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp<20,120),"远程窗口内仍可真实使用铁山")
 _check(is_equal_approx(maze.capture_flow.axe_hitstop.state.duration,0.07) and maze.capture_flow.axe_hitstop.state.left>0.0,"铁山在三档远程窗口中固定保留70毫秒")
 await get_tree().create_timer(0.65).timeout
 _remote_end()
 RenderingServer.force_draw(false)
 render_view.get_texture().get_image().save_png(output+"/remote_tools_1280.png")
 _check(not invalid_seen and not maze.player.input_locked,"全部远程工具流程状态合法且输入可用")

func _remote_consecutive(slot: Key) -> void:
 await _remote_choose(2,slot)
 _begin_trace("consecutive_remote_"+str(slot),false)
 for i in 3:
  _check(await _wait_until(func(): return Run.snapshot(sm).combat.cooldown<=0.000001 and Run.snapshot(sm).combat.action_left<=0.000001,240),"真实远程连射等待原冷却：%d／%d" % [slot,i])
  await _attack_click()
  _check(await _wait_until(func(): return actor().hp<20.0-i,180),"真实远程连射每次独立命中：%d／%d" % [slot,i])
 _check(await _wait_until(func(): return not maze.capture_flow.axe_hitstop.paused(Rules.IDS[0]) and actor().get("hit_remaining",0.0)<=0.000001,180),"远程连射结束无累计暂停")
 _check(Run.snapshot(sm).combat.throws==3 and Run.snapshot(sm).combat.hits==3,"远程三次出手与三次伤害一一对应")
 _remote_end()
