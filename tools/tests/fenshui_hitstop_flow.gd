extends "res://tools/tests/fenshui_player_attack_flow.gd"
var trial: Node
var render_view: SubViewport
var traces: Array=[]
var samples: Array=[]
var frame_images: Array[Image]=[]
var sampling:=false
var capture_pixels:=false
var sample_start:=0
var case_name: String=""

func _ready() -> void:
 super._ready()
 render_view=SubViewport.new()
 render_view.size=Vector2i(1280,720)
 render_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 render_view.handle_input_locally=false
 get_tree().root.add_child.call_deferred(render_view)

func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 _check(get_window().unfocusable and ProjectSettings.get_setting_with_override("display/window/size/no_focus"),"启动不可聚焦标记生效，原生焦点另由运行器核验",{"unfocusable":get_window().unfocusable,"godot_has_focus":get_window().has_focus(),"setting":ProjectSettings.get_setting_with_override("display/window/size/no_focus")})
 _check(get_window().mode==Window.MODE_MINIMIZED,"测试窗口从启动即最小化，不占主屏",{"mode":get_window().mode})
 if failures>0:
  _finish_hitstop()
  return
 maze.reparent(render_view)
 for layer in maze.get_children():
  if layer is CanvasLayer and layer.layer==100:
   for old_hint in layer.get_children():
    if old_hint.has_method("dismiss"): old_hint.dismiss()
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var image: Image=render_view.get_texture().get_image()
 _check(not image.is_empty() and image.get_width()==1280,"最小化窗口下独立视口仍生成真实游戏画面")
 image.save_png(output+"/screenless_probe.png")
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
 if ResourceLoader.exists("res://tools/previews/fenshui_hitstop_controls.gd"):
  trial=load("res://tools/previews/fenshui_hitstop_controls.gd").new()
  render_view.add_child(trial)
  trial.attach(maze)
 await _send_key(KEY_F5)
 var clock: RefCounted=maze.capture_flow.axe_hitstop
 _check(clock!=null and is_equal_approx(float(clock.state.get("duration",0.0)),0.04),"游戏内F5从无停顿切到40毫秒档")
 if failures==0:
  RenderingServer.frame_post_draw.connect(_sample_frame)
  for choice in range(3):
   await _candidate(choice,true)
   await _candidate(choice,false)
  for choice in range(3): await _candidate(choice,true,false)
  await _pause_and_move()
  await _switch_during_hit()
  await _multiple_targets()
  await _consecutive()
  await _lethal()
  render_view.size=Vector2i(1152,648)
  await _candidate(2,true)
  _check(trial.hint.get_global_rect().end.x<=1152,"较小分辨率下档位与操作说明不出屏")
  _check(not invalid_seen,"完整输入流程保持探索状态有效")
  _check(not frame_ms.is_empty() and frame_ms.max()<250.0,"本次隔离对照保留250毫秒长帧门槛",{"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
  var control_ref: WeakRef=weakref(trial)
  maze.capture_flow.set_process(false)
  maze.queue_free()
  await get_tree().process_frame
  await get_tree().process_frame
  _check(control_ref.get_ref()!=null and trial.hint.is_visible_in_tree() and trial.hint.text.contains("已离开") and trial.heal_button.text=="返回卡肉对照","离开场景后仍有明确说明及可达的返回入口")
 _finish_hitstop()

func _finish_hitstop() -> void:
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"frame_ms":frame_ms,"traces":traces,"window_mode":get_window().mode,"godot_focus_cache":get_window().has_focus()},"  "))
 get_tree().quit(1 if failures else 0)

func _send_key(key: Key) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=key
  event.physical_keycode=key
  event.pressed=pressed
  render_view.push_input(event)
  await get_tree().process_frame

func _attack_click() -> void:
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=Vector2(850,400)
  event.pressed=pressed
  render_view.push_input(event)
  await get_tree().process_frame

func _click(control: Control) -> void:
 var point: Vector2=control.get_global_rect().get_center()
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=point
  event.pressed=pressed
  render_view.push_input(event)

func _choose(choice: int) -> void:
 for i in 3:
  if trial.choice==choice: break
  await _send_key(KEY_F5)
 await _send_key(KEY_F6)
 maze.capture_flow.window_focused=true
 await get_tree().process_frame
 _check(trial.choice==choice and trial.hint.text.contains(str([0,40,70][choice])+"毫秒"),"真实切档及当前档位显示："+str(choice))

