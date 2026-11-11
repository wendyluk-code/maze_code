extends "res://tools/tests/fenshui_hitstop_flow.gd"
@export var render_check:=false
@export var ranged_check:=false
## 从实际场景重载观察提示生命周期，不控制用户窗口。
func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 _check(get_window().mode==Window.MODE_MINIMIZED and get_window().unfocusable,"测试从启动最小化且不可聚焦")
 if render_check: maze.reparent(render_view)
 for layer in maze.get_children():
  if layer is CanvasLayer and layer.layer==100:
   for old_hint in layer.get_children():
    if old_hint.has_method("dismiss"): old_hint.dismiss()
 baseline=sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial=false
 baseline[Run.KEY].combat.cooldown=0.0
 baseline[Run.KEY].combat.selected=2
 for id in baseline[Run.KEY].monsters: baseline[Run.KEY].monsters[id].status="alive" if id==Rules.IDS[0] else "skipped"
 var a: Dictionary=baseline[Run.KEY].combat.actors[Rules.IDS[0]]
 a.position=[920.0,440.0]
 a.fish_origin=a.position.duplicate()
 a.fish_aim=[0.0,1.0]
 a.fish_hit=false
 Fish.phase(a,"recover",2.5)
 await _reset(Vector2(880,490))
 trial=load("res://tools/previews/fenshui_hitstop_controls.gd").new()
 trial.ranged_trial=ranged_check
 if render_check: render_view.add_child(trial)
 else: add_child(trial)
 trial.attach(maze)
 _check(trial.hint.is_visible_in_tree(),"首次进入对照提示可见")
 await _send_key(KEY_F5)
 await _send_key(KEY_F6)
 _check(trial.hint.is_visible_in_tree(),"F5／F6后提示仍可见")
 if render_check:
  await _heal_live()
  for size in [Vector2i(1280,720),Vector2i(1152,648)]:
   render_view.size=size
   RenderingServer.force_draw(false)
   render_view.get_texture().get_image().save_png(output+"/heal_tools_"+str(size.x)+".png")
   _check(trial.heal_button.get_global_rect().end.x<=size.x and trial.hint.get_global_rect().end.x<=size.x,"双分辨率提示和回血按钮在屏内："+str(size.x))
  _finish_hitstop()
  return
 var reference: WeakRef=weakref(trial)
 var old_lifetime: float=trial.hint.get("_remaining")
 _check(get_tree().reload_current_scene()==OK,"执行与游戏相同的当前地图重载入口")
 await get_tree().process_frame
 await get_tree().process_frame
 var remaining: Node=reference.get_ref()
 _check(remaining!=null and is_instance_valid(remaining.hint) and remaining.hint.is_visible_in_tree(),"重载当前地图后提示和对照控件仍可达",{"control_alive":remaining!=null,"hint_seconds_before":old_lifetime,"has_scene_changed":get_tree().has_signal("scene_changed")})
 if remaining!=null:
  _check(is_instance_valid(remaining.maze) and remaining.maze==get_tree().current_scene,"重载后工具重新绑定实际新场景")
  _check(remaining.get("heal_button") is Button,"提供独立可点击的怪物回满血入口")
  maze=get_tree().current_scene
  trial=remaining
  _check(trial.choice==1 and (is_equal_approx(maze.capture_flow.axe_hitstop.state.get("ranged_duration",0.0),0.03) if ranged_check else is_equal_approx(maze.capture_flow.axe_hitstop.state.duration,0.04)),"重载后保持原档位并安装正确时钟")
  if failures==0:
   await _heal_live()
   await _heal_defeated()
   await _heal_captured()
   await _leave_and_return()
 _finish_hitstop()

func _send_key(key: Key) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=key
  event.physical_keycode=key
  event.pressed=pressed
  (render_view if render_check else get_viewport()).push_input(event)
  await get_tree().process_frame

func _click(control: Control) -> void:
 var view: Viewport=control.get_viewport()
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=control.get_global_rect().get_center()
  event.pressed=pressed
  view.push_input(event)
 await get_tree().process_frame

