extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const Catalog=preload("res://data/maze/capture_catalog.gd")
const Aim=preload("res://scripts/maze/auto_aim.gd")
const FISH="fenshui_silverfish_1"
var baseline: Dictionary

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实地图完成入场")
 maze.capture_flow.window_focused=true
 baseline=entry_snapshot.duplicate(true)
 var selected: int=state().combat.selected
 var order:=candidate_order()
 var nearest:=""
 var distance:=INF
 for id in order:
  var d: float=maze.player.position.distance_squared_to(Run.Combat.vec(state().combat.actors[id].position))
  if d<distance:
   nearest=id
   distance=d
 await key(KEY_TAB)
 _check(state().combat.selected==selected,"分水庭普通战斗Tab用于锁定，不再切换招式")
 _check(not nearest.is_empty() and maze.capture_flow.locked_target_id==nearest,"第一次Tab锁定视野中最近的有效魔物",{"expected":nearest,"actual":maze.capture_flow.locked_target_id})
 var captions: Array=[]
 for label in maze.capture_flow.controls_hint.find_children("*","Label",true,false): captions.append(label.text)
 _check(captions.has("锁定/切换") and captions.has("Q") and captions.has("解除锁定"),"锁定切换与Q解除锁定常驻显示，不依赖悬停")
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  await get_tree().process_frame
  await get_tree().process_frame
  check_hint_layout(true,str(size.x))
  await picture("controls_hint_"+str(size.x))
 if failures: return
 order=candidate_order()
 _check(order.size()>=2,"真实七怪视口有至少两个可切换目标")
 for i in order.size()+1:
  var old: String=maze.capture_flow.locked_target_id
  var expected: String=order[(order.find(old)+1)%order.size()]
  await key(KEY_TAB)
  _check(maze.capture_flow.locked_target_id==expected,"Tab按目录稳定顺序切换并回绕："+str(i),{"expected":expected,"actual":maze.capture_flow.locked_target_id})
 var locked: String=maze.capture_flow.locked_target_id
 var repeat:=InputEventKey.new()
 repeat.keycode=KEY_TAB
 repeat.pressed=true
 repeat.echo=true
 viewport.push_input(repeat)
 await get_tree().process_frame
 _check(maze.capture_flow.locked_target_id==locked,"按住Tab的重复事件不连跳目标")
 for pair in [[KEY_1,1],[KEY_2,2],[KEY_SPACE,0]]:
  await key(pair[0])
  _check(state().combat.selected==pair[1] and maze.capture_flow.locked_target_id==locked,"换招保持锁定："+str(pair[1]))
 var position_before: Vector2=maze.player.position
 Input.action_press("ui_down")
 await get_tree().create_timer(0.12).timeout
 Input.action_release("ui_down")
 _check(maze.player.position.distance_to(position_before)>1.0 and maze.capture_flow.locked_target_id==locked,"真实内部移动改变站位但不改锁定")
 await get_tree().process_frame
 _check(maze.capture_flow.monsters[locked].label.visible,"沿用现有单目标血条显示锁定对象，不新增光效")
 await picture("normal_locked_existing_label")
 var throws_before: int=state().combat.throws
 await mouse(maze.capture_flow.controls_hint.get_global_rect().get_center())
 _check(state().combat.throws==throws_before,"点击扩宽提示栏不穿透为攻击")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"真实小地图入口展开并暂停")
 var paused: Dictionary=state().combat.duplicate(true)
 await key(KEY_TAB)
 await key(KEY_Q)
 await click()
 _check(state().combat==paused and maze.capture_flow.locked_target_id==locked,"地图暂停时Tab、Q和攻击均不穿透")
 await key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded and maze.capture_flow.locked_target_id==locked,"关闭地图后恢复原有效锁定")
 await key(KEY_Q)
 _check(maze.capture_flow.locked_target_id.is_empty(),"Q解除锁定")
 await key(KEY_Q)
 _check(maze.capture_flow.locked_target_id.is_empty(),"未锁定时Q无副作用")
 if failures: return
 await direction_and_range()
 await invalidation()
 await defeat_and_recover()
 _check(Run.valid(state()),"完整交互后探索状态仍合法")
 if failures==0: await legacy_routing()

func candidate_order() -> Array[String]:
 var ids: Array[String]=[]
 var run:=state()
 var rect: Rect2=maze.capture_flow.visible_world_rect()
 for row in Catalog.rows(run.combat):
  var a: Dictionary=run.combat.actors[row.id]
  if run.monsters[row.id].status=="alive" and a.hp>0 and a.mode!="return" and Catalog.targetable(run.combat,row.id) and rect.has_point(Run.Combat.vec(a.position)): ids.append(row.id)
 return ids

