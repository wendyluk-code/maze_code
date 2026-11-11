extends "res://tools/tests/fenshui_trial_interaction.gd"
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
@export var capture_only:=false
var pictures: Array=[]
var runtime_environment: Dictionary={}
var combat_trace: Array=[]
var trace_signature: String=""

func _scene_check(_effects: Node) -> void:
 output=_arg("--output-dir=")
 DirAccess.make_dir_recursive_absolute(output)
 runtime_environment={"backend":DisplayServer.get_name(),"startup_no_focus":ProjectSettings.get_setting_with_override("display/window/size/no_focus"),"unfocusable":get_window().unfocusable,"has_focus":get_window().has_focus()}
 _check(runtime_environment.backend!="headless" and runtime_environment.startup_no_focus==true and get_window().unfocusable and not get_window().has_focus(),"测试窗口从启动起不可聚焦、不接管桌面输入")
 if failures:
  _finish_fish()
  return
 baseline=sm.data.duplicate(true)
 baseline[Run.KEY].combat.fs01_trial=false
 for id in baseline[Run.KEY].monsters:
  baseline[Run.KEY].monsters[id].status="alive" if id==Rules.IDS[0] else "skipped"
 baseline[Run.KEY].combat.actors[Rules.IDS[0]].position=[860.0,485.0]
 if capture_only:
  for case in ["success","failure","cancel"]: await _capture_path(case)
 else:
  for size in [Vector2i(1152,648),Vector2i(1280,720)]:
   get_window().size=size
   await _shore(size)
  await _role_attacks()
 _check(not invalid_seen,"正式鱼全程战斗状态合法")
 _check(not frame_ms.is_empty() and frame_ms.max()<250,"正式鱼真实交互保留250毫秒帧门槛",{"max_ms":frame_ms.max() if not frame_ms.is_empty() else -1})
 _finish_fish()

func actor() -> Dictionary:
 return Run.snapshot(sm).combat.actors[Rules.IDS[0]]

func _trace(edge: String) -> void:
 var c: Dictionary=Run.snapshot(sm).combat
 var a: Dictionary=c.actors[Rules.IDS[0]]
 combat_trace.append({"edge":edge,"section":section,"us":Time.get_ticks_usec(),"throws":c.throws,"hits":c.hits,"hp":a.hp,"phase":a.get("fish_phase","idle"),"left":a.get("fish_left",0),"fish":a.position,"hero":[maze.player.position.x,maze.player.position.y],"distance":Fish.vec(a.position).distance_to(maze.player.position),"cooldown":c.cooldown,"action_left":c.get("action_left",0.0),"pending":Run.snapshot(sm).pending})

func _reset(point: Vector2) -> void:
 await super._reset(Vector2(781,475) if capture_only else point)
 if capture_only:
  _check(await _wait_until(func(): return actor().get("fish_phase","")=="stranded",180),"捕获前由真实岸边站位诱鱼上岸")
  await _hold(KEY_LEFT,0.35)
  _trace("诱导上岸并真实侧移后")

func _attack_click() -> void:
 if capture_only:
  _check(await _wait_until(func(): return Run.snapshot(sm).combat.cooldown<=0.00001 or maze.capture_flow.dialog.visible,120),"真实普攻等待既有冷却")
  if maze.capture_flow.dialog.visible: return
 if capture_only: _trace("点击前")
 await super._attack_click()
 if capture_only: _trace("点击后")

func _process(delta: float) -> void:
 super._process(delta)
 if not capture_only or not recording or not is_instance_valid(maze): return
 var c: Dictionary=Run.snapshot(sm).combat
 var a: Dictionary=c.actors[Rules.IDS[0]]
 var signature:=JSON.stringify([c.throws,c.hits,a.hp,a.get("fish_phase","idle")])
 if signature!=trace_signature:
  trace_signature=signature
  _trace("投掷命中或阶段变化")

