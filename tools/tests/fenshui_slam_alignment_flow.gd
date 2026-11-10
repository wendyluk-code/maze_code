extends "res://tools/tests/fenshui_feedback_repair.gd"

func battle() -> void:
 if _arg("--phase=")=="lethal":
  _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"双击杀从正式场景就绪入口开始")
  var entry: Node=load("res://tools/previews/fenshui_feedback_play.gd").new()
  entry.maze=maze
  _check(entry._prepare_frog(),"双击杀沿实际候选消费者")
  entry.free()
  await lethal()
  return
 # 复用原四向真实受击、禁移禁攻和恢复检查，不重复其余无关全集。
 await super.battle()
 if failures: return
 setup(Vector2(1140,470))
 seed_hurt("slam")
 var c: Dictionary=sm.data[Run.KEY].combat
 var fish: Dictionary=c.actors[FISH]
 fish.position=[1100.0,450.0]
 fish.fish_origin=fish.position.duplicate()
 fish.fish_aim=[0.0,1.0]
 fish.fish_hit=false
 Run.Combat.Silverfish.phase(fish,"recover",2.5)
 var eel: Dictionary=c.actors["fenshui_thunder_eel_2"]
 eel.position=[1150.0,450.0]
 eel.eel_origin=eel.position.duplicate()
 eel.eel_path=[]
 eel.cooldown=10.0
 Run.Combat.ThunderEel.phase(eel,"idle",0.0)
 var a: Dictionary=c.actors[Boss.ID]
 a.frog_phase="warning"
 a.frog_left=0.1
 a.position=a.frog_origin.duplicate()
 _check(Run.valid(state()),"真实七怪联合范围检查点合法")
 var hp: float=c.hp
 var fish_hp: float=fish.hp
 var eel_hp: float=eel.hp
 splash.clear()
 splash._process(0.0)
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return splash.takeoffs>0,1.0),"自然预警转起跳消费原水花")
 _check(state().combat.hp==hp and state().combat.actors[FISH].hp==fish_hp,"空中未结算范围伤害")
 _check(await until_true(func(): return splash.landings>0,1.3),"自然落地启动同落点主浪")
 _check(state().combat.hp<hp and state().combat.actors[FISH].hp<fish_hp and state().combat.actors["fenshui_thunder_eel_2"].hp<eel_hp,"真实七怪落地同时伤到玩家、鱼及电鳗")
 _check(await until_true(func(): return splash.age>=0.24,0.5),"主浪实际展开到峰值阶段")
 var width: float=splash.back.scale.x*float(splash._peaks.landing)
 _check(absf(width-269.7916666667)<0.02,"水花原交付峰值横宽保持约270，不靠缩小素材掩盖判定")
 _check(splash.global_position.distance_to(Run.Combat.vec(actor().position))<0.01,"范围和水花均使用实际落点")
 await picture("slam_player_fish_eel")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 var left: float=state().combat.hurt_recovery_left
 var age: float=splash.age
 await get_tree().create_timer(0.15).timeout
 _check(maze.map_ui.expanded and state().combat.hurt_recovery_left==left and splash.age==age,"地图暂停同时冻结主浪和玩家受击恢复")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return not maze.capture_flow.player_hurt_visual.active(),1.0),"范围受击结束正常恢复人物")
 _check(Run.valid(state()) and maze.capture_flow.monsters.size()==7,"联合范围实战后原七怪场景仍合法")

func lethal() -> void:
 setup(Vector2(1140,470))
 var fixture: Node=load("res://tools/tests/fenshui_slam_alignment.gd").new()
 fixture.sm=sm
 fixture.original=sm.data.duplicate(true)
 fixture.seed_monsters()
 fixture.free()
 var c: Dictionary=sm.data[Run.KEY].combat
 for id in [FISH,"fenshui_thunder_eel_2"]: c.actors[id].hp=0.5
 var a: Dictionary=c.actors[Boss.ID]
 a.frog_phase="warning"
 a.frog_left=0.1
 a.position=a.frog_origin.duplicate()
 _check(Run.valid(state()),"双目标低生命受控检查点合法")
 maze.capture_flow.set_process(true)
 var flow: Node=maze.capture_flow
 _check(await until_true(func(): return state().combat.actors[FISH].hp<=0 and state().combat.actors["fenshui_thunder_eel_2"].hp<=0,2.0),"同次真实落地能够同时击败鱼鳗")
 _check(await until_true(func(): return flow.dialog.visible and not flow.dialog.flipping,2.5),"双击杀后实际显示首个原捕获询问窗")
 if failures: return
 var first: String=flow.current
 await picture("slam_double_defeat_first")
 await mouse(flow.dialog._cancel_button.get_global_rect().get_center())
 _check(await until_true(func(): return flow.dialog.visible and not flow.dialog.flipping and flow.current!=first,2.5),"处理第一个目标后进入第二个目标，不永久锁输入")
 if failures: return
 await mouse(flow.dialog._cancel_button.get_global_rect().get_center())
 _check(await until_true(func(): return not flow.busy and not maze.player.input_locked,2.0),"两个目标均处理后完整恢复人物控制")
 _check(Run.valid(state()),"双击杀与原结算兼容，最终状态合法")
 await picture("slam_double_defeat_restored")