func reset_fixture(point: Vector2=Vector2(840,490)) -> void:
 # 仅复原隔离档并暂停推进以固定输入边界；仍由真实视口消费按键，不调用选敌内部函数。
 maze.capture_flow.set_process(false)
 sm.data=baseline.duplicate(true)
 maze.player.position=point
 maze.camera.snap_to_target()
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return state().combat.cooldown<=0.00001 and state().combat.action_left<=0.0,2.0),"等待真实入场冷却结束，不写零冷却")
 maze.capture_flow.set_process(false)
 await key(KEY_Q)
 var invalid: Array=[]
 for row in Catalog.rows(state().combat,true):
  var a: Dictionary=state().combat.actors[row.id]
  if not Run.Combat.Silverfish.valid(a) or not Run.Combat.ThunderEel.valid(a) or (row.kind=="wind_frog" and not Run.Combat.Frog.valid(a)): invalid.append({"id":row.id,"actor":a})
 _check(Run.valid(state()),"隔离复原输入有效",{"invalid_actors":invalid,"combat_valid":Run.Combat.valid(state().combat),"walkable":sm.maze_terrain(sm.maze_exploration_state().region).is_walkable(point),"paused":maze.capture_flow.combat_paused(),"retry":maze.capture_flow.save_retry_delay})

func lock_fish() -> void:
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==FISH: break
 _check(maze.capture_flow.locked_target_id==FISH,"真实Tab选中指定远鱼，不直接写锁定编号")

func direction_and_range() -> void:
 for pair in [[KEY_SPACE,"hero"],[KEY_1,"yaya"],[KEY_2,"tieshan"]]:
  await reset_fixture()
  await lock_fish()
  await key(pair[0])
  var start: Vector2=maze.player.position
  var at:=Run.Combat.vec(state().combat.actors[FISH].position)
  _check(Aim.target(state(),start)!=FISH,"自动瞄准与当前锁定对象确实不同："+pair[1])
  var throws: int=state().combat.throws
  await click()
  var c: Dictionary=state().combat
  var expected:=start.direction_to(at)
  var hovered: Control=viewport.gui_get_hovered_control()
  _check(c.throws==throws+1 and Run.Combat.vec(c.aim).dot(expected)>0.9999,"真实攻击优先朝锁定远鱼出手："+pair[1],{"throws":c.throws,"cooldown":c.cooldown,"action_left":c.action_left,"aim":c.aim,"expected":str(expected),"hovered":str(hovered.get_path()) if hovered else "","paused":maze.capture_flow.combat_paused(),"retry":maze.capture_flow.save_retry_delay})
  _check(maze.capture_flow.locked_target_id==FISH,"换招和攻击不因射程改锁近怪："+pair[1])
  if pair[1]=="tieshan":
   _check(c.axe_pending and c.shots.is_empty() and start.distance_to(at)>Run.Combat.Skills.AXE_RADIUS,"远锁不把近战变成远程弹体")
  else:
   if c.shots.is_empty(): return
   var shot: Dictionary=c.shots.back()
   var length: float=Run.Combat.vec(shot.origin).distance_to(Run.Combat.vec(shot.target))
   _check(absf(length-Run.Combat.Skills.LENGTH[pair[1]])<0.01,"锁定后弹体长度保持原射程："+pair[1])
  _check(not sm.data[Run.KEY].has("locked_target_id") and not c.has("locked_target_id"),"锁定编号不进入探索或战斗存档："+pair[1])
 # 未锁定时仍从原自动瞄准入口获得出手方向。
 await reset_fixture()
 var expected:=Aim.direction(state(),maze.player.position,maze.player.facing)
 await click()
 _check(Run.Combat.vec(state().combat.aim).dot(expected)>0.9999,"解除后恢复原自动瞄准")

