extends "res://tools/previews/fenshui_borrow_lightning.gd"
## 正式场景自动交互；仅初始布置及随机数固定，攻击、捕获通过真实输入。
var baseline: Dictionary
var frame_ms: Array=[]
var recording:=false
var output: String
var last_frame:=0
var overlap_seen:=false
var invalid_seen:=false
var phase_seen: Dictionary={}
var section: String=""
var long_frames: Array=[]

func _process(_delta: float) -> void:
 if not recording or not is_instance_valid(maze): return
 maze.capture_flow.window_focused=true
 var now:=Time.get_ticks_usec()
 if last_frame>0:
  var duration: float=(now-last_frame)/1000.0
  frame_ms.append(duration)
  if duration>100.0: long_frames.append({"ms":duration,"section":section,"dialog":maze.capture_flow.dialog.visible,"attempt":maze.capture_flow.attempt.mode,"reward":maze.capture_flow.reward.visible})
 last_frame=now
 var run: Dictionary=Run.snapshot(sm)
 if not Run.valid(run): invalid_seen=true
 if run.is_empty(): return
 var eel: String=run.combat.actors[Rules.IDS[2]].get("fs_phase","")
 for id in Rules.IDS:
  var phase: String=run.combat.actors[id].get("fs_phase","")
  phase_seen[phase]=true
  if id.contains("silverfish") and phase in ["warning","rush"] and eel in ["warning","discharge"]: overlap_seen=true

func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 baseline=sm.data.duplicate(true)
 _check(get_window().unfocusable and not get_window().has_focus(),"测试窗口从启动起不可聚焦、不接管桌面输入")
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  get_window().size=size
  await _free_battle(size)
 await _skills_and_damage()
 await _capture_path("success")
 await _capture_path("failure")
 await _capture_path("cancel")
 await _capture_path("eel")
 await _legacy_replay()
 var report: Dictionary={"checks":checks,"failures":failures,"results":results,"frame_ms":frame_ms,"long_frames":long_frames,"overlap_seen":overlap_seen,"phase_seen":phase_seen,"user_dir":OS.get_user_data_dir()}
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"	"))
 print("FS01_INTERACTION ",checks,"项，失败",failures,"；最大帧毫秒",frame_ms.max() if frame_ms.size() else -1)
 get_tree().quit(1 if failures else 0)

func _reset(point: Vector2) -> void:
 recording=false
 maze.capture_flow.set_process(false)
 maze.capture_flow.dialog.hide()
 maze.capture_flow.attempt.close()
 maze.capture_flow.reward.hide()
 maze.capture_flow.busy=false
 maze.capture_flow.resolving=false
 maze.capture_flow.current=""
 maze.capture_flow.save_retry_delay=0.0
 maze._busy=false
 maze.player.input_locked=false
 maze.player.set_physics_process(true)
 sm.data=baseline.duplicate(true)
 sm.data[Run.KEY].combat.hero=Rules.pack(point)
 maze.player.position=point
 maze.camera.snap_to_target()
 maze.capture_flow.window_focused=true
 sm.save()
 maze.capture_flow.set_process(true)
 await get_tree().process_frame

func _hold(key: Key, seconds: float) -> void:
 var event:=InputEventKey.new()
 event.keycode=key
 event.physical_keycode=key
 event.pressed=true
 Input.parse_input_event(event)
 await get_tree().create_timer(seconds).timeout
 event=InputEventKey.new()
 event.keycode=key
 event.physical_keycode=key
 event.pressed=false
 Input.parse_input_event(event)
 await get_tree().process_frame

func _attack_click() -> void:
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.position=Vector2(900,450)
 event.pressed=true
 get_viewport().push_input(event)
 await get_tree().process_frame
 event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.position=Vector2(900,450)
 event.pressed=false
 get_viewport().push_input(event)
 await get_tree().process_frame

## 仅视口内事件，不调用warp_mouse、系统鼠标模式或原生输入注入。
func _click(control: Control) -> void:
 await get_tree().process_frame
 var center:=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=center
 get_viewport().push_input(motion)
 await get_tree().process_frame
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.button_mask=MOUSE_BUTTON_MASK_LEFT
 event.position=center
 event.pressed=true
 get_viewport().push_input(event)
 await get_tree().process_frame
 event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.position=center
 event.pressed=false
 get_viewport().push_input(event)
 await get_tree().process_frame