func _shore(size: Vector2i) -> void:
 section="formal_fish_"+str(size)
 await _reset(Vector2(781,475))
 recording=true
 last_frame=0
 var monster: Node=maze.capture_flow.monsters[Rules.IDS[0]]
 _check(await _wait_until(func(): return actor().get("fish_phase","")=="warning",120),"正式场景站在岸边诱导预警："+str(size))
 _check(monster.get("membrane") is Sprite2D and monster.membrane.visible,"水中预警有对应动作独立保护膜")
 _check(monster.action=="attack" and monster.membrane.texture.resource_path=="res://assets/effects/fenshui/protection_bubble.png" and not monster.membrane.region_enabled,"攻击时显示完整通用保护泡，不再裁身体外壳图集")
 await _map_pause("warning")
 var aim: Array=actor().fish_aim.duplicate()
 await _image("warning_%dx%d" % [size.x,size.y])
 await _hold(KEY_DOWN,0.18)
 _check(actor().fish_aim==aim,"真实横移后鱼仍保持原锁向")
 _check(await _wait_until(func(): return actor().fish_phase=="stranded",180),"真实冲刺上岸进入2.5秒搁浅")
 _check(Fish.allowed(Fish.vec(actor().position)) and Fish.dry(Fish.vec(actor().position)),"正式搁浅位置身体完整在合法岸上")
 _check(not monster.membrane.visible and monster.action=="stranded" and monster.frame_index() in [2,3],"活体睁眼侧身帧无膜，不循环闭眼死亡帧")
 var frame: int=monster.frame_index()
 await get_tree().create_timer(0.23).timeout
 _check(monster.frame_index()!=frame,"活体搁浅尾鳍持续换帧")
 await _hold(KEY_LEFT,0.35)
 await _image("stranded_%dx%d" % [size.x,size.y])
 await _map_pause("stranded")
 _check(await _wait_until(func(): return actor().fish_phase=="returning",240),"2.5秒结束后开始合法回水")
 await _map_pause("returning")
 await _image("returning_%dx%d" % [size.x,size.y])
 _check(await _wait_until(func(): return actor().fish_phase=="forming",180),"完整回水才开始凝膜")
 _check(not Fish.shielded(Run.snapshot(sm).combat,Rules.IDS[0]),"凝膜尚未完成时不提前减伤")
 await _map_pause("forming")
 await _image("forming_%dx%d" % [size.x,size.y])
 _check(await _wait_until(func(): return Fish.shielded(Run.snapshot(sm).combat,Rules.IDS[0]),180),"1秒凝膜结束后保护恢复")
 _check(monster.membrane.visible,"水中保护恢复时独立膜同步显示")
 var before_hp: float=actor().hp
 await _attack_click()
 _check(await _wait_until(func(): return actor().hp<before_hp,180),"内部鼠标真实攻击造成水中伤害")
 _check(before_hp-actor().hp<Run.snapshot(sm).combat.attack,"水膜下真实命中低于本趟普通攻击原伤害")
 await _image("water_hit_%dx%d" % [size.x,size.y])
 recording=false

func _map_pause(expected: String) -> void:
 var button: Control=maze.map_ui.mini_button
 var center:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=center
 get_viewport().push_input(motion)
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=center
  event.pressed=pressed
  get_viewport().push_input(event)
 _check(maze.map_ui.expanded and actor().fish_phase==expected,"真实点击地图冻结当前阶段："+expected)
 var before: Dictionary=actor()
 await get_tree().create_timer(0.3).timeout
 _check(actor()==before,"地图期间生命位置与剩余时间不推进："+expected)
 await _send_key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"内部Esc关闭地图恢复输入："+expected)

func _role_attacks() -> void:
 for pair in [[KEY_SPACE,0,"主角投射物"],[KEY_1,1,"芽芽投射物"],[KEY_2,2,"铁山范围攻击"]]:
  await _reset(Vector2(820,500))
  recording=true
  last_frame=0
  await _send_key(pair[0])
  _check(Run.snapshot(sm).combat.selected==pair[1],"真实按键选择伤害来源："+pair[2])
  _check(await _wait_until(func(): return Run.snapshot(sm).combat.cooldown<=0.00001 and actor().get("fish_phase","")=="warning" and actor().fish_left>0.4,480),"等待原攻击冷却及水中预警窗口："+pair[2])
  var before: float=actor().hp
  var throws: int=Run.snapshot(sm).combat.throws
  await _attack_click()
  _check(Run.snapshot(sm).combat.throws>throws,"真实鼠标释放招式："+pair[2])
  _check(await _wait_until(func(): return actor().hp<before,180),"招式实际命中水中保护鱼："+pair[2])
  recording=false

func _finish_fish() -> void:
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"frame_ms":frame_ms,"long_frames":long_frames,"pictures":pictures,"combat_trace":combat_trace,"environment":runtime_environment,"user_dir":OS.get_user_data_dir()},"	"))
 print("正式银鳞鱼场景：",checks,"项，失败",failures)
 get_tree().quit(1 if failures else 0)

func _image(name: String) -> void:
 await super._image(name)
 var monster: Node=maze.capture_flow.monsters[Rules.IDS[0]]
 pictures.append({"image":name,"phase":actor().get("fish_phase","idle"),"left":actor().get("fish_left",0),"position":actor().position,"hp":actor().hp,"action":monster.action,"frame":monster.frame_index(),"direction":monster.facing,"membrane_visible":monster.membrane.visible,"membrane_alpha":monster.membrane.modulate.a})