func invalidation() -> void:
 await reset_fixture()
 await lock_fish()
 viewport.size=Vector2i(320,180)
 maze.camera.snap_to_target()
 maze.capture_flow.set_process(true)
 await get_tree().process_frame
 await get_tree().process_frame
 _check(not maze.capture_flow.visible_world_rect().has_point(Run.Combat.vec(state().combat.actors[FISH].position)) and maze.capture_flow.locked_target_id.is_empty(),"实际视口缩小使目标离开视野后自动解除")
 viewport.size=Vector2i(1280,720)
 for status in ["captured","skipped"]:
  await reset_fixture()
  await lock_fish()
  var run:=state()
  run.monsters[FISH].status=status
  sm.data[Run.KEY]=run
  maze.capture_flow.set_process(true)
  await get_tree().process_frame
  await get_tree().process_frame
  _check(maze.capture_flow.locked_target_id.is_empty(),"已离场目标不保留锁定："+status)
 await reset_fixture()
 await lock_fish()
 var returning:=state()
 returning.combat.actors[FISH].mode="return"
 sm.data[Run.KEY]=returning
 await click()
 _check(maze.capture_flow.locked_target_id.is_empty(),"出手前复核并解除返回中的目标")
 # 已解锁可见dormant巨蛙现在可锁；旧emerging出水仍不可锁。
 for phase in ["emerging"]:
  await reset_fixture(Vector2(1100,440))
  var hidden_frog:=state()
  hidden_frog.combat.actors[Boss.ID].frog_phase=phase
  hidden_frog.combat.actors[Boss.ID].frog_left=0.5 if phase=="emerging" else 0.0
  sm.data[Run.KEY]=hidden_frog
  var selected_hidden:=false
  for i in 8:
   await key(KEY_TAB)
   selected_hidden=selected_hidden or maze.capture_flow.locked_target_id==Boss.ID
  _check(not selected_hidden,"Tab跳过巨蛙不可选阶段："+phase)
 await reset_fixture()
 var run:=state()
 for monster in run.monsters.values(): monster.status="skipped"
 sm.data[Run.KEY]=run
 await key(KEY_TAB)
 _check(maze.capture_flow.locked_target_id.is_empty() and state().combat.selected==0,"没有有效目标时Tab保持未锁定且不换招")
 # 失焦事件不占用系统焦点；只修改游戏内部已存在的焦点门禁。
 await reset_fixture()
 await lock_fish()
 maze.capture_flow.window_focused=false
 await key(KEY_TAB)
 await key(KEY_Q)
 await click()
 _check(maze.capture_flow.locked_target_id==FISH and state().combat.throws==0,"失焦时锁定键与攻击不生效")
 maze.capture_flow.window_focused=true
 await key(KEY_Q)
 _check(maze.capture_flow.locked_target_id.is_empty(),"内部焦点恢复后Q正常解除")

func defeat_and_recover() -> void:
 await reset_fixture(Vector2(1100,440))
 var run:=state()
 var fish: Dictionary=run.combat.actors[FISH]
 fish.position=[1065.0,405.0]
 fish.fish_origin=fish.position.duplicate()
 fish.fish_aim=[0.0,1.0]
 fish.fish_hit=false
 fish.fish_phase="recover"
 fish.fish_left=2.5
 fish.hp=1
 sm.data[Run.KEY]=run
 await lock_fish()
 await key(KEY_SPACE)
 maze.capture_flow.set_process(true)
 var throws: int=state().combat.throws
 var hp_before: Dictionary=state().combat.actors.duplicate(true)
 await click()
 _check(await until_true(func(): return state().combat.actors[FISH].hp<=0,2.0),"真实锁定攻击击败鱼，而非写入死亡结果",{"before":hp_before,"after":state().combat.actors,"throws":state().combat.throws,"aim":state().combat.aim})
 _check(state().combat.throws==throws+1 and maze.capture_flow.locked_target_id.is_empty(),"目标实际死亡后锁定自动解除")
 _check(await until_true(func(): return maze.capture_flow.dialog.visible,2.0),"死亡动作结束进入原捕获窗")
 if failures: return
 _check(await until_true(func(): return not maze.capture_flow.dialog.flipping,1.0),"等待原捕获窗翻入完成再操作")
 await key(KEY_TAB)
 _check(maze.capture_flow.locked_target_id.is_empty(),"捕获窗阻止Tab穿透选中其他目标")
 await mouse(maze.capture_flow.dialog._cancel_button.get_global_rect().get_center())
 _check(await until_true(func(): return not maze.capture_flow.busy and not maze.player.input_locked),"真实取消捕获后恢复探索输入")
 _check(state().monsters[FISH].status=="skipped","原捕获结算仍只离场实际击败的鱼")
 await key(KEY_TAB)
 _check(not maze.capture_flow.locked_target_id.is_empty() and maze.capture_flow.locked_target_id!=FISH,"捕获恢复后可锁定另一只存活魔物")
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  maze.camera.snap_to_target()
  await picture("restored_"+str(size.x))