func _image(name: String) -> void:
 var was_recording:=recording
 recording=false
 # 最小化窗口可能不再自动触发绘制结束信号，显式绘制当前真实视口。
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 _check(get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")==OK,"实际画面证据："+name)
 last_frame=0
 recording=was_recording

func _free_battle(size: Vector2i) -> void:
 section="free_"+str(size)
 await _reset(Vector2(781,475))
 var initial: Dictionary=Run.snapshot(sm)
 var elapsed: float=initial.combat.elapsed
 var start: Vector2=maze.player.position
 recording=true
 last_frame=0
 await _hold(KEY_RIGHT,0.9)
 _check(maze.player.position.x>start.x+45 and Rules.wet(maze.player.position),"方向键从岸路进入浅水："+str(size))
 await get_tree().create_timer(0.4).timeout
 await _image("overlap_%dx%d" % [size.x,size.y])
 await _hold(KEY_DOWN,0.35)
 await _hold(KEY_LEFT,0.75)
 await _hold(KEY_UP,0.35)
 await get_tree().create_timer(0.5).timeout
 var after: Dictionary=Run.snapshot(sm)
 _check(after.combat.elapsed>elapsed+2.0 and Run.valid(after),"重叠攻击后战斗继续且状态合法："+str(size))
 _check(after.combat.hp>0,"完整移动躲避后仍可继续战斗："+str(size))
 _check(not maze.player.input_locked and not maze.capture_flow.busy,"技能结束输入恢复："+str(size))
 await _click(maze.map_ui.mini_button)
 _check(maze.map_ui.expanded,"战斗中真实点击打开地图："+str(size))
 var paused: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 await get_tree().create_timer(0.3).timeout
 _check(Run.snapshot(sm).combat==paused,"地图展开期间攻击阶段与生命暂停："+str(size))
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"内部Esc关闭地图恢复输入："+str(size))
 var saved: Dictionary=sm.data.duplicate(true)
 maze.capture_flow.set_process(false)
 var path: String=sm._active_save_path
 sm._active_save_path=""
 _check(not Run.combat_tick(sm,maze.player.position,0.5).success and sm.data==saved,"交互战斗后的保存失败回滚："+str(size))
 sm._active_save_path=path
 recording=false
 _check(overlap_seen and not invalid_seen,"实际重叠预警/攻击未使状态失效："+str(size))

func _skills_and_damage() -> void:
 section="skills_and_damage"
 await _reset(Vector2(900,470))
 recording=true
 last_frame=0
 var hp: float=Run.snapshot(sm).combat.hp
 await get_tree().create_timer(1.7).timeout
 var run: Dictionary=Run.snapshot(sm)
 _check(run.combat.hp<hp and run.combat.hp>0,"不躲避时真实技能命中扣血而非卡住")
 _check(run.combat.actors[Rules.IDS[1]].hp<20,"真实同场雷电同时伤鱼且状态合法")
 await _image("actual_damage")
 for pair in [[KEY_1,1],[KEY_2,2],[KEY_SPACE,0]]:
  await _send_key(pair[0])
  _check(Run.snapshot(sm).combat.selected==pair[1],"内部按键切换队伍招式："+str(pair[1]))
  await get_tree().create_timer(0.85).timeout
  var throws: float=Run.snapshot(sm).combat.throws
  await _attack_click()
  _check(Run.snapshot(sm).combat.throws>throws,"鼠标释放已选招式："+str(pair[1]))
 var shift:=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=true
 Input.parse_input_event(shift)
 await _hold(KEY_LEFT,0.25)
 _check(Run.snapshot(sm).combat.sprint<1.0,"内部Shift加方向输入触发冲刺消耗")
 shift=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=false
 Input.parse_input_event(shift)
 await get_tree().process_frame
 _check(not maze.player.sprint_held and Run.valid(Run.snapshot(sm)),"松开冲刺后输入与状态正常")
 recording=false

