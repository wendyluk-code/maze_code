extends "res://tools/tests/fenshui_frog_navigation_flow.gd"
const SAFE=Vector2(920,782)
const FISH="fenshui_silverfish_1"
const HIT_HERO=Vector2(1050,455)

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"真实七怪入口正常解锁")
 var flow: Node=maze.capture_flow
 _check(flow.monsters[Boss.ID].get("heal_visual")!=null,"真实巨蛙安装恢复水光消费者")
 _check(flow.monsters["fenshui_silverfish_1"].get("hit_visual")!=null,"正式鱼节点安装差异命中消费者")
 if failures: return
 _check(flow.monsters[Boss.ID].enable_frog_front24(),"使用统一版1.4倍双前向身体")
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=resolution
  for slot in [0,1,2]:
   await actual_hit(slot,false,resolution.x)
   if failures: return
 for slot in [0,1,2]:
  await actual_hit(slot,true,1280)
  if failures: return
 for target in ["fenshui_thunder_eel_2",Boss.ID]:
  for slot in [0,1,2]:
   for protected in [true,false]:
    await actual_hit(slot,protected,1280,target,Vector2(1040,595) if target.contains("thunder_eel") else Vector2(880,490))
    if failures: return
 await healing()
 if failures: return
 await healing_attack()
 if failures: return
 await water_combat_healing()

func water_combat_healing() -> void:
 var hero:=Vector2(1090,450)
 setup(hero)
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.position=[1040.0,450.0]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.hp=48.0
 a.frog_phase="active"
 a.mode="chase"
 a.frog_left=1.2
 a.cooldown=10.0
 a.frog_heal_quiet=0.0
 _check(Run.valid(state()) and Boss.water(hero),"真实七怪水中交战恢复检查点合法")
 maze.capture_flow.set_process(true)
 await key(KEY_SPACE)
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==Boss.ID: break
 _check(maze.capture_flow.locked_target_id==Boss.ID,"水中交战通过真实Tab锁定巨蛙")
 var visual: Node=maze.capture_flow.monsters[Boss.ID].heal_visual
 _check(await until_true(func(): return visual.active and actor().hp>48.0 and actor().mode=="chase",2.8),"玩家仍在水中交战，2秒未受击即真实回血并显示水光")
 if failures: return
 # 只为同状态双分辨率取图暂时停止事务；恢复条件来自此前真实运行。
 maze.capture_flow.set_process(false)
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=resolution
  await picture("combat_healing_"+str(resolution.x))
 maze.capture_flow.set_process(true)
 var hits: int=state().combat.hits
 await click()
 _check(await until_true(func(): return state().combat.hits>hits and actor().frog_heal_quiet==0.0,1.0),"真实水中交战左键命中清零回血计时")
 _check(not visual.active,"交战中的有效受击仍关闭恢复水光")
 await picture("combat_healing_hit")

func healing_attack() -> void:
 var shore:=Vector2(394.5697,291.7372)
 var target:=Vector2(416,240)
 setup(shore)
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.position=[target.x,target.y]
 a.frog_origin=a.position.duplicate()
 a.frog_target=a.position.duplicate()
 a.hp=48.0
 a.frog_phase="dormant"
 a.mode="idle"
 a.frog_heal_quiet=2.0
 _check(Run.valid(state()) and not Boss.water(shore),"真实七怪干岸攻击使用合法受伤恢复检查点")
 maze.capture_flow.set_process(true)
 var visual: Node=maze.capture_flow.monsters[Boss.ID].heal_visual
 _check(await until_true(func(): return visual.active,1.0),"岸上攻击前巨蛙实际正在回血并显示水光")
 await key(KEY_SPACE)
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==Boss.ID: break
 _check(maze.capture_flow.locked_target_id==Boss.ID,"真实Tab能够锁定已受伤的恢复待机巨蛙")
 var hits: int=state().combat.hits
 await click()
 _check(await until_true(func(): return state().combat.hits>hits and actor().frog_heal_quiet==0.0,1.0),"真实内部左键有效命中清零计时，不把飞行前已恢复生命当成命中无效")
 _check(not visual.active,"实际受击扣血当帧停止恢复水光")
 await picture("healing_hit_from_shore")

func setup(point: Vector2) -> void:
 maze.capture_flow.set_process(false)
 sm.data=entry_snapshot.duplicate(true)
 maze.capture_flow.combat_time=0.0
 maze.capture_flow.locked_target_id=""
 sm.data[Run.KEY].combat.hero=[point.x,point.y]
 sm.data[Run.KEY].combat.cooldown=0.0
 maze.player.position=point
 maze.camera.snap_to_target()
 for monster in maze.capture_flow.monsters.values():
  monster.hit_visual.clear()
  if monster.heal_visual!=null: monster.heal_visual.clear()
  monster.set_process(true)
 maze.capture_flow.window_focused=true

