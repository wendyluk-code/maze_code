extends "res://tools/tests/fenshui_heal_hit_flow.gd"
const HURT_POINT=Vector2(1090,450)

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"玩家受击使用正式七怪入口")
 var visual: Node=maze.capture_flow.get("player_hurt_visual")
 _check(is_instance_valid(visual),"正式分水庭安装已认可玩家受击显示")
 if failures: return
 _check(maze.capture_flow.monsters[Boss.ID].enable_frog_front24(),"联合验收沿当前巨蛙双前向身体，不换怪物素材")
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=resolution
  for kind in ["fish","electric","water","slam"]:
   await actual_hurt(kind)
   if failures: return
 await direction_and_pause()
 if failures: return
 await moving_and_attacking()
 if failures: return
 await slam_recovery()
 if failures: return
 await failure_and_cleanup()

func seed_hurt(kind: String, side: float=1.0) -> void:
 var fixture=load("res://tools/tests/fenshui_player_hurt_state.gd").new()
 fixture.sm=sm
 fixture.seed_attack(kind,false)
 fixture.free()
 if side<0:
  if kind=="fish":
   var fish: Dictionary=sm.data[Run.KEY].combat.actors[FISH]
   # 接触点距玩家18，仍在17的脚底实体外；避免原分步移动停在18.5而未命中。
   fish.position=[1108.0,450.0]
   fish.fish_origin=fish.position.duplicate()
   fish.fish_aim=[-1.0,0.0]
  elif kind=="electric":
   var eel: Dictionary=sm.data[Run.KEY].combat.actors["fenshui_thunder_eel_2"]
   eel.position=[1140.0,450.0]
   eel.eel_origin=eel.position.duplicate()
  elif kind=="water":
   sm.data[Run.KEY].combat.actors[Boss.ID].frog_shots=[{"position":[1112.0,450.0],"direction":[-1.0,0.0],"distance":28.0}]

func begin_hurt(kind: String, facing: Vector2=Vector2.DOWN, side: float=1.0) -> void:
 setup(HURT_POINT)
 maze.capture_flow.player_hurt_visual.clear()
 maze.player.facing=facing
 seed_hurt(kind,side)
 var received: int=maze.capture_flow.player_hurt_visual.received
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return maze.capture_flow.player_hurt_visual.received>received,1.0),"真实攻击启动受击恢复用例："+kind,{"hero":str(maze.player.position),"hp":state().combat.hp,"fish":state().combat.actors[FISH],"paused":maze.capture_flow.combat_paused()})

func actual_hurt(kind: String) -> void:
 var visual: Node=maze.capture_flow.player_hurt_visual
 setup(HURT_POINT)
 visual.clear()
 maze.player.facing=Vector2.DOWN
 seed_hurt(kind)
 _check(Run.valid(state()),"七怪受击检查点有效："+kind)
 var hp: float=state().combat.hp
 var received: int=visual.received
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return visual.received>received,1.0),"原攻击真实命中后才播放："+kind)
 _check(state().combat.hp<hp and visual.kind==kind,"对应实际扣血且种类正确："+kind)
 _check(visual.effect.visible and visual.pose.visible,"正面玩家出现原图集受击动作及贴身图集")
 var pose_unflashed: bool=visual.pose.material==null or (visual.pose.material.shader==preload("res://scripts/maze/fenshui_water_body.gdshader") and not visual.pose.material.get_shader_parameter("flash"))
 _check(pose_unflashed and (maze.player.body.material==null or not maze.player.body.material.get_shader_parameter("flash")),"新受击不叠加全身白闪，水体仅沿已认可脚部染色")
 maze.capture_flow.set_process(false)
 visual.set_process(false)
 var saved_age: float=visual.age
 for sample in [[0.0,0],[0.04,1],[0.08,2],[0.12,3],[0.17,4],[0.21,5]]:
  visual.age=sample[0]
  visual._render()
  _check(visual.effect_frame==sample[1],"按230毫秒六帧时间轴取图："+kind+str(sample[1]))
  RenderingServer.force_draw(false)
  var shown: Image=viewport.get_texture().get_image()
  shown.save_png(output+"/"+kind+"_actual_frame_"+str(sample[1])+"_"+str(viewport.size.x)+".png")
  visual.effect.hide()
  RenderingServer.force_draw(false)
  var hidden: Image=viewport.get_texture().get_image()
  _check(shown.get_data()!=hidden.get_data(),"实际游戏倍率可见，不只存在图集数据："+kind+str(sample[1]))
 visual.age=saved_age
 visual._render()
 visual.set_process(true)
 maze.capture_flow.set_process(true)
 _check(visual.effect.get_parent()==visual and visual.get_parent()==maze.player,"特效与人物使用同一移动父层，不漂离受击者")
 _check(visual.effect.scale.x>0,"当前左侧来向及向下砸击保持已确认方向")
 _check(await until_true(func(): return not visual.active(),1.1),"按招式600或900毫秒人物受击恢复时长有界")
 _check(not visual.active() and not visual.effect.visible and not visual.pose.visible,"受击结束清除两层并恢复原人物")
 _check(not maze.player.input_locked and maze.player.body.visible,"动作结束不残留输入锁或隐藏正常人物")

