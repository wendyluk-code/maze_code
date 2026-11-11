extends "res://tools/tests/fenshui_frog_counter_flow.gd"
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const FISH="fenshui_silverfish_1"
var test_id:=FISH
var returning_samples: Dictionary={}

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实七怪地图完成入场")
 for kind in ["silverfish","thunder_eel"]:
  for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
   viewport.size=resolution
   await shore_cycle(kind,resolution)
   if failures: return
 await frog_return()
 if failures: return
 await lifecycle()

func shore_fixture(run: Dictionary, kind: String="silverfish") -> Dictionary:
 for row in Run.Catalog.Fenshui.all():
  if row.kind!=kind: continue
  var start:=Fish.vec(run.combat.actors[row.id].position)
  for direction in 32:
   var aim:=Vector2.RIGHT.rotated(direction*TAU/32.0)
   var clear:=true
   # 雷鳗55像素限制从最后完整水中点算，不能误当从出生点总路程。
   for distance in range(2,111 if kind=="silverfish" else 171,2):
    var point:=start+aim*distance
    if not Fish.allowed(point) or not preload("res://scripts/maze/water_spacing.gd").clear(run,row.id,point):
     clear=false
     break
    if distance>=45 and Fish.dry(point) and Fish.Roads.is_walkable(point) and not Fish.Water.protected(point):
     return {"id":row.id,"hero":point,"start":start}
   if not clear: continue
 return {}

func reset(point: Vector2, checkpoint: Dictionary={}) -> void:
 maze.capture_flow.set_process(false)
 sm.data=entry_snapshot.duplicate(true)
 if not checkpoint.is_empty(): sm.data[Run.KEY]=checkpoint.duplicate(true)
 maze.capture_flow.dialog.hide()
 maze.capture_flow.attempt.close()
 maze.capture_flow.reward.hide()
 maze.capture_flow.busy=false
 maze.capture_flow.resolving=false
 maze._busy=false
 maze.player.input_locked=false
 maze.player.position=point
 maze.camera.snap_to_target()
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 await get_tree().process_frame

func shore_cycle(kind: String, resolution: Vector2i) -> void:
 var checkpoint: Dictionary=entry_snapshot[Run.KEY].duplicate(true)
 if kind=="thunder_eel":
  # 雷鳗出生点不适合直线诱导；仅交换两个合法水中检查点，数量和规则不变。
  var original: Array=checkpoint.combat.actors["fenshui_thunder_eel_1"].position.duplicate()
  checkpoint.combat.actors["fenshui_thunder_eel_1"].position=checkpoint.combat.actors["fenshui_silverfish_4"].position.duplicate()
  checkpoint.combat.actors["fenshui_silverfish_4"].position=original
 var fixture:=shore_fixture(checkpoint,kind)
 _check(not fixture.is_empty(),"七怪岸水检查点存在合法完整上岸路线："+kind)
 if fixture.is_empty(): return
 test_id=fixture.id
 await reset(fixture.hero,checkpoint)
 var field: String="fish_phase" if kind=="silverfish" else "eel_phase"
 var node: Node=maze.capture_flow.monsters[test_id]
 _check(Run.valid(state()) and maze.capture_flow.monsters.size()==7,"岸边检查点合法且保留七只怪物："+kind,{"fixture":fixture,"swapped_water_checkpoint":kind=="thunder_eel"})
 _check(node.get("return_water_visual") is Node2D,"真实怪物节点接入汗滴："+kind)
 if failures: return
 var sweat: Node2D=node.return_water_visual
 _check(not sweat.visible,"普通巡游或预警不冒汗："+kind)
 _check(await until_true(func(): return state().combat.actors[test_id].get(field,"")=="stranded",5.0),"真实站位自然诱导完整上岸："+kind,{"actor":state().combat.actors[test_id]})
 if failures: return
 _check(not sweat.visible,"搁浅尚未回水时不冒汗："+kind)
 # 走离攻击位置，模拟玩家躲避；不控制系统键鼠。
 Input.action_press("ui_down")
 await get_tree().create_timer(0.22).timeout
 Input.action_release("ui_down")
 _check(await until_true(func(): return state().combat.actors[test_id].get(field,"")=="returning",4.0),"真实搁浅结束后开始回水："+kind)
 if failures: return
 returning_samples[kind]={"id":test_id,"actor":state().combat.actors[test_id].duplicate(true)}
 _check(sweat.visible,"实际回水时汗滴可见："+kind)
 await picture(kind+"_returning_"+str(resolution.x))
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"真实地图按钮暂停回水："+kind)
 var paused: Dictionary=state().combat.actors[test_id].duplicate(true)
 var clock: float=sweat.clock
 var frame: int=node.frame_index()
 await get_tree().create_timer(0.24).timeout
 _check(state().combat.actors[test_id]==paused and sweat.clock==clock and node.frame_index()==frame,"地图期间位置、汗滴和回水动作都冻结："+kind)
 await key(KEY_ESCAPE)
 _check(not maze.map_ui.expanded,"地图关闭恢复："+kind)
 _check(await until_true(func(): return state().combat.actors[test_id].get(field,"")=="forming",4.0),"完整入水后才进入凝膜："+kind)
 if failures: return
 _check(Fish.Water.water(Fish.vec(state().combat.actors[test_id].position)),"入水按完整身体圆判定："+kind)
 await get_tree().create_timer(0.64).timeout
 _check(not sweat.visible,"完整入水后0.6秒内汗滴收尾清除："+kind)
 _check(Run.valid(state()),"汗滴不写坏原存档状态："+kind)
 await picture(kind+"_water_clear_"+str(resolution.x))

