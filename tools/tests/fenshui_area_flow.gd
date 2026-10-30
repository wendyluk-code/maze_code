extends "res://tools/tests/thunder_eel_shore_flow.gd"
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
const FISH="fenshui_silverfish_1"
var area_events: Array=[]
@export var drawing_case:=false

func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 environment={"backend":DisplayServer.get_name(),"startup_no_focus":ProjectSettings.get_setting_with_override("display/window/size/no_focus"),"unfocusable":get_window().unfocusable,"has_focus":get_window().has_focus()}
 _check(environment.backend!="headless" and environment.startup_no_focus==true and get_window().unfocusable and not get_window().has_focus(),"测试窗口从启动起不可聚焦、不接管桌面输入")
 baseline=sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial=false
 if not capture_case.is_empty():
  for id in baseline[Run.KEY].monsters: baseline[Run.KEY].monsters[id].status="alive" if id==EEL else "skipped"
  baseline[Run.KEY].combat.actors[EEL].position=[860.0,485.0]
  await _eel_capture(capture_case)
 else:
  var positions=[Vector2(920,440),Vector2(1040,440),Vector2(920,500),Vector2(1040,500),Vector2(980,440),Vector2(1100,440)]
  var rows: Array=Run.Catalog.Fenshui.all()
  for id in baseline[Run.KEY].monsters: baseline[Run.KEY].monsters[id].status="skipped"
  for i in rows.size():
   var id: String=rows[i].id
   _check(Eel.Water.water(positions[i]),"多鱼多鳗夹具先核对身体浅水合法："+id)
   baseline[Run.KEY].monsters[id].status="alive"
   var a: Dictionary=baseline[Run.KEY].combat.actors[id]
   a.position=Run.Combat.pack(positions[i])
   if i<4:
    a.fish_origin=a.position.duplicate()
    a.fish_aim=[0.0,1.0]
    a.fish_hit=false
    a.fish_phase="recover"
    a.fish_left=2.5
  if failures==0 and drawing_case:
   await _draw_samples()
  elif failures==0:
   for size in [Vector2i(1152,648),Vector2i(1280,720)]:
    get_window().size=size
    await _area_scene(size)
 _check(not invalid_seen,"正式范围借电全过程战斗状态合法")
 if not drawing_case: _check(not frame_ms.is_empty() and frame_ms.max()<250,"正式范围借电保留250毫秒交互帧门槛",{"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"frame_ms":frame_ms,"long_frames":long_frames,"pictures":pictures,"trace":trace,"area_events":area_events,"environment":environment,"user_dir":OS.get_user_data_dir()},"\t"))
 print("正式范围借电场景：",checks,"项，失败",failures)
 get_tree().quit(1 if failures else 0)

func _draw_samples() -> void:
 # 新绘制错误的最小受控复现，不替代完整多怪流程或其帧门槛。
 await _reset(Vector2(1040,490))
 maze.capture_flow.set_process(false)
 for left in [0.35,0.349,0.34,0.30,0.20,0.05,0.0]:
  var run: Dictionary=Run.snapshot(sm)
  for id in [EEL,"fenshui_thunder_eel_2"]:
   var a: Dictionary=run.combat.actors[id]
   a.eel_origin=a.position.duplicate()
   a.eel_path=[]
   a.eel_phase="discharge"
   a.eel_left=left
   a.mode="chase"
   a.windup=0.0
  run.combat.actors[FISH].electric_left=4.0-(0.35-left)
  sm.data[Run.KEY]=run
  _check(Run.valid(run),"释放绘制样例状态合法："+str(left))
  await get_tree().process_frame
  await get_tree().process_frame
  await _image("draw_release_"+str(left).replace(".","_"))

func _area_scene(size: Vector2i) -> void:
 section="范围借电"+str(size)
 await _reset(Vector2(1040,490))
 recording=true
 last_frame=0
 var monster: Node=maze.capture_flow.monsters[EEL]
 _check(await _wait_until(func(): return actor().get("eel_phase","")=="charging",120),"正式双鳗开始范围蓄电")
 var effects: Node=maze.get_node_or_null("FenshuiElectricEffects")
 _check(effects!=null,"正式分水庭安装共区域非指向性电纹，不依赖试玩入口")
 _check(await _wait_until(func(): return actor().get("eel_phase","")=="charging" and actor().eel_left<0.35,120),"持续真实蓄电至释放前")
 _check(monster.action=="attack" and monster.frame_index()<=1,"蓄电末段仍使用收身前两帧，不提前伸展")
 await _image("area_warning_%dx%d" % [size.x,size.y])
 _check(await _wait_until(func(): return actor().get("eel_phase","")=="discharge",120),"真实场景释放进入已结算余电")
 var run: Dictionary=Run.snapshot(sm)
 var affected: Array=[]
 for id in run.combat.actors:
  if id.begins_with("fenshui_silverfish_") and run.combat.actors[id].get("electric_left",0)>0: affected.append(id)
 _check(affected.size()>=2,"未先攻击即有多鱼受到一次环境电伤并破膜")
 _check(monster.frame_index()>=2,"释放伸展使用原主体后两帧")
 area_events.append({"resolution":str(size),"affected":affected,"serial":run.combat.get("electric_serial",0)})
 await _image("area_release_%dx%d" % [size.x,size.y])
 if size==Vector2i(1280,720):
  for i in 3:
   await get_tree().create_timer(0.075).timeout
   var live: Dictionary=Run.snapshot(sm)
   var live_monster: Node=maze.capture_flow.monsters[FISH]
   var pieces: Array=[]
   for piece in live_monster.membrane_pieces: pieces.append({"visible":piece.visible,"position":str(piece.position),"alpha":piece.modulate.a,"region":str(piece.region_rect)})
   area_events.append({"edge":"连续释放与碎膜","frame":i,"eel_phase":actor().eel_phase,"eel_frame":monster.frame_index(),"fish_left":live.combat.actors[FISH].get("electric_left",0),"pieces":pieces})
   await _image("area_sequence_"+str(i))
 # 此处只重现凝膜/破膜同时存在的显示输入，数值优先级另经公开战斗入口验证。
 maze.capture_flow.set_process(false)
 run=Run.snapshot(sm)
 run.combat.actors[FISH].fish_phase="forming"
 run.combat.actors[FISH].fish_left=0.5
 sm.data[Run.KEY]=run
 var fish_node: Node=maze.capture_flow.monsters[FISH]
 fish_node.sync_action(run.combat.actors[FISH],run.combat)
 _check(not fish_node.membrane.visible,"破膜期间即使正在凝膜也不显示膜面")
 maze.capture_flow.set_process(true)
 await _pause_area()
 for pair in [[KEY_1,1],[KEY_2,2],[KEY_SPACE,0]]:
  await _close_pending_captures()
  await _send_key(pair[0])
  _check(Run.snapshot(sm).combat.selected==pair[1],"多怪电纹同场内部按键切换招式："+str(pair[1]))
  _check(await _wait_until(func(): return Run.snapshot(sm).combat.cooldown<=0.00001 or maze.capture_flow.busy,180),"等当前招式真实冷却，不把固定0.85秒当冷却完成")
  await _close_pending_captures()
  var throws: float=Run.snapshot(sm).combat.throws
  await _attack_click()
  _check(Run.snapshot(sm).combat.throws>throws,"多怪电纹同场实际发射玩家招式："+str(pair[1]))
 await _close_pending_captures()
 _check(await _wait_until(func(): return Run.snapshot(sm).combat.shots.is_empty() and Run.snapshot(sm).combat.action_left<=0 or maze.capture_flow.busy,180),"等待在途招式结果，避免捕获弹窗中途取消冲刺")
 await _close_pending_captures()
 var before: Vector2=maze.player.position
 var shift:=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=true
 Input.parse_input_event(shift)
 await _hold(KEY_LEFT,0.25)
 shift=InputEventKey.new()
 shift.keycode=KEY_SHIFT
 shift.pressed=false
 Input.parse_input_event(shift)
 _check(maze.player.position.distance_to(before)>5 and Run.snapshot(sm).combat.sprint<1,"电纹与玩家技能重叠后仍可移动冲刺",{"before":str(before),"after":str(maze.player.position),"sprint":Run.snapshot(sm).combat.sprint,"paused":maze.capture_flow.combat_paused(),"dialog":maze.capture_flow.dialog.visible,"hp":Run.snapshot(sm).combat.hp})
 _check(not maze.player.input_locked and not maze.capture_flow.busy,"重叠场景输入无残留锁")
 await _image("area_overlap_%dx%d" % [size.x,size.y])
 recording=false

func _close_pending_captures() -> void:
 # 正常击败会主动打开捕获窗，不能把有意锁定输入误判为技能卡住。
 for i in 6:
  await get_tree().process_frame
  if not maze.capture_flow.dialog.visible: return
  _check(await _wait_until(func(): return not maze.capture_flow.dialog.flipping,120),"等待重叠技能击败后的真实捕获窗")
  await _click(maze.capture_flow.dialog._cancel_button)
  _check(await _wait_until(func(): return not maze.capture_flow.busy,120),"主动放弃当前捕获后恢复输入")

func _pause_area() -> void:
 await _click(maze.map_ui.mini_button)
 _check(maze.map_ui.expanded,"多怪借电中实际打开地图")
 var before: Dictionary=Run.snapshot(sm).combat
 await get_tree().create_timer(0.3).timeout
 _check(Run.snapshot(sm).combat==before,"地图冻结全部鱼鳗阶段与破膜剩时")
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"关闭地图恢复探索输入")
 maze.confirmation.open_confirmation("验证范围借电暂停","确认","继续探索")
 before=Run.snapshot(sm).combat
 await get_tree().create_timer(0.25).timeout
 _check(Run.snapshot(sm).combat==before,"确认弹窗冻结全部鱼鳗阶段与破膜剩时")
 await _click(maze.confirmation.cancel_button)
 _check(not maze.confirmation.visible and not maze.player.input_locked,"取消确认恢复探索输入")