func direction_and_pause() -> void:
 var visual: Node=maze.capture_flow.player_hurt_visual
 for kind in ["fish","electric","water"]:
  await begin_hurt(kind,Vector2.RIGHT,-1.0)
  _check(visual.effect.visible and visual.effect.scale.x<0,"右侧来向反转贴身特效："+kind)
  _check(visual.pose.visible and not maze.player.body.visible and maze.player.facing==Vector2.RIGHT,"侧向使用已认可专用受击动作，保留逻辑朝向且不叠双人物")
  await get_tree().create_timer(0.32).timeout
 await begin_hurt("slam",Vector2.UP,-1.0)
 _check(visual.effect.scale.x>0 and visual.pose.visible and not maze.player.body.visible and maze.player.facing==Vector2.UP,"背向使用已认可专用受击动作，砸击特效始终向下")
 await get_tree().create_timer(0.32).timeout
 await begin_hurt("water")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded and visual.active(),"实际受击期间打开原地图暂停")
 var age: float=visual.age
 var hp: float=state().combat.hp
 var recovery: float=state().combat.get("hurt_recovery_left",0.0)
 await get_tree().create_timer(0.35).timeout
 _check(visual.age==age and state().combat.hp==hp and visual.pose.visible and not maze.player.body.visible and not maze.capture_flow.skill_visual.hero.visible,"地图暂停冻结受击时间且不露出双人物")
 _check(state().combat.get("hurt_recovery_left",0.0)==recovery,"地图暂停同样冻结实际控制恢复时钟")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return not visual.active(),0.8),"关闭地图后600毫秒受击正常续播并清理")
 _check(maze.player.body.visible and not visual.effect.visible,"暂停恢复后正常人物可见")

func moving_and_attacking() -> void:
 var visual: Node=maze.capture_flow.player_hurt_visual
 await begin_hurt("fish")
 var start: Vector2=maze.player.position
 Input.action_press("ui_down")
 _check(await until_true(func(): return float(state().combat.get("hurt_recovery_left",0.0))<=0.15,0.65),"真实战斗连续推进到受击450毫秒后")
 _check(float(state().combat.get("hurt_recovery_left",0.0))>0.0 and maze.player.position.distance_to(start)<0.01 and not maze.player.input_locked,"超过旧400毫秒仍停止主动行走，不占用通用输入锁")
 _check(visual.active() and visual.pose.visible and not visual.effect.visible,"450毫秒后保留受击姿态，但230毫秒接触图已经清除")
 var mid_throws: int=state().combat.throws
 await click()
 _check(state().combat.throws==mid_throws,"450毫秒后真实左键仍不能出招")
 _check(visual.effect.global_position.distance_to(visual.to_global(visual.effect.position))<0.001,"移动后特效继续贴着玩家水中显示层而不是停在世界接触点")
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return float(state().combat.get("hurt_recovery_left",0.0))<=0.0,0.7),"真实战斗推进受击恢复倒计时")
 var restored: Vector2=maze.player.position
 _check(await until_true(func(): return maze.player.position.distance_to(restored)>2.0,0.3),"恢复后继续读取当前持有方向，不重按也能行走")
 release_move()
 await begin_hurt("fish")
 var throws: int=state().combat.throws
 await click()
 _check(state().combat.throws==throws and visual.active(),"真实左键在受击恢复期不能发出新攻击")
 _check(visual.pose.visible and not maze.player.body.visible and not maze.capture_flow.skill_visual.hero.visible,"正面受击期间只显示一层人物")
 _check(await until_true(func(): return not visual.active() and float(state().combat.get("hurt_recovery_left",0.0))<=0.0,0.7),"受击结束正常清理并恢复控制")
 await click()
 _check(state().combat.throws==throws+1,"恢复后新左键正常攻击，不残留控制锁")
 await get_tree().create_timer(0.4).timeout
 _check(maze.player.body.visible and not maze.capture_flow.skill_visual.hero.visible,"恢复后的新出招结束正常显示人物")
 # 两次真实命中，第二次沿原伤害规则结算，只替换显示而不堆叠人物。
 await begin_hurt("fish")
 var received: int=visual.received
 maze.capture_flow.set_process(false)
 seed_hurt("water")
 maze.capture_flow.combat_time=0.0
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return visual.received>received,0.5),"连续攻击仍由第二次真实扣血触发")
 _check(visual.kind=="water" and visual.get_child_count()==2,"连续受击用最新短效替换，不累积图层")
 _check(await until_true(func(): return not visual.active(),0.8),"连续受击600毫秒结束无残留")
 _check(not visual.effect.visible and not visual.pose.visible,"连续受击结束两层均清理")

