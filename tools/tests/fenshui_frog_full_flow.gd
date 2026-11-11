extends "res://tools/tests/fenshui_frog_counter_flow.gd"
var base: Dictionary

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"整套四向从真实七怪地图启动")
 base=entry_snapshot.duplicate(true)
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(frog.frog_motion_direction==-1,"正式巨蛙默认自动四向，不固定候选方向")
 for direction in 4:
  maze.capture_flow.set_process(false)
  sm.data=base.duplicate(true)
  maze.player.position=Boss.HOME+Vector2(-45 if direction in [1,3] else 45,-35 if direction in [2,3] else 35)
  maze.camera.snap_to_target()
  maze.capture_flow.window_focused=true
  maze.capture_flow.set_process(true)
  _check(await until_true(func(): return actor().frog_phase=="airborne",6.0),"四侧自然起跳："+str(direction))
  _check(frog.facing==direction,"实际身体节点面向该侧玩家："+str(direction))
  var expected: String=["frog-v3","front-left","back-right","back-left"][direction]
  _check(frog.body.texture==frog.frog_motion.textures[3] if direction==0 else (frog.body.texture is AtlasTexture and frog.body.texture.atlas.resource_path.contains(expected)),"腾空消费该方向完整原图："+str(direction))
  await picture("direction_"+str(direction)+"_air")
  _check(await until_true(func(): return actor().frog_phase=="landing"),"不攻击可自然落地："+str(direction))
  _check(frog.frame_index() in [15,16,17],"普通落地消费撑地恢复链")
  await picture("direction_"+str(direction)+"_landing")
  await get_tree().create_timer(0.2).timeout
  maze.player.position=Run.Combat.vec(actor().position)+Vector2(-7 if direction in [1,3] else 7,-7 if direction in [2,3] else 7)
  _check(Boss.line(Run.Combat.vec(actor().position),maze.player.position),"吐水四侧前置在巨蛙实际合法落点的连续浅水内")
  _check(await until_true(func(): return actor().mode=="windup",5.0),"落地后自然吐水蓄势")
  _check(frog.body.texture==frog.action_sheets.attack,"吐水蓄势显示原攻击图而非蹲姿")
  _check(frog.facing==direction and int(frog.body.region_rect.position.y/192)==direction,"吐水真实瞄准四侧玩家并消费对应方向行",{"case_direction":direction,"body_direction":frog.facing,"frog_aim":actor().frog_aim,"hero":str(maze.player.position),"frog":actor().position,"hero_hit_remaining":state().combat.hit_remaining})
  # 避开已锁向的水团，保留规则与实际发射事件。
  maze.player.position+=Vector2(40,20)
  _check(await until_true(func(): return float(actor().get("frog_spit_left",0.0))>0.14,2.0),"实际发射后出现释放帧")
  _check(frog.body.texture==frog.action_sheets.attack and int(frog.body.region_rect.position.x/192)==2,"水团生成与释放身体帧同步")
  await picture("direction_"+str(direction)+"_spit")
  check_water_mouth(frog,direction)
  _check(await until_true(func(): return float(actor().get("frog_spit_left",0.0))>0 and float(actor().get("frog_spit_left",0.0))<=0.14,1.0),"释放后进入原收势图")
  _check(int(frog.body.region_rect.position.x/192)==3,"收势消费第4帧，不延长规则阶段")
  maze.capture_flow.set_process(false)
  sm.data=base.duplicate(true)
  maze.player.position=Boss.HOME+Vector2(-45 if direction in [1,3] else 45,-35 if direction in [2,3] else 35)
  maze.capture_flow.set_process(true)
  _check(await until_true(func(): return actor().frog_phase=="airborne",5.0),"四向反击前自然腾空")
  await key(KEY_SPACE)
  await click()
  _check(await until_true(func(): return actor().frog_phase=="toppling",1.0),"四向均由实际命中触发翻落")
  _check(await until_true(func(): return actor().frog_phase=="exposed",2.0),"四向翻落进入露腹")
  _check(frog.facing==direction and not frog.membrane.visible,"四向露腹保向并取消膜")
  await picture("direction_"+str(direction)+"_counter")
  _check(await until_true(func(): return actor().frog_phase=="recovering",4.0),"四向露腹到期正常起身")
  await picture("direction_"+str(direction)+"_rise")
  if failures: break
 # 原真实左键反击、露腹、暂停恢复仍须通过自动方向。
 maze.capture_flow.set_process(false)
 sm.data=base.duplicate(true)
 maze.player.position=Vector2(880,490)
 maze.capture_flow.set_process(true)
 if failures==0: await super.battle()

func bubble_center(frog: Node2D) -> Vector2:
 return super.bubble_center(frog)

func check_water_mouth(frog: Node2D, direction: int) -> void:
 # 原192格攻击图上的嘴／背向头部出口标定点，不以显示器实现常量回填答案。
 var pixel: Vector2=[Vector2(132,83),Vector2(55,83),Vector2(129,55),Vector2(63,55)][direction]
 var expected_offset: Vector2=frog.body.position+(frog.body.offset+pixel)*frog.body.scale
 var shots: Array=actor().frog_shots
 var visual: Node
 for child in maze.get_children():
  if child.get_script()!=null and child.get_script().resource_path=="res://scripts/maze/wind_frog_visual.gd": visual=child
 _check(visual!=null and not shots.is_empty(),"原真实水团显示节点及实际发射仍存在")
 if visual==null or shots.is_empty(): return
 var index:=shots.size()-1
 var actual_offset: Vector2=visual.pool[index].position-Run.Combat.vec(shots[index].position)
 _check(actual_offset.distance_to(expected_offset)<1.0,"水团显示从当前方向嘴／头部出口发出，不从后腿发出",{"direction":direction,"actual":str(actual_offset),"expected":str(expected_offset)})