func actual_hit(slot: int,protected: bool,width: int,target: String=FISH,hero: Vector2=HIT_HERO) -> void:
 setup(hero)
 var a: Dictionary=sm.data[Run.KEY].combat.actors[target]
 var hp_before:=float(a.hp)
 a.electric_left=0.0 if protected else 4.0
 if target==FISH:
  a.fish_origin=a.position.duplicate()
  a.fish_aim=[0.0,1.0]
  a.fish_hit=false
  Run.Combat.Silverfish.phase(a,"recover",2.5)
 elif target.contains("thunder_eel"):
  a.eel_origin=a.position.duplicate()
  a.eel_path=[]
  Run.Combat.ThunderEel.phase(a,"charging" if protected else "forming",1.0)
 else:
  a.frog_phase="active"
  a.frog_left=0.0
  a.frog_origin=a.position.duplicate()
  a.frog_target=a.position.duplicate()
  a.frog_jump=6.0
  a.cooldown=2.0
 _check(Run.valid(state()) and Run.Combat.terrain("fenshui").is_walkable(hero),"真实七怪命中检查点有效："+target)
 var shielded: bool=Run.Combat.Silverfish.shielded(state().combat,target) or Run.Combat.ThunderEel.shielded(state().combat,target) or Run.Combat.Skills.FrogCounter.shielded(state().combat,target)
 _check(shielded==protected,"命中前检查点保护状态与本例一致："+target+str(protected))
 var monster: Node=maze.capture_flow.monsters[target]
 var visual: Node=monster.hit_visual
 _check(visual.get("watercolor_sheet") is Texture2D and visual.watercolor_frames[["hero","yaya","tieshan"][slot]] is AtlasTexture,"实际生产命中使用原水彩切片而非程序替代："+target+str(slot))
 var received: int=visual.received
 maze.capture_flow.set_process(true)
 await get_tree().process_frame
 await key(KEY_SPACE if slot==0 else (KEY_1 if slot==1 else KEY_2))
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==target: break
 _check(maze.capture_flow.locked_target_id==target,"真实Tab锁定测试魔物，不直接指定目标："+target)
 var observation: Dictionary={"deformed":false}
 var sample:=func():
  if visual.received<=received or observation.deformed: return
  var stretch: Vector2=monster.body.material.get_shader_parameter("impact_scale")
  if not stretch.is_equal_approx(Vector2.ONE):
   observation.deformed=true
   observation.age=visual.reaction_age
   observation.scale=str(stretch)
   RenderingServer.force_draw(false)
   viewport.get_texture().get_image().save_png(output+"/"+["spatula","yaya","axe"][slot]+"_reaction_"+str(width)+".png")
 get_tree().process_frame.connect(sample)
 await click()
 _check(await until_true(func(): return visual.received>received,1.0),"真实左键及原弹道/近战产生反馈："+str(slot))
 _check(state().combat.actors[target].hp<hp_before,"反馈对应实际生命减少："+target)
 if failures:
  get_tree().process_frame.disconnect(sample)
  return
 if protected:
  _check(not visual.effects.is_empty(),"有膜的有效命中仍显示已认可接触图形："+str(slot))
  _check(visual.reaction_kind.is_empty() and monster.membrane.visible and monster.body.material.get_shader_parameter("impact_scale")==Vector2.ONE,"保护膜保留、身体不挤压，不以取消保护恢复命中可见性")
  _check(not monster.body.material.get_shader_parameter("flash"),"保护命中不恢复全身白闪")
 else:
  _check(not visual.effects.is_empty() and visual.reaction_kind==["hero","yaya","tieshan"][slot],"真实消费者选择对应武器图形与受击显示")
  if target.contains("thunder_eel"):
   _check(monster.membrane.visible and not Run.Combat.ThunderEel.shielded(state().combat,target) and monster.membrane.modulate.a<1.0,"雷鳗凝膜逐渐可见但完成前仍不减伤，沿原规则")
  else:
   _check(not monster.membrane.visible,"破膜时去除保护外观")
  _check(not monster.body.material.get_shader_parameter("flash"),"新命中不叠加全身白闪")
  await get_tree().create_timer(0.035).timeout
  await get_tree().process_frame
  var deform: Vector2=monster.body.material.get_shader_parameter("impact_scale")
  trace.append({"kind":slot,"reaction_age":visual.reaction_age,"reaction_kind":visual.reaction_kind,"scale":str(deform),"effects":visual.effects.duplicate(true)})
  _check(observation.deformed,"显示层短促形变已生效，非延长卡肉",observation.duplicate(true))
  _check(monster.position.distance_to(Run.Combat.vec(state().combat.actors[target].position))<0.01,"命中显示不移动实际脚底")
 var tag: String=("protected_" if protected else "")+["spatula","yaya","axe"][slot]+"_"+str(width)+("" if target==FISH else "_"+target)
 if not visual.effects.is_empty():
  # 仅静态前后取证冻结此实例；显隐后等待绘制周期，避免把渲染线程旧帧当结果。
  var mode: int=maze.process_mode
  maze.process_mode=Node.PROCESS_MODE_DISABLED
  await get_tree().process_frame
  visual.hide()
  await get_tree().process_frame
  RenderingServer.force_draw(false)
  var without: Image=viewport.get_texture().get_image()
  visual.show()
  await get_tree().process_frame
  RenderingServer.force_draw(false)
  var with_contact: Image=viewport.get_texture().get_image()
  _check(without.get_data()!=with_contact.get_data(),"实际视口接触图形可见，不只创建了隐藏数据："+tag)
  without.save_png(output+"/without_contact_"+tag+".png")
  with_contact.save_png(output+"/"+tag+".png")
  maze.process_mode=mode
 else:
  await picture(tag)
 get_tree().process_frame.disconnect(sample)
 if not protected and slot==0 and width==1152:
  await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
  _check(maze.map_ui.expanded,"命中期间打开原地图")
  var age: float=visual.reaction_age
  var hp: float=state().combat.actors[FISH].hp
  await get_tree().create_timer(0.18).timeout
  _check(visual.reaction_age==age and state().combat.actors[FISH].hp==hp,"地图暂停冻结短效、形变与战斗")
  await key(KEY_ESCAPE)
 await get_tree().create_timer(0.4).timeout
 _check(visual.effects.is_empty() and visual.reaction_kind.is_empty() and monster.body.material.get_shader_parameter("impact_scale")==Vector2.ONE,"反馈结束自动清理并恢复原身体显示")
 _check(maze.capture_flow.monsters.size()==7 and Run.valid(state()),"反馈期间鱼鳗巨蛙继续正常七怪战斗")

