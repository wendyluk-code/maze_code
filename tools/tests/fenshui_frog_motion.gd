extends "res://tools/tests/ch2_entry_state.gd"
## 验证玩家可进入的新演示入口；未接入前必须先得到行为红灯。
const Run=preload("res://scripts/maze/capture_run.gd")
const Aim=preload("res://scripts/maze/auto_aim.gd")
const Frog=preload("res://data/maze/fenshui_boss.gd")
var entry: Node
var viewport: SubViewport
var output: String
var motion_trace: Array=[]

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"巨蛙动作检查使用隔离存档")
 _check(ResourceLoader.exists("res://tools/previews/fenshui_frog_motion.tscn"),"第4版巨蛙可通过游戏内演示入口加载")
 if failures:
  _finish_motion()
  return
 output=_arg("--output-dir=")
 # 仅控制隔离测试的时间边界，不改变实际入口或任何战斗阶段。
 get_tree().paused=true
 entry=load("res://tools/previews/fenshui_frog_motion.tscn").instantiate()
 get_tree().root.add_child(entry)
 for i in 90:
  await get_tree().process_frame
  if entry.controls!=null: break
 _check(entry.controls!=null,"真实入口完成正常分水庭及动作控件加载")
 if entry.controls==null:
  get_tree().paused=false
  _finish_motion()
  return
 var controls: Node=entry.controls
 var maze: Node2D=entry.maze
 controls.playing=false
 maze.capture_flow.window_focused=true
 _record_recovery(maze,"初始化完成、演示已暂停，解除隔离时间暂停前")
 get_tree().paused=false
 await _recovery_cases(maze,controls)
 if failures or OS.get_environment("FROG_RECOVERY_ONLY")=="1":
  _finish_motion()
  return
 _check(Run.snapshot(sm).combat.hero==[880.0,490.0] and maze.player.position.distance_to(Vector2(880,490))<0.1,"演示入口显示与战斗保存站位一致，恢复时不跳回区域入口")
 if failures:
  _finish_motion()
  return
 _check(maze.region_id=="fenshui" and not Run.snapshot(sm).combat.fs01_trial,"演示在真实正常分水庭而非旧引鱼借电玩法")
 _check(controls.active and not maze.capture_flow.is_processing(),"演示覆盖真实巨蛙身体并暂停战斗推进")
 _check(is_equal_approx(maze.capture_flow.axe_hitstop.state.duration,0.07) and is_equal_approx(maze.capture_flow.axe_hitstop.state.ranged_duration,0.05),"正常50／70毫秒配置保留")
 var before: Dictionary=sm.data.duplicate(true)
 var old_texture: Texture2D=controls.saved.texture
 var old_transform: Transform2D=controls.saved.transform
 var old_offset: Vector2=controls.saved.offset
 var old_region: Rect2=controls.saved.region_rect
 var old_width: float=148.0/192.0*float(controls.frog.config.width)
 _check(controls.motion.textures.size()==18,"18个不同姿态实际加载，包含三张新过渡")
 _check(controls.motion.textures[12].atlas.get_width()==2172 and controls.motion.textures[15].region.position.x>330,"采用补帧并跳过原第13格")
 _check(controls.motion.textures[13].region.position.x>=724,"侧卧触地实际取自补帧图第2格，不重复第1格")
 _check(controls.motion.textures[14].region.position.x>=1448,"侧卧撑起实际取自补帧图第3格，不重复第1格")
 var belly_time:=0.0
 for index in controls.motion.SEQUENCE:
  if index in [8,9,10,11]: belly_time+=controls.motion.duration(index)
 _check(is_equal_approx(belly_time,3.0),"露腹四姿态循环共3秒，不用一张静帧拉长")
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 maze.reparent(viewport)
 maze.capture_flow.window_focused=true
 for layer in maze.get_children():
  if layer is CanvasLayer and layer.layer==100:
   for hint in layer.get_children():
    if hint.has_method("dismiss"): hint.dismiss()
 var body: Sprite2D=controls.frog.body
 for i in 18:
  if i>0: await _key(KEY_F10)
  _check(not body.flip_h and not body.flip_v and is_zero_approx(body.rotation),"姿态不以镜像或旋转冒充其他方向："+str(i+1))
  var expected_scale: float=old_width/245.0*(313.5/724.0 if i in [12,13,14] else 1.0)
  _check(is_equal_approx(body.scale.x,expected_scale) and body.scale.x==body.scale.y,"跨图统一等比缩放："+str(i+1))
  var bounds: Rect2i=controls.motion.BOUNDS[i]
  var region: Rect2i=controls.motion.regions[i]
  var foot: float=(body.offset.y+bounds.end.y-region.position.y)*body.scale.y
  _check(absf(foot)<0.001,"真实主体接地点贴合地图锚点："+str(i+1))
  _check(controls.pose==i,"真实逐帧输入选中姿态："+str(i+1))
  await _picture("pose_%02d_1280" % (i+1))
 _check(sm.data==before,"18姿态展示不改探索、生命、伤害、奖励或存档状态")
 await _click_local(controls.play_button)
 var seen: Dictionary={}
 var stamp:=Time.get_ticks_usec()
 var previous: int=-1
 while Time.get_ticks_usec()-stamp<6000000:
  if controls.pose!=previous:
   motion_trace.append({"pose":controls.pose,"us":Time.get_ticks_usec()-stamp})
   seen[controls.pose]=true
   previous=controls.pose
  await get_tree().process_frame
 _check(seen.size()==18 and motion_trace.size()>18,"真实时间连续播放完整18姿态并进入下一轮")
 _check(sm.data==before,"完整连续演示仍不推进战斗或写入新阶段")
 controls.play()
 await _key(KEY_F8)
 var paused_pose: int=controls.pose
 var paused_remaining: float=controls.remaining
 await get_tree().create_timer(0.2).timeout
 _check(not controls.playing and controls.pose==paused_pose and controls.remaining==paused_remaining,"真实F8暂停姿态和剩余时间")
 await _key(KEY_F10)
 _check(controls.pose==(paused_pose+1)%18 and not controls.playing,"真实逐姿态前进并保持暂停")
 await _key(KEY_F8)
 _check(controls.playing,"真实F8继续播放")
 await get_tree().create_timer(0.25).timeout
 _check(controls.pose!=paused_pose+1,"继续后按真实时间换姿态")
 controls.playing=false
 controls.pose=14
 controls.motion.draw_pose(body,14)
 viewport.size=Vector2i(1152,648)
 await _picture("transition_1152")
 _check(controls.resume_button.get_global_rect().end.x<1152 and controls.hint.is_visible_in_tree(),"小分辨率提示与恢复按钮可达")
 _key_now(KEY_F9)
 _check(not controls.active and not maze.player.input_locked and maze.capture_flow.is_processing(),"真实F9恢复原战斗和输入")
 _check(body.texture==old_texture and body.transform==old_transform and body.offset==old_offset and body.region_rect==old_region,"退出演示当刻恢复原图集、取景、脚底与变换",{"transform":str(body.transform),"expected":str(old_transform)})
 _check(Run.valid(Run.snapshot(sm)),"返回原战斗后探索状态仍合法")
 var restored: Dictionary=Run.snapshot(sm)
 _record_recovery(maze,"F9后立即，尚未普通推进")
 _check(sm.data==before,"F9退出当刻保留原探索和战斗状态")
 _check(restored.combat.actors[Frog.ID].frog_phase==before[Run.KEY].combat.actors[Frog.ID].frog_phase,"恢复演示前真实阶段，不强制已激活巨蛙退回待机")
 var start: Vector2=maze.player.position
 Input.action_press("ui_left")
 await get_tree().physics_frame
 await get_tree().physics_frame
 Input.action_release("ui_left")
 _check(maze.player.position.x<start.x,"退出演示后真实内部方向输入可移动")
 await _click_local(maze.map_ui.mini_button)
 var held: Dictionary=Run.snapshot(sm).combat.duplicate(true)
 await get_tree().create_timer(0.15).timeout
 _check(maze.map_ui.expanded and Run.snapshot(sm).combat==held,"恢复原战斗后原地图窗口仍暂停战斗")
 _check(not controls.tool_layer.visible,"原地图展开时不覆盖演示工具")
 await _key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and not maze.player.input_locked,"原地图Esc关闭后恢复输入")
 # 原规则需普通战斗推进才刷新剧情解锁并唤醒；不写阶段或重置站位。
 _record_recovery(maze,"原地图关闭后，等待自然激活前")
 var until:=Time.get_ticks_msec()+3000
 var first_tick:=false
 while (float(Run.snapshot(sm).combat.elapsed)<=float(restored.combat.elapsed) or Run.snapshot(sm).combat.actors[Frog.ID].frog_phase in ["dormant","emerging"]) and Time.get_ticks_msec()<until:
  await get_tree().process_frame
  if not first_tick and float(Run.snapshot(sm).combat.elapsed)>float(restored.combat.elapsed):
   first_tick=true
   _record_recovery(maze,"等待期间首个普通推进")
 var original: Dictionary=Run.snapshot(sm)
 _record_recovery(maze,"有界自然激活等待结束")
 var active: bool=original.combat.actors[Frog.ID].frog_phase not in ["dormant","emerging"]
 _check(active and float(original.combat.elapsed)>float(restored.combat.elapsed),"原战斗在3秒内正常推进并自然激活巨蛙")
 _check(Aim.target(original,maze.player.position)==Frog.ID,"实际恢复后的同一目标可被自动瞄准，不在攻击前重置站位")
 if not active or Aim.target(original,maze.player.position)!=Frog.ID:
  _finish_motion()
  return
 var hp: float=original.combat.actors[Frog.ID].hp
 var throws: int=int(original.combat.throws)
 var hits: int=int(original.combat.hits)
 for pressed in [true,false]:
  var click:=InputEventMouseButton.new()
  click.button_index=MOUSE_BUTTON_LEFT
  click.position=controls.frog.get_global_transform_with_canvas().origin+Vector2(0,-20)
  click.pressed=pressed
  viewport.push_input(click)
 var fired: Dictionary=Run.snapshot(sm)
 _record_recovery(maze,"原锅铲出手当刻")
 _check(int(fired.combat.throws)==throws+1 and fired.combat.shots.size()==1,"恢复后只通过真实鼠标输入发射一枚原锅铲")
 var damage: float=float(fired.combat.shots[0].damage) if fired.combat.shots.size()==1 else -1.0
 until=Time.get_ticks_msec()+1200
 while Run.snapshot(sm).combat.actors[Frog.ID].hp==hp and Time.get_ticks_msec()<until: await get_tree().process_frame
 var after: Dictionary=Run.snapshot(sm)
 _record_recovery(maze,"首次实际伤害或1.2秒等待到期")
 _check(float(after.combat.actors[Frog.ID].hp)<hp,"恢复原战斗后真实锅铲命中巨蛙")
 _check(is_equal_approx(damage,3.0) and is_equal_approx(hp-float(after.combat.actors[Frog.ID].hp),1.0),"原3点锅铲在正式水膜保护下扣最低1点，仍仅命中一次",{"before":hp,"after":after.combat.actors[Frog.ID].hp,"projectile_damage":damage})
 _check(int(after.combat.throws)==throws+1 and int(after.combat.hits)==hits+1,"实际出手与命中各只增加一次")
 _check(not controls.active and (body.texture is AtlasTexture or body.texture in [controls.frog.action_sheets.idle,controls.frog.action_sheets.attack]),"退出演示后正式战斗自行消费本轮完整方向链或审定待机／吐水图")
 maze.capture_flow.set_process(false)
 var run: Dictionary=Run.snapshot(sm)
 run.combat.actors.fenshui_wind_frog_1.hp=0
 sm.data[Run.KEY]=run
 controls.frog.action_time=0.72
 maze.capture_flow.set_process(true)
 _check(await _wait_until(func(): return maze.capture_flow.dialog.visible,180),"原巨蛙倒地后仍进入真实捕获窗")
 _check(await _wait_until(func(): return not maze.capture_flow.dialog.flipping,120),"捕获翻转完成后可操作")
 _check(not controls.tool_layer.visible,"原捕获窗口显示时隐藏演示工具")
 var modal_texture: Texture2D=body.texture
 _key_now(KEY_F10)
 _check(not controls.active and body.texture==modal_texture,"捕获窗口中F10不改动背后的巨蛙显示")
 await _picture("original_capture_dialog")
 await _click_local(maze.capture_flow.dialog._confirm_button)
 _check(await _wait_until(func(): return maze.capture_flow.attempt.visible,120),"真实点击捕获仍打开原操作窗")
 await _click_local(maze.capture_flow.attempt.no_button)
 await get_tree().create_timer(0.3).timeout
 _check(not maze.capture_flow.attempt.visible and not maze.player.input_locked and not maze.capture_flow.busy,"取消原捕获恢复移动，不残留演示锁")
 maze.capture_flow.set_process(false)
 _finish_motion()

