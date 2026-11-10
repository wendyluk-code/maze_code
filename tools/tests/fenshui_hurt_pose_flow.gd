extends "res://tools/tests/fenshui_player_hurt_flow.gd"
## 针对真实扣血后的持续痛态、可见体型与脚底标定；不使用网页模拟。
const HeroAppearance=preload("res://scripts/characters/hero_animation.gd")

func battle() -> void:
 if _arg("--phase=")=="1152": viewport.size=Vector2i(1152,648)
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"痛态回归使用真实七怪入口")
 var visual: Node=maze.capture_flow.player_hurt_visual
 if visual.has_method("enable_refined_pose"): visual.enable_refined_pose()
 if _arg("--phase=")=="clock":
  await recovery_clock()
  return
 for kind in ["fish","slam"]:
  await begin_hurt(kind)
  _check(await until_true(func(): return visual.age>=0.30,0.8),"正常连续播放到接触图消失之后："+kind)
  _check(visual.pose_frame==1 and visual.pose.visible,"硬直中保持闭眼绷紧帧，不能长保持微笑待机："+kind,{"frame":visual.pose_frame,"age":visual.age})
  var normal:=bounds(HeroAppearance.ANIMATIONS.get_frame_texture(&"front_idle",0))
  var hurt:=bounds(visual.pose.texture)
  var body: Sprite2D=maze.player.body
  var normal_height: float=normal.size.y*absf(body.scale.y)
  var reference:=bounds(visual.sheets.hero[0])
  var expected_scale: float=normal_height/reference.size.y
  _check(absf(absf(visual.pose.scale.y)-expected_scale)<0.001,"所有受击帧沿参考身体唯一比例，不逐帧拉伸也不按整格猜大小",{"expected":expected_scale,"actual":visual.pose.scale.y,"visible_height":hurt.size.y*absf(visual.pose.scale.y)})
  var normal_foot: float=(body.offset.y+normal.end.y)*body.scale.y
  var hurt_foot: float=visual.pose.position.y+(visual.pose.offset.y+hurt.end.y)*visual.pose.scale.y
  _check(absf(normal_foot-hurt_foot)<1.5,"痛态脚底不漂浮",{"normal":normal_foot,"hurt":hurt_foot})
  await picture(kind+"_held_pose")
  if failures: return
  _check(await until_true(func(): return not visual.active(),1.0),"持续痛态随实际600/900毫秒恢复结束")
  _check(maze.player.body.visible and not visual.pose.visible,"结束恢复正常人物，不延长控制锁")
 await recovery_clock()
 if failures: return
 for kind in ["water","slam"]:
  for facing in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
   await direction_pose(kind,facing)
   if failures: return

func direction_pose(kind: String, facing: Vector2) -> void:
  var visual: Node=maze.capture_flow.player_hurt_visual
  await begin_hurt(kind,facing)
  _check(await until_true(func(): return visual.age>=0.30,0.8),"侧背连续播放到接触图消失之后")
  _check(visual.pose.visible and not visual.effect.visible and visual.pose_frame==2,"侧背真实新图保持痛态直到恢复尾段")
  var row: int=0 if facing==Vector2.LEFT else (1 if facing==Vector2.RIGHT else 2)
  _check(visual.pose.texture.atlas.resource_path.ends_with("three_directions_v1.png") and visual.pose.texture.region.position==Vector2(724,row*362),"真实受击选择正确方向和持痛帧")
  _check(maze.player.facing==facing and not maze.player.body.visible,"受击显示不改逻辑朝向且无双人物")
  await picture(kind+"_hurt_"+str(facing))
  if failures: return
  await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
  var age: float=visual.age
  await get_tree().create_timer(0.2).timeout
  _check(maze.map_ui.expanded and visual.age==age and visual.pose.visible,"侧背持续姿态在地图暂停中冻结")
  await key(KEY_ESCAPE)
  _check(await until_true(func(): return not visual.active(),0.8),"关闭暂停后侧背正常恢复")
  _check(maze.player.body.visible and not visual.pose.visible,"侧背结束无隐藏人物或残留变换")

func recovery_clock() -> void:
 var visual: Node=maze.capture_flow.player_hurt_visual
 await begin_hurt("fish")
 _check(await until_true(func(): return visual.age>=0.15,0.6),"真实受击推进后检查事务与显示同钟")
 maze.capture_flow.set_process(false)
 var age: float=visual.age
 var left: float=state().combat.hurt_recovery_left
 await get_tree().create_timer(0.15).timeout
 _check(state().combat.hurt_recovery_left==left and is_equal_approx(visual.age,age),"战斗事务没有推进时，痛态不得独立走完而提前露出待机",{"age_before":age,"age_after":visual.age,"recovery":left})
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return not visual.active(),0.8),"事务恢复后，痛态与实际硬直一起结束")

func bounds(texture: Texture2D) -> Rect2i:
 var image:=texture.get_image()
 var low:=Vector2i(image.get_width(),image.get_height())
 var high:=Vector2i(-1,-1)
 for y in image.get_height():
  for x in image.get_width():
   if image.get_pixel(x,y).a<0.5: continue
   low.x=mini(low.x,x)
   low.y=mini(low.y,y)
   high.x=maxi(high.x,x)
   high.y=maxi(high.y,y)
 return Rect2i(low,high-low+Vector2i.ONE)
