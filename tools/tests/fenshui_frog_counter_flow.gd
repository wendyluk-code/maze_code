extends "res://tools/tests/ch2_entry_state.gd"
const Run=preload("res://scripts/maze/capture_run.gd")
const Boss=preload("res://data/maze/fenshui_boss.gd")
var viewport: SubViewport
var maze: Node2D
var output: String
var trace: Array=[]
var shot_damage:=0.0
var shot_serial:=-1
var entry_snapshot: Dictionary

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 output=_arg("--output-dir=")
 _check(_verify_isolation(),"正式巨蛙场景检查隔离用户存档")
 _completed()
 sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"done","line":0}
 sm.cancel_maze_entry()
 _check(Run.begin(sm,Roads.SPAWN).success,"建立原探索，不手填正式怪物列表")
 _check(Run.change_region(sm,"fenshui",Vector2(880,490)).success,"进入真实分水庭巨蛙附近")
 entry_snapshot=sm.data.duplicate(true)
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.handle_input_locally=false
 get_tree().root.add_child(viewport)
 maze=load("res://scenes/maze_fenshui.tscn").instantiate()
 viewport.add_child(maze)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.window_focused=true
 _check(maze.capture_flow.monsters.size()==7,"正常场景保留4鱼2鳗1蛙，不跳过其他魔物")
 var body: Sprite2D=maze.capture_flow.monsters[Boss.ID].body
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 var approved: bool=frog.action_sheets.values().has(body.texture) or frog.frog_motion.textures.has(body.texture)
 if body.texture is AtlasTexture: approved=approved or body.texture.atlas.resource_path.begins_with("res://assets/monsters/wind_frog/counter_candidate/")
 _check(approved,"正式节点消费本轮审定待机或完整方向动作图，而非独立工具覆盖",{"phase":frog.frog_state.get("frog_phase",""),"texture":body.texture.resource_path})
 if failures==0: await battle()
 _finish()

func state() -> Dictionary:
 return Run.snapshot(sm)

func actor() -> Dictionary:
 return state().combat.actors[Boss.ID]

func until_true(predicate: Callable, seconds: float=4.0) -> bool:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000.0)
 while not predicate.call() and Time.get_ticks_msec()<deadline:
  await get_tree().process_frame
 return predicate.call()