func _heal_live() -> void:
 await _send_key(KEY_F5)
 await _send_key(KEY_F6)
 maze.capture_flow.set_process(false)
 maze.player.set_physics_process(false)
 maze.player.position=Vector2(890,490)
 var c: Dictionary=sm.data[Run.KEY].combat
 c.hero=[890.0,490.0]
 c.actors[Rules.IDS[0]].hp=3.0
 var before: Dictionary=c.duplicate(true)
 var clock: Dictionary=maze.capture_flow.axe_hitstop.state.duplicate(true)
 var position: Vector2=maze.player.position
 await _click(trial.heal_button)
 var expected: Dictionary=before.duplicate(true)
 expected.actors[Rules.IDS[0]].hp=20
 var actual: Dictionary=Run.snapshot(sm).combat
 var differences: Array=[]
 for key in expected:
  if actual.get(key)!=expected[key]: differences.append({"key":key,"before":expected[key],"after":actual.get(key)})
 _check(actual==expected,"真实点击仅把活体怪物血量恢复到原20上限",{"differences":differences})
 _check(maze.player.position==position and trial.choice==2 and maze.capture_flow.axe_hitstop.state==clock,"活体回血保留玩家站位、当前档位及当前时钟")
 _check(Run.snapshot(sm).combat.throws==before.throws,"点击回血不穿透成攻击")
 _check(trial.hint.is_visible_in_tree() and trial.tool_status.text.contains("已回满血"),"回血后保留提示并显示执行结果")
 sm.data[Run.KEY].combat.actors[Rules.IDS[0]].hp=4.0
 var original: String=sm._active_save_path
 var rollback: Dictionary=sm.data.duplicate(true)
 sm._active_save_path=""
 await _click(trial.heal_button)
 _check(sm.data==rollback and trial.tool_status.text.contains("失败"),"回血保存失败不留下血量变化")
 sm._active_save_path=original
 await _click(trial.heal_button)
 _check(actor().hp==20.0,"保存恢复后独立回血可再次使用")

func _heal_defeated() -> void:
 recording=true
 await _send_key(KEY_F6)
 maze.capture_flow.set_process(false)
 sm.data[Run.KEY].combat.actors[Rules.IDS[0]].hp=0.0
 maze.capture_flow.set_process(true)
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible,240),"实际倒地等待后打开原捕获对话")
 await _click(trial.heal_button)
 _check(actor().hp==20.0 and trial.choice==2 and not maze.capture_flow.dialog.visible,"捕获对话上仍可点击回血并重置对照")
 _check(trial.tool_status.text.contains("重置站位") and maze.player.position==Vector2(880,490),"倒地恢复明确告知完整重置且保留档位")
 _check(not maze.player.input_locked and maze.player.is_physics_processing(),"倒地恢复后输入重新可用")
 recording=false

func _heal_captured() -> void:
 maze.capture_flow.set_process(false)
 var run: Dictionary=Run.snapshot(sm)
 run.combat.actors[Rules.IDS[0]].hp=0.0
 run.monsters[Rules.IDS[0]].capture_roll=0.0
 sm.data[Run.KEY]=run
 _check(Run.defeat(sm,Rules.IDS[0],maze.player.position).success,"用真实事务建立已击败目标")
 _check(Run.start_capture(sm,Rules.IDS[0]).success and Run.finish_capture(sm,Rules.IDS[0],true).success,"用真实事务完成捕获操作")
 _check(Run.resolve(sm,Rules.IDS[0],true).success,"真实结算捕获状态")
 await _click(trial.heal_button)
 _check(Run.snapshot(sm).monsters[Rules.IDS[0]].status=="alive" and actor().hp==20.0,"已捕获目标通过隔离重置恢复可对照")
 _check(Run.snapshot(sm).bag==trial.baseline[Run.KEY].bag and trial.choice==2,"捕获恢复不重复发奖励，档位不变")

func _leave_and_return() -> void:
 _check(get_tree().change_scene_to_file("res://scenes/start_screen.tscn")==OK,"真实切换到非对照场景")
 await get_tree().process_frame
 await get_tree().process_frame
 _check(trial.hint.is_visible_in_tree() and trial.hint.text.contains("已离开") and not trial.active_trial(),"离开对照后仍明确显示当前不在对照")
 _check(trial.heal_button.text=="返回卡肉对照","非对照场景的按钮明确改为返回，不给其他怪物回血")
 await _click(trial.heal_button)
 await get_tree().process_frame
 await get_tree().process_frame
 maze=get_tree().current_scene
 _check(trial.active_trial() and trial.choice==2 and maze.capture_flow.axe_hitstop!=null,"点击返回后重新进入原档位对照")
 _check(trial.heal_button.text=="怪物回满血" and trial.hint.is_visible_in_tree(),"返回后提示和独立回血工具恢复")