func _recovery_cases(maze: Node2D, controls: Node) -> void:
 for pending in [true,false]:
  var baseline: Dictionary=Run.snapshot(sm)
  var phase: String=baseline.combat.actors[Frog.ID].frog_phase
  _check((phase in ["dormant","emerging"])==pending,"真实覆盖"+("未激活" if pending else "已激活")+"输入，不跳过分支")
  var vp: Viewport=maze.get_viewport()
  for pressed in [true,false]:
   var event:=InputEventKey.new()
   event.keycode=KEY_F9
   event.pressed=pressed
   vp.push_input(event)
  _record_recovery(maze,"双输入F9立即："+phase)
  _check(not controls.active and Run.snapshot(sm)==baseline,"F9保留"+phase+"输入的原状态")
  if pending: _check(Aim.target(Run.snapshot(sm),maze.player.position).is_empty(),"真实未激活输入独立验证不可选中")
  var until:=Time.get_ticks_msec()+3000
  while (float(Run.snapshot(sm).combat.elapsed)<=float(baseline.combat.elapsed) or Run.snapshot(sm).combat.actors[Frog.ID].frog_phase in ["dormant","emerging"]) and Time.get_ticks_msec()<until:
   await get_tree().process_frame
  _record_recovery(maze,"双输入恢复后实际推进："+phase)
  var advanced: Dictionary=Run.snapshot(sm)
  _check(float(advanced.combat.elapsed)>float(baseline.combat.elapsed) and advanced.combat.actors[Frog.ID].frog_phase not in ["dormant","emerging"],phase+"恢复后至少一次原推进并处于活动阶段")
  _check(Aim.target(advanced,maze.player.position)==Frog.ID,phase+"恢复推进后可自动瞄准同一巨蛙")
  for pressed in [true,false]:
   var event:=InputEventKey.new()
   event.keycode=KEY_F7
   event.pressed=pressed
   vp.push_input(event)
  controls.playing=false