func frog_return() -> void:
 # 找原规则允许的回家单跳，确实经过非完整水域，而非伪造岸上落点。
 var fixture:=frog_fixture(entry_snapshot[Run.KEY])
 _check(not fixture.is_empty(),"巨蛙存在原规则允许的回水越岸跳跃")
 if fixture.is_empty(): return
 await reset(fixture.hero)
 maze.capture_flow.set_process(false)
 var run:=state()
 var a: Dictionary=run.combat.actors[Boss.ID]
 a.position=Fish.pack(fixture.start)
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.frog_phase="active"
 a.frog_left=0.0
 a.mode="chase"
 sm.data[Run.KEY]=run
 _check(Run.valid(state()),"巨蛙仅恢复合法水中活动检查点",{"fixture":fixture})
 maze.capture_flow.set_process(true)
 var node: Node=maze.capture_flow.monsters[Boss.ID]
 _check(node.enable_frog_front24(),"同一回水阶段兼容已认可1.4倍双前向候选")
 _check(await until_true(func(): return actor().mode=="return" and actor().frog_phase=="airborne" and not Boss.water(Fish.vec(actor().position),Boss.BODY),5.0),"巨蛙原自然返回跳跃实际越岸")
 if failures: return
 _check(node.return_water_visual.visible,"巨蛙真实回水越岸时冒汗")
 returning_samples["wind_frog"]={"id":Boss.ID,"actor":actor().duplicate(true)}
 await picture("frog_return_crossing")
 _check(await until_true(func(): return actor().frog_phase=="landing",2.0),"返回跳跃落到原合法水域")
 await get_tree().create_timer(0.64).timeout
 _check(not node.return_water_visual.visible,"巨蛙落水后0.6秒内清除汗滴")

func frog_fixture(run: Dictionary) -> Dictionary:
 var path=preload("res://scripts/maze/frog_water_path.gd")
 for y in range(240,700,32):
  for x in range(320,1400,32):
   var start:=Vector2(x,y)
   if not Boss.allowed(start) or not preload("res://scripts/maze/water_spacing.gd").clear(run,Boss.ID,start): continue
   var target: Vector2=path.landing(run,start,Boss.HOME)
   if start.distance_to(target)<100.0: continue
   var dry:=false
   for i in range(1,16):
    if not Boss.water(start.lerp(target,float(i)/16.0),Boss.BODY): dry=true
   if dry:
    var hero:=Vector2.ZERO
    var best:=INF
    var midpoint:=start.lerp(target,0.5)
    for hy in range(int(midpoint.y)-160,int(midpoint.y)+161,16):
     for hx in range(int(midpoint.x)-160,int(midpoint.x)+161,16):
      var point:=Vector2(hx,hy)
      if not Fish.dry(point) or not Fish.Roads.is_walkable(point) or Fish.Water.protected(point): continue
      var distance:=point.distance_squared_to(midpoint)
      if distance<best:
       best=distance
       hero=point
    if not hero.is_zero_approx(): return {"start":start,"target":target,"hero":hero}
 return {}

