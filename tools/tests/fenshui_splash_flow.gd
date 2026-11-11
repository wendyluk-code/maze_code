extends "res://tools/tests/fenshui_player_hurt_flow.gd"
## 保留正式七怪，真实事务走过预警、起跳、落地；水花不拥有战斗状态。
var splash: Node2D

func battle() -> void:
 if _arg("--phase=")=="1152": viewport.size=Vector2i(1152,648)
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"水花使用正常七怪入口")
 _check(maze.capture_flow.monsters[Boss.ID].get_node_or_null("LandingSplashCandidate")==null,"正式G地图默认不安装未终审水花")
 _check(not maze.capture_flow.player_hurt_visual.refined_pose,"正式G默认受击显示也不被候选入口静默修改")
 var entry: Node=load("res://tools/previews/fenshui_feedback_play.gd").new()
 _check(entry._play_message().count("\n")>=4 and not entry._play_message().contains("\\n"),"真实候选确认窗正确换行，明确显示未终审范围")
 entry.maze=maze
 _check(entry._prepare_frog(),"实际候选入口安装新水花和持续痛态，不手工复制另一套接线")
 splash=entry.splash
 entry.free()
 setup(HURT_POINT)
 seed_hurt("slam")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.frog_phase="warning"
 a.frog_left=0.15
 a.position=a.frog_origin.duplicate()
 splash.clear()
 splash._process(0.0)
 _check(Run.valid(state()),"自然起落使用合法预警检查点，不更改攻击判定")
 var hp: float=state().combat.hp
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return splash.takeoffs==1,1.0),"真实预警转腾空启动一次起跳水花")
 _check(actor().frog_phase=="airborne" and state().combat.hp==hp,"腾空不结算巨蛙落地伤害")
 _check(splash.back.visible and splash.front.visible and splash.frame in [0,1,2],"起跳实际消费新图集前三帧并前后分层")
 var origin:=Run.Combat.vec(actor().frog_origin)
 _check(splash.global_position.distance_to(origin)<0.01,"起跳水花固定在起跳水面，不随空中身体漂移")
 await picture("real_takeoff")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 var age: float=splash.age
 var left: float=actor().frog_left
 await get_tree().create_timer(0.25).timeout
 _check(maze.map_ui.expanded and splash.age==age and actor().frog_left==left,"真实地图暂停同时冻结空中状态与起跳水花")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return splash.landings==1,1.5),"真实腾空转落地启动一次落地水花")
 _check(actor().frog_phase=="landing" and state().combat.hp<hp,"落地水花对应原真实落地扣血事务")
 _check(splash.frame in [3,4,5,6,7,8],"落地消费六帧新图，不复用人物水枪受击图")
 _check(splash.global_position.distance_to(Run.Combat.vec(actor().position))<0.01,"落地水花挂在实际落点")
 _check(splash.back.z_index==0 and splash.front.z_index>0 and splash.get_index()<splash.get_parent().body.get_index(),"水花后半按树序在身体后但不沉到地图底下，前半只遮脚底下侧")
 _check(await until_true(func(): return splash.age>=0.24,0.5),"正常速度连续到落地主浪")
 await picture("real_landing_peak")
 maze.capture_flow.set_process(false)
 splash.set_process(false)
 RenderingServer.force_draw(false)
 var shown: Image=viewport.get_texture().get_image()
 splash.back.hide()
 RenderingServer.force_draw(false)
 var hidden: Image=viewport.get_texture().get_image()
 _check(shown.get_data()!=hidden.get_data(),"后半水花在实际游戏画面可见，不只检查节点层级")
 splash.back.show()
 splash.set_process(true)
 var before: Dictionary=state().duplicate(true)
 splash._process(0.0)
 _check(state()==before,"显示采样不写生命、位置或伤害状态")
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return splash.frame== -1,1.0),"650毫秒水花结束，无残留图层")
 _check(splash.landings==1 and splash.takeoffs==1,"同一次起落不重复播放或重复触发伤害")
 _check(Run.valid(state()) and maze.capture_flow.monsters.size()==7,"联合播放后正常七怪与原状态仍合法")
 setup(HURT_POINT)
 splash.clear()
 _check(splash.frame== -1 and not splash.back.visible and not splash.front.visible,"复位清理两半水花，不残留旧波浪")
 for slot in [0,1,2]:
  await actual_hit(slot,false,viewport.size.x)
  if failures: return
 await failure_and_cleanup()