func _record_recovery(maze: Node2D, point: String) -> void:
 var run: Dictionary=Run.snapshot(sm)
 var terrain: RefCounted=sm.maze_terrain("fenshui")
 motion_trace.append({"point":point,"hero":run.combat.hero.duplicate(),"frog":run.combat.actors[Frog.ID].duplicate(true),"auto_target":Aim.target(run,maze.player.position),"elapsed":run.combat.elapsed,"story":sm.yufeng_salia_state(),"unlocked":run.combat.get("frog_unlocked",false),"walkable":terrain.is_walkable(maze.player.position),"terrain_multiplier":terrain.terrain_multiplier(maze.player.position),"paused":maze.capture_flow.combat_paused(),"flow_processing":maze.capture_flow.is_processing(),"locked":maze.player.input_locked,"throws":run.combat.throws,"hits":run.combat.hits})

func _picture(name: String) -> void:
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 viewport.get_texture().get_image().save_png(output+"/"+name+".png")

func _key_now(key: Key) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=key
  event.physical_keycode=key
  event.pressed=pressed
  viewport.push_input(event)

func _click_local(control: Control) -> void:
 await _mouse_local(control.get_global_rect().get_center())

func _mouse_local(point: Vector2) -> void:
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=point
  event.pressed=pressed
  viewport.push_input(event)
  await get_tree().process_frame

func _key(key: Key) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=key
  event.physical_keycode=key
  event.pressed=pressed
  viewport.push_input(event)
  await get_tree().process_frame

func _finish_motion() -> void:
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"motion_trace":motion_trace},"  "))
 get_tree().quit(1 if failures else 0)