func lifecycle() -> void:
 await reset(Vector2(438,395))
 _check(await until_true(func(): return state().combat.cooldown<=0.00001,2.0),"压力组合前等待真实入场冷却结束")
 maze.capture_flow.set_process(false)
 var run:=state()
 for kind in returning_samples:
  var sample: Dictionary=returning_samples[kind]
  run.combat.actors[sample.id]=sample.actor.duplicate(true)
 sm.data[Run.KEY]=run
 _check(Run.valid(run),"三怪同场显示清理压力样例状态可读取，不代表正常布局")
 maze.capture_flow.set_process(true)
 await get_tree().process_frame
 maze.capture_flow.set_process(false)
 # 明确标记压力样例，不作为正常怪物点位或正常试玩截图。
 var eel: Dictionary=sm.data[Run.KEY].combat.actors["fenshui_thunder_eel_2"]
 eel.eel_phase="charging"
 eel.eel_left=1.2
 eel.mode="windup"
 eel.windup=1.2
 var throws: int=state().combat.throws
 await key(KEY_2)
 await click()
 _check(state().combat.throws==throws+1,"三种汗滴与原雷鳗蓄电同场时，真实内部攻击入口仍可出手")
 viewport.size=Vector2i(2560,1440)
 maze.capture_flow.set_process(true)
 await get_tree().create_timer(0.15).timeout
 maze.capture_flow.set_process(false)
 _check(state().combat.elapsed>run.combat.elapsed,"组合压力样例中原战斗和多种显示共同实际推进，不仅静态摆拍")
 await picture("stress_return_sweat_and_attack")
 viewport.size=Vector2i(1280,720)
 for kind in returning_samples:
  var id: String=returning_samples[kind].id
  var node: Node=maze.capture_flow.monsters[id]
  _check(node.return_water_visual.visible,"恢复检查点重新建立瞬时视觉："+kind)
  var before: Dictionary=sm.data.duplicate(true)
  node.hide()
  await get_tree().process_frame
  _check(not node.return_water_visual.visible,"隐藏/捕获离场不留汗滴："+kind)
  _check(sm.data==before,"显示清理不修改经营或探索存档："+kind)
  node.show()
  var dead: Dictionary=run.combat.actors[id].duplicate(true)
  dead.hp=0
  node.sync_action(dead,run.combat)
  _check(not node.return_water_visual.visible,"死亡同步立即清理汗滴："+kind)
  node.sync_action(run.combat.actors[id],run.combat)
  _check(node.return_water_visual.visible,"重新进入有效回水显示可恢复："+kind)
  var other: Dictionary=run.combat.duplicate(true)
  other.region="salt_pool"
  node.sync_action(run.combat.actors[id],other)
  _check(not node.return_water_visual.visible,"其他地图不带入回水视觉："+kind)
  node.sync_action(run.combat.actors[id],run.combat)
  node.action_paused=true
  var frozen_clock: float=node.return_water_visual.clock
  await get_tree().create_timer(0.12).timeout
  _check(node.return_water_visual.clock==frozen_clock,"局部命中停顿冻结同只怪物汗滴："+kind)
  node.action_paused=false
  var idle: Dictionary=run.combat.actors[id].duplicate(true)
  if kind=="wind_frog": idle.mode="idle"
  else: idle["fish_phase" if kind=="silverfish" else "eel_phase"]="idle"
  node.sync_action(idle,run.combat)
  _check(not node.return_water_visual.visible,"不再回水时立即清理："+kind)
  var trial: Dictionary=run.combat.duplicate(true)
  trial.fs01_trial=true
  node.sync_action(run.combat.actors[id],trial)
  _check(not node.return_water_visual.visible,"旧特殊试玩不启用："+kind)
 var old: WeakRef=weakref(maze.capture_flow.monsters[FISH].return_water_visual)
 maze.queue_free()
 await get_tree().process_frame
 _check(old.get_ref()==null,"真实场景释放后汗滴节点一同销毁，无跨图残留")