func legacy_routing() -> void:
 for region in ["maze_entry","salt_pool","trial","legacy_story"]:
  maze.queue_free()
  await get_tree().process_frame
  sm.data=baseline.duplicate(true)
  sm.data.ch2_guide_01={"step":"done","seen":{},"banked":{},"recipe":"","revision":2}
  var path: String="res://scenes/maze_fenshui.tscn"
  if region in ["maze_entry","salt_pool"]:
   var point: Vector2=Roads.SPAWN if region=="maze_entry" else preload("res://data/maze/salt_pool_roads.gd").SPAWN
   _check(Run.change_region(sm,region,point).success,"原换区事务建立回归入口："+region)
   path="res://scenes/maze_entry.tscn" if region=="maze_entry" else "res://scenes/maze_salt_pool.tscn"
  elif region=="trial": sm.data[Run.KEY].combat.fs01_trial=true
  # 快照将版本2的旧切磋检查点迁移为版本3友好委托，不再等待已移除的战斗阶段。
  else: sm.data[sm.YUFENG_SALIA_KEY]={"version":2,"phase":"question","line":0}
  maze=load(path).instantiate()
  viewport.add_child(maze)
  if region=="legacy_story":
   _check(await until_true(func(): return maze._entry_ready and maze.yf_encounter.phase=="intro"),"旧切磋检查点实际迁移为友好初遇")
   _check(sm.yufeng_salia_record().version==3 and maze.capture_flow.sparring()==null and maze.yf_encounter.run.is_empty(),"迁移后使用正常探索，不创建旧切磋状态")
   _check(maze.player.input_locked and maze.yf_encounter.dialog.visible,"友好初遇对白持有输入锁")
   var before_story: Dictionary=maze.capture_flow.display_run().combat.duplicate(true)
   maze.capture_flow.window_focused=true
   await key(KEY_TAB)
   await key(KEY_Q)
   await click()
   _check(maze.capture_flow.display_run().combat.selected==before_story.selected and maze.capture_flow.display_run().combat.throws==before_story.throws and maze.capture_flow.locked_target_id.is_empty(),"友好对白期间Tab、Q及攻击不穿透")
   continue
  _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实回归场景入场完成："+region)
  maze.capture_flow.window_focused=true
  await get_tree().process_frame
  await get_tree().process_frame
  var normal: bool=region in ["maze_entry","salt_pool"]
  _check(maze.capture_flow.target_lock_enabled()==normal,"正常地图共用锁定，特殊模式继续排除："+region)
  check_hint_layout(normal,region)
  var marker: Node2D=maze.capture_flow.target_marker
  _check((marker==null or not marker.visible) and maze.capture_flow.movement_allowed(Vector2.ZERO,Vector2.ZERO),"初始未锁定无标记，且不推广分水庭脚底阻挡："+region)
  var before: int=maze.capture_flow.display_run().combat.selected
  await key(KEY_TAB)
  if normal:
   _check(maze.capture_flow.display_run().combat.selected==before,"正常地图Tab用于锁定而非切招："+region)
  else:
   _check(maze.capture_flow.display_run().combat.selected!=before and maze.capture_flow.locked_target_id.is_empty(),"特殊模式旧Tab切招式保留："+region)
  var selected: int=maze.capture_flow.display_run().combat.selected
  await key(KEY_Q)
  _check(maze.capture_flow.display_run().combat.selected==selected,"其他模式Q不改招式："+region)

func check_hint_layout(lock_mode: bool, label: String) -> void:
 var hint: Control=maze.capture_flow.controls_hint
 var content: HBoxContainer=hint.get_node("InteractButton/Content")
 var captions: Array=[]
 for caption in hint.find_children("*","Label",true,false):
  if caption.is_visible_in_tree(): captions.append(caption.text)
 var expected: Array=["左键","攻击","Tab","锁定/切换","Q","解除锁定","Shift","加速"] if lock_mode else ["左键","攻击","Tab","切换","Shift","加速"]
 _check(captions==expected,"固定提示完整且顺序正确："+label,{"actual":captions,"expected":expected})
 var frame: Rect2=hint.get_global_rect()
 var previous_right:=frame.position.x
 for child in content.get_children():
  if not child.visible: continue
  var bounds: Rect2=child.get_global_rect()
  _check(frame.grow(0.5).encloses(bounds) and bounds.position.x>=previous_right-0.5,"键帽与文字不重叠且完整位于底框："+label+"/"+child.name,{"frame":str(frame),"bounds":str(bounds)})
  previous_right=bounds.end.x
 _check(absf(frame.get_center().x-viewport.size.x*0.5)<1.0 and frame.position.y>=0 and frame.end.y<=viewport.size.y+0.5,"提示栏居中且完整入屏："+label)
 if not lock_mode: _check(is_equal_approx(frame.size.x,348.0),"其他模式保持原348宽度："+label)
