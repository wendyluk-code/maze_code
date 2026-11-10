extends "res://tools/tests/fenshui_frog_counter_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实七怪入场完成")
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(false)
 var run:=state()
 var frog: Dictionary=run.combat.actors[Boss.ID]
 frog.position=[900.0,450.0]
 frog.frog_phase="active"
 frog.frog_left=1.2
 frog.frog_origin=frog.position.duplicate()
 frog.frog_target=frog.position.duplicate()
 sm.data[Run.KEY]=run
 maze.player.position=Vector2(830,450)
 maze.capture_flow.set_process(true)
 await get_tree().process_frame
 await get_tree().process_frame
 maze.capture_flow.set_process(false)
 _check(maze.capture_flow.monsters[Boss.ID].enable_frog_front24(),"脚底碰撞与同一1.4倍双前向身体共同验收")
 Input.action_press("ui_right")
 for i in 75: await get_tree().physics_frame
 Input.action_release("ui_right")
 _check(maze.player.position.x<=855.1 and maze.player.position.x>=850.0,"实际内部移动停在巨蛙脚底左沿，不穿入中心",{"position":str(maze.player.position)})
 await key(KEY_TAB)
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  maze.camera.snap_to_target()
  await picture("foot_contact_"+str(size.x))
 await key(KEY_Q)
 var before: Vector2=maze.player.position
 Input.action_press("ui_left")
 for i in 15: await get_tree().physics_frame
 Input.action_release("ui_left")
 _check(maze.player.position.x<before.x-5.0,"贴近实体后可以离开，不锁死玩家")
 _check(maze.capture_flow.monsters.size()==7,"碰撞测试保留正式七怪")
 run=state()
 run.combat.actors[Boss.ID].frog_left=0.25
 run.combat.hit_velocity=[150.0,0.0]
 run.combat.hit_remaining=0.12
 run.combat.flash_remaining=0.1
 sm.data[Run.KEY]=run
 _check(Run.valid(state()),"原18像素击退检查点有效")
 _check(Run.combat_tick(sm,Vector2(850,450),0.1,Rect2(0,0,1715,917)).success,"通过公开事务推进玩家原击退")
 _check(Run.Combat.vec(state().combat.hero).x<=855.1,"原击退也在脚底实体前截停，不穿入巨蛙",{"hero":state().combat.hero})
 run=state()
 run.combat.hero=[895.0,450.0]
 sm.data[Run.KEY]=run
 _check(sm.record_maze_location("fenshui",Vector2(895,450)).success and sm.save(),"真实保存旧脚底重叠检查点")
 sm.load_data()
 maze.player.position=Run.Combat.vec(state().combat.hero)
 _check(maze.player.position.is_equal_approx(Vector2(895,450)) and Run.valid(state()),"实际读回旧重叠，不拒绝整个存档")
 Input.action_press("ui_left")
 for i in 55: await get_tree().physics_frame
 Input.action_release("ui_left")
 _check(maze.player.position.x<854.9,"旧档实体重叠允许沿分离方向走出，不永久卡住",{"hero":str(maze.player.position)})
 maze.player.position=Vector2(850,450)
 var slide_start: Vector2=maze.player.position
 Input.action_press("ui_right")
 Input.action_press("ui_down")
 for i in 35: await get_tree().physics_frame
 Input.action_release("ui_right")
 Input.action_release("ui_down")
 _check(maze.player.position.y>slide_start.y+15.0,"斜向贴边沿可行轴滑行，不把整次位移拒绝",{"hero":str(maze.player.position)})
 await melee_and_release()

func melee_and_release() -> void:
 maze.player.position=Vector2(850,450)
 Input.action_press("ui_right")
 for i in 25: await get_tree().physics_frame
 Input.action_release("ui_right")
 maze.capture_flow.window_focused=true
 maze.capture_flow.set_process(true)
 await key(KEY_2)
 _check(await until_true(func(): return state().combat.cooldown<=0.00001),"正常等待原近战冷却，不增射程或改冷却")
 var hits: int=state().combat.hits
 await click()
 _check(await until_true(func(): return state().combat.hits>hits,2.0),"实体阻挡后的合法贴近站位仍能用原铁山近战实际命中")
 # 只控制隔离档遭遇前置，击败必须由真实攻击产生；保留七只怪物。
 maze.capture_flow.set_process(false)
 sm.data=entry_snapshot.duplicate(true)
 var run:=state()
 var id:="fenshui_silverfish_1"
 var fish: Dictionary=run.combat.actors[id]
 fish.fish_phase="recover"
 fish.fish_left=2.5
 fish.fish_origin=fish.position.duplicate()
 fish.fish_aim=[0.0,1.0]
 fish.fish_hit=false
 fish.hp=1
 sm.data[Run.KEY]=run
 var corpse:=Run.Combat.vec(fish.position)
 maze.player.position=corpse+Vector2(-30,0)
 maze.camera.snap_to_target()
 maze.capture_flow.set_process(true)
 await key(KEY_SPACE)
 _check(await until_true(func(): return state().combat.cooldown<=0.00001),"原锅铲冷却完成")
 await click()
 _check(await until_true(func(): return state().combat.actors[id].hp<=0,1.0),"真实锅铲击败鱼后检查占位释放")
 maze.capture_flow.set_process(false)
 maze.player.position=corpse+Vector2(-30,0)
 Input.action_press("ui_right")
 for i in 65: await get_tree().physics_frame
 Input.action_release("ui_right")
 _check(maze.player.position.x>corpse.x+10.0,"死亡动作尚未结算捕获时已释放脚底，可真实走过原位置",{"hero":str(maze.player.position),"corpse":str(corpse)})
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return maze.capture_flow.dialog.visible,2.0),"死亡仍进入原捕获流程")
 _check(await until_true(func(): return not maze.capture_flow.dialog.flipping,1.0),"原捕获窗翻入完成")
 await mouse(maze.capture_flow.dialog._cancel_button.get_global_rect().get_center())
 _check(await until_true(func(): return not maze.player.input_locked and not maze.capture_flow.busy,2.0),"原捕获取消后恢复输入")
 _check(state().monsters[id].status=="skipped" and Run.valid(state()),"离场后占位继续释放，原存档可保存")
