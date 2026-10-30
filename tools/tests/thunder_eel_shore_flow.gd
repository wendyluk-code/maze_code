extends "res://tools/tests/fenshui_trial_interaction.gd"
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const EEL="fenshui_thunder_eel_1"
@export var capture_case:=""
var pictures: Array=[]
var trace: Array=[]
var environment: Dictionary={}
var trace_signature:=""

func _process(delta: float) -> void:
 super._process(delta)
 if not recording or not is_instance_valid(maze): return
 var c: Dictionary=Run.snapshot(sm).combat
 var a: Dictionary=c.actors[EEL]
 var signature:=JSON.stringify([c.throws,c.hits,a.hp,a.get("eel_phase","idle")])
 if signature!=trace_signature:
  trace_signature=signature
  trace.append({"edge":section,"us":Time.get_ticks_usec(),"throws":c.throws,"hits":c.hits,"hp":a.hp,"phase":a.get("eel_phase","idle"),"left":a.get("eel_left",0),"position":a.position,"hero":c.hero,"cooldown":c.cooldown})

func actor() -> Dictionary:
 return Run.snapshot(sm).combat.actors[EEL]

func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 environment={"backend":DisplayServer.get_name(),"startup_no_focus":ProjectSettings.get_setting_with_override("display/window/size/no_focus"),"unfocusable":get_window().unfocusable,"has_focus":get_window().has_focus()}
 _check(environment.backend!="headless" and environment.startup_no_focus==true and get_window().unfocusable and not get_window().has_focus(),"测试窗口从启动起不可聚焦、不接管桌面输入")
 baseline=sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial=false
 for id in baseline[Run.KEY].monsters: baseline[Run.KEY].monsters[id].status="alive" if id==EEL else "skipped"
 baseline[Run.KEY].combat.actors[EEL].position=[860.0,485.0]
 if capture_case.is_empty():
  for size in [Vector2i(1152,648),Vector2i(1280,720)]:
   get_window().size=size
   await _shore(size)
 else: await _eel_capture(capture_case)
 _check(not invalid_seen,"正式雷鳗全过程战斗状态可保存")
 _check(not frame_ms.is_empty() and frame_ms.max()<250,"正式雷鳗保留250毫秒交互帧门槛",{"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"frame_ms":frame_ms,"long_frames":long_frames,"pictures":pictures,"trace":trace,"environment":environment,"user_dir":OS.get_user_data_dir()},"	"))
 print("正式雷鳗：",checks,"项，失败",failures)
 get_tree().quit(1 if failures else 0)

func _shore(size: Vector2i) -> void:
 section="雷鳗岸水"+str(size)
 await _reset(Vector2(781,475))
 recording=true
 last_frame=0
 var monster: Node=maze.capture_flow.monsters[EEL]
 _check(await _wait_until(func(): return actor().get("eel_phase","")=="stranded",180),"真实岸边站位诱导雷鳗完整上岸："+str(size))
 _check(Eel.Ground.dry(Eel.vec(actor().position)) and Eel.Ground.allowed(Eel.vec(actor().position)),"上岸身体完整合法且不穿岛或保护区")
 _check(monster.get("membrane") is Sprite2D,"正式雷鳗创建独立透明膜层")
 if not monster.get("membrane") is Sprite2D:
  recording=false
  return
 _check(not monster.membrane.visible and monster.action=="shore","岸停无膜且使用可辨的岸行动作")
 await _hold(KEY_LEFT,0.3)
 await _image("shore_%dx%d" % [size.x,size.y])
 if size==Vector2i(1280,720): await _shore_preview(monster)
 var frame: int=monster.frame_index()
 await get_tree().create_timer(0.4).timeout
 _check(monster.frame_index()!=frame,"岸停仍有连续活体蜿蜒动作")
 await _pause_stage("stranded")
 await _hold(KEY_LEFT,0.3)
 _check(await _wait_until(func(): return actor().eel_phase=="returning",240),"岸停2.5秒后原路回水")
 await _pause_stage("returning")
 await _image("returning_%dx%d" % [size.x,size.y])
 _check(await _wait_until(func(): return actor().eel_phase=="forming",240),"完整回水进入1秒凝膜")
 _check(monster.membrane.visible and not Eel.shielded(Run.snapshot(sm).combat,EEL),"凝膜可见但完成前不提前减伤")
 await _pause_stage("forming")
 await _image("forming_%dx%d" % [size.x,size.y])
 _check(await _wait_until(func(): return Eel.shielded(Run.snapshot(sm).combat,EEL),180),"1秒后水中保护恢复")
 _check(monster.membrane.visible and monster.membrane.region_rect==monster.body.region_rect and monster.membrane.offset==monster.body.offset and monster.membrane.scale==monster.body.scale,"主体与膜共享帧朝向锚点缩放")
 _check(monster.membrane.modulate.a==1.0,"有效水膜不重复乘已烘焙透明度")
 await _image("water_%dx%d" % [size.x,size.y])
 recording=false

func _pause_stage(expected: String) -> void:
 await _click(maze.map_ui.mini_button)
 _check(maze.map_ui.expanded and actor().eel_phase==expected,"真实地图冻结阶段："+expected)
 var before: Dictionary=actor()
 await get_tree().create_timer(0.3).timeout
 _check(actor()==before,"地图冻结生命位置与剩余时间："+expected)
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"关闭地图恢复输入："+expected)
 maze.confirmation.open_confirmation("受控验证阶段暂停","确认","继续探索")
 before=actor()
 await get_tree().create_timer(0.25).timeout
 _check(maze.capture_flow.combat_paused() and actor()==before,"既有二次确认弹窗冻结活体雷鳗阶段："+expected)
 await _click(maze.confirmation.cancel_button)
 _check(not maze.confirmation.visible and not maze.player.input_locked,"关闭二次确认恢复输入："+expected)

func _eel_capture(case: String) -> void:
 section="雷鳗捕获"+case
 await _reset(Vector2(781,475))
 recording=true
 last_frame=0
 _check(await _wait_until(func(): return actor().get("eel_phase","")=="stranded",180),"捕获前通过真实岸线引鳗上岸")
 await _hold(KEY_LEFT,0.35)
 maze.capture_flow.set_process(false)
 var run: Dictionary=Run.snapshot(sm)
 run.monsters[EEL].capture_roll=0.0
 run.monsters[EEL].copy_roll=0.99
 run.combat.selected=0
 sm.data[Run.KEY]=run
 sm.save()
 maze.capture_flow.set_process(true)
 for i in 24:
  if maze.capture_flow.dialog.visible: break
  _check(await _wait_until(func(): return Run.snapshot(sm).combat.cooldown<=0.00001 or maze.capture_flow.dialog.visible,120),"等待原普攻冷却："+str(i))
  if maze.capture_flow.dialog.visible: break
  var throws: int=Run.snapshot(sm).combat.throws
  var hits: int=Run.snapshot(sm).combat.hits
  await _attack_click()
  _check(Run.snapshot(sm).combat.throws>throws,"内部普攻真实发射而非把点击当投掷："+str(i))
  _check(await _wait_until(func(): return Run.snapshot(sm).combat.hits>hits or maze.capture_flow.dialog.visible,120),"普攻真实命中或进入捕获："+str(i))
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible,180),"真实普攻击败30生命雷鳗进入捕获："+case)
 if not maze.capture_flow.dialog.visible:
  recording=false
  return
 _check(actor().hp==0,"雷鳗生命真实归零")
 _check(await _wait_until(func(): return not maze.capture_flow.dialog.flipping,120),"等待捕获窗翻转结束")
 await _image("capture_dialog_"+case)
 var stopped: Dictionary=actor()
 await get_tree().create_timer(0.3).timeout
 _check(actor()==stopped,"捕获弹窗期间阶段生命位置冻结")
 await _click(maze.capture_flow.dialog._confirm_button)
 _check(await _wait_until(func(): return maze.capture_flow.attempt.visible,120),"真实点击打开雷鳗捕获操作窗")
 var attempt: Control=maze.capture_flow.attempt
 if case=="cancel":
  var satiety: float=Run.snapshot(sm).satiety
  await _click(attempt.no_button)
  await get_tree().create_timer(0.3).timeout
  _check(not attempt.visible and not maze.player.input_locked and Run.snapshot(sm).satiety==satiety,"取消雷鳗捕获不扣费并恢复输入")
 else:
  await _click(attempt.yes_button)
  _check(await _wait_until(func(): return attempt.mode=="suppress",240),"付费抛绳后进入镇压")
  var end:=Time.get_ticks_msec()+12000
  while attempt.visible and Time.get_ticks_msec()<end:
   if case=="success": await _send_key(KEY_J)
   else: await get_tree().process_frame
  if case=="success":
   _check(maze.capture_flow.reward.visible,"真实按J达标显示鳗腹奖励")
   await _image("reward_"+case)
   if maze.capture_flow.reward.visible: await _click(maze.capture_flow.reward._confirm_button)
   _check(Run.snapshot(sm).monsters[EEL].status=="captured" and Run.snapshot(sm).bag.get("thunder_eel_belly",0)==1,"捕获成功且鳗腹只入袋一次")
  else:
   _check(maze.capture_flow.dialog.visible and Run.snapshot(sm).monsters[EEL].status=="failed","不按J导致真实捕获失败")
   _check(await _wait_until(func(): return not maze.capture_flow.dialog.flipping,120),"失败结果翻转完成")
   await _image("capture_failed")
   if maze.capture_flow.dialog.visible: await _click(maze.capture_flow.dialog._confirm_button)
  await get_tree().create_timer(0.5).timeout
  _check(not maze.player.input_locked and not maze.capture_flow.busy,"关闭捕获结果恢复输入")
  var bag: Dictionary=Run.snapshot(sm).bag.duplicate(true)
  _check(not Run.resolve(sm,EEL,true).success and Run.snapshot(sm).bag==bag,"雷鳗拒绝重复结算")
 var before: Vector2=maze.player.position
 await _hold(KEY_LEFT,0.2)
 _check(maze.player.position.distance_to(before)>5,"捕获结束真实方向键可继续移动")
 recording=false