func _sample_frame() -> void:
 if not sampling: return
 var c: Dictionary=Run.snapshot(sm).combat
 if not c.has("action_left"): return
 var a: Dictionary=c.actors[Rules.IDS[0]]
 var monster: Node=maze.capture_flow.monsters[Rules.IDS[0]]
 var sweep: Sprite2D=maze.capture_flow.skill_visual.sweep
 var serial: int=c.throws
 samples.append({"us":Time.get_ticks_usec()-sample_start,"hp":a.hp,"position":a.position.duplicate(),"action_left":c.action_left,"cooldown":c.cooldown,"elapsed":c.elapsed,"held_left":maze.capture_flow.axe_hitstop.state.get("left",0.0),"flash_left":a.get("flash_remaining",0.0),"flash":monster.body.material.get_shader_parameter("flash"),"hit_left":a.get("hit_remaining",0.0),"monster_action_time":monster.action_time,"sweep_visible":sweep.visible,"sweep_angle":sweep.rotation,"sweep_alpha":sweep.modulate.a,"hero_frame":str(maze.capture_flow.skill_visual.hero.texture.region) if maze.capture_flow.skill_visual.hero.texture is AtlasTexture else ""})
 samples[-1]["attack_serial"]=serial
 samples[-1]["player_hp"]=c.hp
 if capture_pixels: frame_images.append(render_view.get_texture().get_image())

func _begin_trace(name: String, pixels: bool=true) -> void:
 case_name=name
 section=name
 samples=[]
 frame_images=[]
 sample_start=Time.get_ticks_usec()
 capture_pixels=pixels
 sampling=true
 recording=true
 last_frame=sample_start

func _end_trace() -> void:
 sampling=false
 recording=false
 var frozen: Array=samples.filter(func(row): return row.held_left>0.000001)
 var info: Dictionary={"case":case_name,"frames":samples.duplicate(true),"frozen_frames":frozen.size(),"candidate_ms":[0,40,70][trial.choice]}
 var windows: Array=[]
 var groups: Dictionary={}
 for row in frozen:
  if not groups.has(row.attack_serial): groups[row.attack_serial]=[]
  groups[row.attack_serial].append(row)
 for serial in groups:
  var group: Array=groups[serial]
  var first: Dictionary=group[0]
  var last: Dictionary=group[-1]
  var after: Array=samples.filter(func(row): return row.attack_serial==serial and row.us>last.us)
  windows.append({"attack_serial":serial,"held_samples":group.size(),"first_to_last_held_sample_ms":float(last.us-first.us)/1000.0,"first_held_to_first_resumed_sample_ms":float(after[0].us-first.us)/1000.0 if not after.is_empty() else -1.0})
 info["windows"]=windows
 info["pixel_readback_each_frame"]=capture_pixels
 traces.append(info)
 var directory:=output+"/"+case_name
 DirAccess.make_dir_recursive_absolute(directory)
 for i in frame_images.size(): frame_images[i].save_png(directory+"/frame_%03d.png" % i)
 frame_images=[]

func _candidate(choice: int, hit: bool, pixels: bool=true) -> void:
 await _choose(choice)
 if not hit:
  maze.player.position=Vector2(781,475)
  maze.camera.snap_to_target()
 await get_tree().process_frame
 var hp: float=actor().hp
 var hits: int=Run.snapshot(sm).combat.hits
 _begin_trace(("candidate_%d_%s_%d" % [[0,40,70][choice],"hit" if hit else "miss",render_view.size.x])+("" if pixels else "_light"),pixels)
 RenderingServer.force_draw(false)
 await _attack_click()
 if hit: _check(await _wait_until(func(): return actor().hp<hp,180),"真实左键命中："+case_name)
 _check(await _wait_until(func(): return Run.snapshot(sm).combat.action_left<0.000001,180),"动作正常结束："+case_name)
 await get_tree().create_timer(0.12).timeout
 _end_trace()
 var c: Dictionary=Run.snapshot(sm).combat
 _check(not samples.is_empty() and samples[0].hp==hp and samples[0].action_left<0.000001 and samples[0].player_hp==trial.baseline[Run.KEY].combat.hp,"连续证据从相同生命的出手前画面开始："+case_name)
 _check(c.hits==hits+(1 if hit else 0) and hp-actor().hp==(1.0 if hit else 0.0),"三档同伤害、打空不伤害："+case_name)
 var held: Array=samples.filter(func(row): return row.held_left>0.000001)
 _check(not held.is_empty() if hit and choice>0 else held.is_empty(),"停顿只出现在非零档实际命中："+case_name)
 if not held.is_empty():
  var first: Dictionary=held[0]
  _check(held.all(func(row): return row.position==first.position and is_equal_approx(row.action_left,first.action_left)),"画面采样期间实际动作和击退冻结："+case_name)
  _check(held.all(func(row): return row.flash and row.sweep_visible and is_equal_approx(row.sweep_angle,first.sweep_angle)),"白闪及认可弧光与停顿同步："+case_name)
 _check(not maze.capture_flow.skill_visual.sweep.visible and not maze.capture_flow.monsters[Rules.IDS[0]].body.material.get_shader_parameter("flash"),"动作与受击结束无残留："+case_name)