func _capture_path(case: String) -> void:
 section="capture_"+case
 var target: String=Rules.IDS[2] if case=="eel" else Rules.IDS[0]
 await _reset(Vector2(900,470) if case=="eel" else Vector2(860,485))
 maze.capture_flow.set_process(false)
 var run: Dictionary=Run.snapshot(sm)
 for id in Rules.IDS:
  if id!=target: run.monsters[id].status="skipped"
 run.monsters[target].capture_roll=0.0
 run.monsters[target].copy_roll=0.99
 run.combat.selected=0
 sm.data[Run.KEY]=run
 sm.save()
 maze.capture_flow.set_process(true)
 recording=true
 last_frame=0
 for i in 24:
  if maze.capture_flow.dialog.visible: break
  await _attack_click()
  await get_tree().create_timer(0.5).timeout
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible,180),"真实鼠标普攻击败进入捕获窗："+case)
 if not maze.capture_flow.dialog.visible:
  recording=false
  return
 _check(await _wait_until(func(): return not maze.capture_flow.dialog.flipping,120),"捕获窗翻转结束后允许点击："+case)
 _check(Run.snapshot(sm).combat.actors[target].hp==0,"普攻确实将目标生命归零："+case)
 await _image("capture_dialog_"+case)
 await _click(maze.capture_flow.dialog._confirm_button)
 _check(await _wait_until(func(): return maze.capture_flow.attempt.visible,120),"鼠标选择捕获打开操作窗："+case)
 var attempt: Control=maze.capture_flow.attempt
 if case=="cancel":
  var satiety: float=Run.snapshot(sm).satiety
  await _click(attempt.no_button)
  await get_tree().create_timer(0.3).timeout
  _check(not attempt.visible and not maze.player.input_locked and Run.snapshot(sm).satiety==satiety,"取消捕获不扣费且恢复输入")
 else:
  await _click(attempt.yes_button)
  _check(await _wait_until(func(): return attempt.mode=="suppress",240),"捕获抛绳束缚后进入镇压："+case)
  var end:=Time.get_ticks_msec()+12000
  while attempt.visible and Time.get_ticks_msec()<end:
   if case in ["success","eel"]: await _send_key(KEY_J)
   else: await get_tree().process_frame
  if case in ["success","eel"]:
   _check(maze.capture_flow.reward.visible,"真实连续按J达标并显示食材奖励")
   await _image("reward_"+case)
   if maze.capture_flow.reward.visible: await _click(maze.capture_flow.reward._confirm_button)
   _check(Run.snapshot(sm).monsters[target].status=="captured","成功捕获已保存："+case)
  else:
   _check(maze.capture_flow.dialog.visible and Run.snapshot(sm).monsters[target].status=="failed","不按J捕获失败且展示失败结果")
   _check(await _wait_until(func(): return not maze.capture_flow.dialog.flipping,120),"失败结果翻转结束后允许关闭")
   await _image("capture_failed")
   if maze.capture_flow.dialog.visible: await _click(maze.capture_flow.dialog._confirm_button)
  await get_tree().create_timer(0.5).timeout
  _check(not maze.player.input_locked and not maze.capture_flow.busy,"捕获结果关闭后恢复移动："+case)
  var bag: Dictionary=Run.snapshot(sm).bag.duplicate(true)
  _check(not Run.resolve(sm,target,true).success and Run.snapshot(sm).bag==bag,"重复结算被拒绝："+case)
 var before_move: Vector2=maze.player.position
 await _hold(KEY_LEFT,0.2)
 _check(maze.player.position.distance_to(before_move)>5.0,"捕获流程结束真实方向键仍可移动："+case)
 recording=false

func _legacy_replay() -> void:
 section="legacy_replay"
 await _reset(Vector2(781,475))
 maze.capture_flow.set_process(false)
 var source:=OS.get_environment("FS01_DIAG_SOURCE")
 if source.is_empty():
  _check(false,"必须提供用户卡住档的只读来源")
  return
 var bytes:=FileAccess.get_file_as_bytes(source)
 sm.data=JSON.parse_string(bytes.get_string_from_utf8())
 var before: Dictionary=Run.snapshot(sm)
 _check(Run.valid(before),"真实卡住档读取后合法，不清空生命和奖励")
 maze.player.position=Rules.vec(before.combat.hero)
 maze.camera.snap_to_target()
 var elapsed: float=before.combat.elapsed
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 recording=true
 last_frame=0
 await _hold(KEY_LEFT,0.25)
 await get_tree().create_timer(0.8).timeout
 var after: Dictionary=Run.snapshot(sm)
 _check(after.combat.elapsed>elapsed+0.5 and Run.valid(after),"真实卡住档恢复后能移动且战斗持续推进")
 _check(after.bag==before.bag,"恢复没有重复发奖励")
 _check(FileAccess.get_file_as_bytes(source)==bytes,"只读源体验档保持字节不变")
 await _image("legacy_resumed")
 recording=false
 _check(not invalid_seen,"整场输入及捕获流程未出现无效战斗状态")
 _check(frame_ms.max()<250.0,"真实交互全程未出现250毫秒以上长帧",{"max_ms":frame_ms.max()})