func healing() -> void:
 setup(SAFE)
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.hp=48.0
 a.frog_origin=a.position.duplicate()
 a.frog_target=[1040.0,450.0]
 a.frog_phase="warning"
 a.frog_left=0.15
 a.mode="chase"
 _check(Run.valid(state()) and Boss.jump_line(Boss.HOME,Vector2(1040,450)),"受伤七怪起跳检查点和非中央水面落点合法")
 maze.capture_flow.set_process(true)
 var visual: Node=maze.capture_flow.monsters[Boss.ID].heal_visual
 _check(await until_true(func(): return actor().frog_phase=="airborne",1.5),"玩家已上岸时完成原跳跃，不突然在空中停住")
 _check(actor().hp==48.0 and not visual.active,"脱战腾空仍不回血或播放恢复水光")
 _check(await until_true(func(): return actor().frog_phase=="dormant",3.0),"真实落地后在非中央水面进入恢复待机")
 _check(Run.Combat.vec(actor().position).distance_to(Vector2(1040,450))<0.01 and actor().hp==48.0,"落稳后才等待安静，不回中央或瞬满")
 _check(await until_true(func(): return visual.active and actor().hp>48.0,2.6),"正式七怪中非中央落稳安静后实际回血并开始水光")
 for resolution in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=resolution
  # 仅镜头观察当前合法恢复点，玩家仍留在同一安全岸路。
  maze.camera.set_process(false)
  maze.camera.position=Run.Combat.vec(actor().position)
  maze.camera.force_update_scroll()
  await picture("healing_"+str(resolution.x))
 maze.camera.set_process(true)
 maze.camera.snap_to_target()
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"回血中真实打开地图")
 var hp: float=actor().hp
 var clock: float=visual.clock
 var quiet: float=actor().frog_heal_quiet
 await get_tree().create_timer(0.3).timeout
 _check(actor().hp==hp and actor().frog_heal_quiet==quiet and visual.clock==clock,"暂停冻结真实回血、安静时钟及恢复水光")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return actor().hp>hp,1.0),"关闭地图后真实回血继续")
 for point in [Vector2(840,746),Vector2(836,739),Vector2(857,659),Vector2(881,594),Vector2(880,565),Vector2(880,490)]:
  _check(await walk_to(point,6.0),"真实内部移动重新进入水域："+str(point))
  if failures: return
 _check(await until_true(func(): return actor().mode=="chase",2.0),"实际重新入水仍正常追击，不因新回血规则停战")
 await picture("water_chase_resumed")