func _pause_and_move() -> void:
 await _choose(2)
 recording=true
 last_frame=0
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp<20.0,120),"暂停对照先真实命中")
 await _click(maze.map_ui.mini_button)
 var before: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 var clock: Dictionary=maze.capture_flow.axe_hitstop.state.duplicate(true)
 await get_tree().create_timer(0.18).timeout
 _check(maze.map_ui.expanded and Run.snapshot(sm).combat==before and maze.capture_flow.axe_hitstop.state==clock,"真实打开地图同时冻结剩余停顿与战斗")
 await _send_key(KEY_ESCAPE)
 _check(await _wait_until(func(): return Run.snapshot(sm).combat.action_left<before.action_left,90),"关闭地图继续剩余停顿后恢复动作")
 await _choose(2)
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp<20.0,120),"移动对照先真实命中")
 var point: Vector2=maze.player.position
 Input.action_press("ui_right")
 await get_tree().physics_frame
 await get_tree().physics_frame
 Input.action_release("ui_right")
 _check(maze.player.position.x>point.x,"局部停顿不锁玩家移动输入")
 recording=false

func _switch_during_hit() -> void:
 await _choose(2)
 recording=true
 await _attack_click()
 await _wait_until(func(): return actor().hp<20.0,120)
 await _send_key(KEY_F5)
 _check(trial.choice==0 and maze.capture_flow.axe_hitstop.state.left==0.0 and actor().hp==20.0,"命中中切档清理旧停顿并恢复相同生命")
 _check(Run.snapshot(sm).combat.action_left==0.0 and not maze.capture_flow.skill_visual.sweep.visible and not maze.player.input_locked,"切档后动作、弧光和输入无残留")
 recording=false

func _multiple_targets() -> void:
 var saved: Dictionary=trial.baseline.duplicate(true)
 var other: String="fenshui_silverfish_2"
 var run: Dictionary=trial.baseline[Run.KEY]
 run.monsters[other].status="alive"
 var a: Dictionary=run.combat.actors[other]
 a.position=[850.0,440.0]
 a.fish_origin=a.position.duplicate()
 a.fish_aim=[0.0,1.0]
 a.fish_hit=false
 Fish.phase(a,"recover",2.5)
 await _choose(2)
 _begin_trace("multi_target",false)
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp<20.0,120),"同挥砍真实命中多个目标")
 _check(Run.snapshot(sm).combat.actors[other].hp==19.0 and maze.capture_flow.axe_hitstop.state.ids.size()==2,"原周身规则仍命中背侧目标，停顿目标为两只")
 _check(maze.capture_flow.axe_hitstop.state.left<=0.070001,"两个目标的停顿不相加")
 await get_tree().create_timer(0.25).timeout
 _end_trace()
 trial.baseline=saved
 trial.reset()

func _consecutive() -> void:
 var saved: Dictionary=trial.baseline.duplicate(true)
 var a: Dictionary=trial.baseline[Run.KEY].combat.actors[Rules.IDS[0]]
 a.position=[900.0,470.0]
 a.fish_origin=a.position.duplicate()
 await _choose(2)
 _begin_trace("consecutive",false)
 var throws: int=Run.snapshot(sm).combat.throws
 for i in 3:
  _check(await _wait_until(func(): return Run.snapshot(sm).combat.cooldown<=0.000001 and Run.snapshot(sm).combat.action_left<=0.000001,240),"连续出手遵守原冷却："+str(i))
  await _attack_click()
  _check(await _wait_until(func(): return actor().hp<20.0-i,120),"连续旋斧每次真实命中："+str(i))
 _check(Run.snapshot(sm).combat.throws==throws+3,"连续三击没有额外出手或叠加触发")
 await get_tree().create_timer(0.2).timeout
 _end_trace()
 trial.baseline=saved

func _lethal() -> void:
 var saved: Dictionary=trial.baseline.duplicate(true)
 trial.baseline[Run.KEY].combat.actors[Rules.IDS[0]].hp=1.0
 await _choose(2)
 recording=true
 await _attack_click()
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible,240),"致命一击停顿后倒地和捕获对话正常，不锁死")
 _check(maze.capture_flow.axe_hitstop.state.left<=0.000001,"倒地等待期间剩余停顿能结束")
 recording=false
 trial.baseline=saved