func record(label: String) -> void:
 var run:=state()
 trace.append({"label":label,"frog":run.combat.actors[Boss.ID].duplicate(true),"hero_hp":run.combat.hp,"hits":run.combat.hits,"throws":run.combat.throws,"elapsed":run.combat.elapsed})

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"正常地图进入完成，没有演示锁输入")
 maze.capture_flow.window_focused=true
 _check(not maze.capture_flow.combat_paused(),"正式战斗正常推进，不是预览暂停")
 await key(KEY_SPACE)
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==Boss.ID: break
 _check(maze.capture_flow.locked_target_id==Boss.ID,"反击前通过真实Tab锁定巨蛙，不让其他鱼鳗替代目标")
 _check(await until_true(func(): return actor().frog_phase=="airborne" and float(actor().frog_left)<=0.5 and float(actor().frog_left)>=0.3),"自然追击进入最高点附近0.20秒反击窗口")
 var airborne_node: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(airborne_node.membrane.visible and bubble_center(airborne_node).distance_to(airborne_node.membrane.global_position)<1.0,"正式七怪场景起跳保护泡贴合可见身体，而非留在地面")
 if failures: return
 var first: Dictionary=state()
 record("腾空待反击")
 # 窄窗口内不先消耗截图/切招的额外游戏帧；先实际出手，再等待结果。
 RenderingServer.force_draw(false)
 viewport.get_texture().get_image().save_png(output+"/airborne.png")
 await click()
 _check(await until_true(func(): return actor().frog_phase=="toppling",1.0),"真实左键锅铲命中使巨蛙失衡翻落")
 record("实际命中翻落")
 _check(state().combat.throws==first.combat.throws+1 and state().combat.hits==first.combat.hits+1,"真实出手与命中各一次，不直接写反击阶段")
 if failures: return
 await picture("toppling")
 _check(await until_true(func(): return actor().frog_phase=="exposed"),"正式战斗翻落后进入露腹")
 record("露腹")
 _check(not maze.capture_flow.monsters[Boss.ID].membrane.visible,"露腹时保护膜实际消失")
 _check(not maze.player.input_locked and maze.capture_flow.is_processing(),"露腹期间玩家与整图战斗未被工具暂停")
 await picture("exposed")
 var a: Dictionary=actor()
 var hp: float=a.hp
 var throws: int=state().combat.throws
 _check(await until_true(func(): return state().combat.cooldown<=0.00001),"等待原招式冷却而非改冷却值")
 await click()
 var shot_run: Dictionary=state()
 _check(shot_serial==throws+1 and shot_damage>0,"真实出手当刻记录原弹体输入，贴身命中不要求弹体跨帧留存")
 if shot_serial!=throws+1: return
 var raw: float=shot_damage
 _check(await until_true(func(): return state().combat.throws==throws+1 and actor().hp<hp,1.0),"露腹中原弹体实际命中")
 _check(is_equal_approx(float(actor().hp),hp-raw*2.0),"露腹实战生命减少为原弹体伤害2倍")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"通过原地图输入暂停战斗")
 var paused: Dictionary=actor().duplicate(true)
 await get_tree().create_timer(0.25).timeout
 _check(actor()==paused,"展开地图时阶段、位置、生命及剩时冻结")
 await key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"通过原地图输入恢复战斗")
 _check(await until_true(func(): return actor().frog_phase=="recovering"),"真实3秒弱点结束后连续起身")
 record("起身")
 await picture("recovering")
 _check(await until_true(func(): return actor().frog_phase in ["active","warning"]),"起身完成继续正常追击，不留在动画工具")
 _check(Run.valid(state()),"完整正式战斗循环仍可保存与捕获")
 var ordinary_advanced:=false
 for id in first.combat.actors:
  if str(id).begins_with("fenshui_") and id!=Boss.ID and state().combat.actors[id]!=first.combat.actors[id]: ordinary_advanced=true
 _check(ordinary_advanced,"同场鱼鳗在反击过程中继续推进，没有清场或整图暂停")
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=resolution
  await picture("normal_"+str(resolution.x))

func bubble_center(frog: Node2D) -> Vector2:
 if frog.facing==0: return frog.body.to_global(frog.body.get_rect().get_center())
 var image: Image=frog.body.texture.get_image()
 var left:=image.get_width()
 var top:=image.get_height()
 var right:=-1
 var bottom:=-1
 for y in image.get_height():
  for x in image.get_width():
   if image.get_pixel(x,y).a<0.5: continue
   left=mini(left,x)
   top=mini(top,y)
   right=maxi(right,x)
   bottom=maxi(bottom,y)
 return frog.body.to_global(frog.body.get_rect().position+Vector2(left+right+1,top+bottom+1)*0.5)

func picture(label: String) -> void:
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 viewport.get_texture().get_image().save_png(output+"/"+label+".png")

func key(code: Key) -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=code
  event.physical_keycode=code
  event.pressed=pressed
  viewport.push_input(event)
  await get_tree().process_frame

func click() -> void:
 await mouse(Vector2(600,400))

func mouse(point: Vector2) -> void:
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=point
  event.pressed=pressed
  viewport.push_input(event)
  if pressed:
   var run:=state()
   if not run.combat.shots.is_empty():
    shot_damage=float(run.combat.shots.back().damage)
    shot_serial=int(run.combat.throws)
  await get_tree().process_frame

func _finish() -> void:
 FileAccess.open(_arg("--report="),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"trace":trace},"  "))
 get_tree().quit(1 if failures else 0)