func slam_recovery() -> void:
 var visual: Node=maze.capture_flow.player_hurt_visual
 await begin_hurt("slam")
 _check(await until_true(func(): return float(state().combat.get("hit_remaining",0.0))<=0.0,0.3),"巨蛙落地先按原时长完成击退，不把击退延长到900毫秒")
 var start: Vector2=maze.player.position
 Input.action_press("ui_down")
 _check(await until_true(func(): return float(state().combat.get("hurt_recovery_left",0.0))<=0.2,0.9),"真实落地受击连续推进到700毫秒后")
 _check(float(state().combat.get("hurt_recovery_left",0.0))>0.0 and maze.player.position.distance_to(start)<0.01,"落地受击超过普通600毫秒后仍不能主动移动")
 _check(visual.active() and visual.pose.visible and not visual.effect.visible,"落地900毫秒恢复保留现有姿态，不延长230毫秒接触图")
 var throws: int=state().combat.throws
 await click()
 _check(state().combat.throws==throws,"落地受击700毫秒后真实左键仍禁攻")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 var recovery: float=state().combat.get("hurt_recovery_left",0.0)
 var age: float=visual.age
 await get_tree().create_timer(0.25).timeout
 _check(maze.map_ui.expanded and state().combat.get("hurt_recovery_left",0.0)==recovery and visual.age==age,"900毫秒落地恢复在原地图暂停中同时冻结逻辑与动作")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return not visual.active() and float(state().combat.get("hurt_recovery_left",0.0))<=0.0,0.6),"关闭地图后900毫秒落地恢复正常结束")
 var restored: Vector2=maze.player.position
 _check(await until_true(func(): return maze.player.position.distance_to(restored)>2.0,0.3),"900毫秒结束后持有方向重新生效")
 release_move()
 await click()
 _check(state().combat.throws==throws+1,"900毫秒结束后新的真实左键可攻击")

func failure_and_cleanup() -> void:
 var visual: Node=maze.capture_flow.player_hurt_visual
 setup(HURT_POINT)
 visual.clear()
 seed_hurt("fish")
 var path: String=sm._active_save_path
 var received: int=visual.received
 var hp: float=state().combat.hp
 sm._active_save_path=""
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return maze.capture_flow.save_retry_delay>0.0,0.5),"真实战斗保存失败进入既有重试等待")
 _check(state().combat.hp==hp and visual.received==received and not visual.active(),"真实场景保存失败不扣血且不误播新受击")
 sm._active_save_path=path
 _check(await until_true(func(): return visual.received>received,1.8),"恢复保存后沿既有重试正常播放真实命中")
 # 有效受击后离开显示树；同一节点重进不能重放旧图。
 maze.player.hide()
 _check(not visual.active() and not visual.effect.visible and not visual.pose.visible,"玩家隐藏立即清理两层")
 maze.player.show()
 await get_tree().process_frame
 _check(not visual.active(),"重新显示不重播已清理受击")
 # 原规则禁止战斗中换区；不放宽门禁来制造离图受击。
 await begin_hurt("water")
 maze.capture_flow.set_process(false)
 var blocked:=Run.change_region(sm,"maze_entry",Roads.SPAWN)
 _check(not blocked.success and blocked.reason=="in_combat" and visual.active(),"原换区战斗限制保持，不把失败换区当作已离图")
 await get_tree().create_timer(0.32).timeout
 setup(SAFE)
 _check(Run.change_region(sm,"maze_entry",Roads.SPAWN).success,"合法非交战检查点通过真实区域事务离开分水庭")
 _check(await until_true(func(): return not visual.active(),0.2),"离图后不让旧受击继续播放")
 _check(Run.change_region(sm,"fenshui",HURT_POINT).success,"原区域事务重新进入分水庭")
 await get_tree().process_frame
 _check(not visual.active(),"重新入图不重放旧受击")
 # 回到同一正式场景检查点，生命归零沿原失败流程处理。
 setup(HURT_POINT)
 maze.capture_flow.save_retry_delay=0.0
 visual.clear()
 seed_hurt("fish")
 sm.data[Run.KEY].combat.hp=1.0
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return state().combat.hp<=0.0,0.6),"原真实攻击可正常击败玩家")
 await get_tree().process_frame
 _check(not visual.active() and not visual.pose.visible and not visual.effect.visible,"致死伤害不残留新动作或贴身特效")
 _check(state().combat.get("hurt_recovery_left",0.0)==0.0,"致死伤害清除受击恢复状态")