func _shore_preview(monster: Node) -> void:
 var flow: Node=maze.capture_flow
 flow.set_process(false)
 monster.set_process(false)
 var direction: int=monster.facing
 var time: float=monster.action_time
 var board:=Image.create(880,720,false,Image.FORMAT_RGBA8)
 var contacts: Array=[]
 for facing in 4:
  monster._set_direction(facing)
  for frame in 4:
   monster.action_time=frame*0.32+0.01
   monster._draw_frame(frame)
   await RenderingServer.frame_post_draw
   var screen: Vector2=monster.get_global_transform_with_canvas().origin
   var capture:=get_viewport().get_texture().get_image()
   capture.convert(Image.FORMAT_RGBA8)
   board.blit_rect(capture,Rect2i(Vector2i(screen)-Vector2i(110,130),Vector2i(220,180)),Vector2i(frame*220,facing*180))
   contacts.append({"direction":facing,"frame":frame,"ground_y":(monster.body.offset.y+monster.eel_contacts[facing*4+frame])*monster.body.scale.y})
 _check(board.save_png(output+"/shore-four-direction-preview.png")==OK,"四向各四帧岸行候选预览，不冒充四条真实追击路径")
 var grounded:=true
 for contact in contacts:
  if absf(contact.ground_y)>1.0: grounded=false
 _check(grounded and monster.wake_rings.is_empty(),"四向16帧脚底贴地且不画水纹")
 trace.append({"edge":"受控四向岸行预览","contacts":contacts})
 monster._set_direction(direction)
 monster.action_time=time
 monster._draw_frame(monster.frame_index())
 monster.set_process(true)
 flow.set_process(true)

func _image(name: String) -> void:
 await super._image(name)
 var monster: Node=maze.capture_flow.monsters[EEL]
 pictures.append({"image":name,"phase":actor().get("eel_phase","idle"),"left":actor().get("eel_left",0),"position":actor().position,"hp":actor().hp,"action":monster.action,"frame":monster.frame_index(),"direction":monster.facing,"membrane_visible":monster.membrane.visible,"membrane_alpha":monster.membrane.modulate.a})
