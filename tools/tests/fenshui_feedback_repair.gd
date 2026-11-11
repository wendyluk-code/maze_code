extends "res://tools/tests/fenshui_player_hurt_flow.gd"
const HeroAppearance=preload("res://scripts/characters/hero_animation.gd")
var splash: Node2D

func seed_hurt(kind: String, side: float=1.0) -> void:
 super.seed_hurt(kind,side)
 if kind=="fish" and side>0.0:
  # 本检查验证受击显示，不以一次接近18像素边界的冲刺是否擦空作为前置。
  # 从合法的18像素接触点走原冲撞入口；仍由真实伤害事务决定是否触发。
  var fish: Dictionary=sm.data[Run.KEY].combat.actors[FISH]
  fish.position=[1072.0,450.0]
  fish.fish_origin=fish.position.duplicate()

func battle() -> void:
 if _arg("--phase=")=="1152": viewport.size=Vector2i(1152,648)
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"返修从真实七怪入口开始")
 var entry: Node=load("res://tools/previews/fenshui_feedback_play.gd").new()
 entry.maze=maze
 _check(entry._prepare_frog(),"实际候选入口安装受击及水花")
 splash=entry.splash
 entry.free()
 if _arg("--phase=")=="crowd":
  await crowd()
  return
 if _arg("--phase=")=="splash":
  await splash_geometry()
  return
 if _arg("--phase=").begins_with("water"):
  await water_alignment()
  return
 if _arg("--phase=")=="crowd-live":
  await crowd_live()
  return
 if _arg("--phase=")=="frozen":
  await moving_pose_freeze()
  return
 var visual: Node=maze.capture_flow.player_hurt_visual
 for facing in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
  await begin_hurt("fish",facing)
  var normal: Rect2=visual._opaque_bounds(maze.player.body.texture)
  var normal_size: Vector2=normal.size*maze.player.body.scale
  var start: Vector2=maze.player.position
  Input.action_press("ui_down")
  _check(await until_true(func(): return visual.age>=0.30,0.8),"实际硬直连续推进到300毫秒")
  var b: Rect2=visual._opaque_bounds(visual.pose.texture)
  var size: Vector2=b.size*visual.pose.scale
  trace.append({"facing":str(facing),"normal_size":str(normal_size),"hurt_size":str(size),"frame":visual.pose_frame,"recovery":state().combat.hurt_recovery_left})
  _check(visual.pose.visible and not maze.player.body.visible,"硬直中保持唯一人物姿态")
  _check(size.y<=normal_size.y*1.05 and size.y>=normal_size.y*0.90,"受击可见身体高度保持正常体型，不突然放大或缩小",trace.back())
  _check(maze.player.position.distance_to(start)<0.1,"受击期间持续持键不能主动移动")
  var throws: int=state().combat.throws
  await click()
  _check(state().combat.throws==throws,"受击期间真实左键不能出招")
  await picture("hurt_"+str(facing))
  _check(await until_true(func(): return not visual.active(),0.8),"硬直显示按实际倒计时结束")
  release_move()
  await click()
  _check(state().combat.throws==throws+1,"无后续伤害时硬直结束可重新攻击")

func splash_geometry() -> void:
 setup(HURT_POINT)
 var frog: Node=maze.capture_flow.monsters[Boss.ID]
 # Q9：正式落地按实际伤害直径；起跳和旧独立消费者仍按原体型比例。
 var body_width: float=148.0/192.0*float(frog.config.width)*1.4
 for type in ["takeoff","landing"]:
  splash._begin(type,Vector2(1040,450))
  splash.age=0.15 if type=="takeoff" else 0.27
  splash._render()
  var actual: float=splash.back.scale.x*float(splash._peaks[type])
  var expected: float=body_width*(105.0 if type=="takeoff" else 330.0)/132.0
  if type=="landing" and splash.has_method("area_snapshot"):
   expected=preload("res://scripts/maze/fenshui_electric_area.gd").radius(Boss.ID+"_slam")*2.0
  _check(absf(actual-expected)<0.01,"水花按起跳体型或正式落地攻击直径标定："+type,{"actual":actual,"expected":expected,"frog":body_width})
  await picture(type)

func crowd() -> void:
 for target in [FISH,Boss.ID]:
  for slot in [0,1,2]:
   setup(Vector2(880,490))
   var c: Dictionary=sm.data[Run.KEY].combat
   c.actors[FISH].position=[880.0,471.5]
   c.actors[FISH].fish_origin=c.actors[FISH].position.duplicate()
   c.actors[FISH].fish_aim=[0.0,1.0]
   c.actors[FISH].fish_hit=false
   Run.Combat.Silverfish.phase(c.actors[FISH],"recover",2.5)
   c.actors[Boss.ID].position=[900.0,450.0]
   c.actors[Boss.ID].frog_origin=c.actors[Boss.ID].position.duplicate()
   c.actors[Boss.ID].frog_target=c.actors[Boss.ID].position.duplicate()
   c.actors[Boss.ID].frog_phase="active"
   c.actors[Boss.ID].frog_left=0.0
   c.actors[Boss.ID].frog_jump=6.0
   c.actors[Boss.ID].cooldown=8.0
   _check(Run.valid(state()),"两怪贴身检查点合法",{"fish_valid":Run.Combat.Silverfish.valid(c.actors[FISH]),"frog_valid":preload("res://scripts/maze/wind_frog_combat.gd").valid(c.actors[Boss.ID])})
   if failures: return
   maze.capture_flow.set_process(true)
   await key(KEY_SPACE if slot==0 else (KEY_1 if slot==1 else KEY_2))
   for i in 8:
    await key(KEY_TAB)
    if maze.capture_flow.locked_target_id==target: break
   _check(maze.capture_flow.locked_target_id==target,"贴身两怪可以通过Tab切到目标")
   var throws: int=state().combat.throws
   var hits: int=state().combat.hits
   var hp: float=state().combat.actors[target].hp
   await click()
   _check(state().combat.throws==throws+1,"两怪贴身真实左键仍接受招式",{"target":target,"slot":slot,"cooldown":state().combat.cooldown,"recovery":state().combat.get("hurt_recovery_left",0.0),"paused":maze.capture_flow.combat_paused()})
   _check(await until_true(func(): return state().combat.hits>hits,1.0),"两怪贴身的攻击实际命中，不只有出招计数",{"target":target,"slot":slot,"hp_before":hp,"hp_after":state().combat.actors[target].hp})
   await picture("crowd_"+target+str(slot))
   if failures: return

func water_alignment() -> void:
 var water: Node
 for child in maze.get_children():
  if child.get_script()!=null and child.get_script().resource_path=="res://scripts/maze/wind_frog_visual.gd": water=child
 _check(water!=null,"诊断复用真实水炮显示消费者")
 var visual: Node=maze.capture_flow.player_hurt_visual
 var bounds: Rect2=visual._opaque_bounds(HeroAppearance.ANIMATIONS.get_frame_texture(&"front_idle",0))
 var hero_center: Vector2=(bounds.get_center()-HeroAppearance.FRAME_FOOT)*maze.player.body.scale
 var frog: Node=maze.capture_flow.monsters[Boss.ID]
 for angle in [0.0,PI*0.25,PI*0.5,PI,PI*1.5,PI*1.75]:
  setup(HURT_POINT)
  var direction:=Vector2.RIGHT.rotated(angle)
  var origin:=Vector2(1030,450)
  var index: int=preload("res://scripts/maze/wind_frog_counter.gd").direction_for(direction)
  var offset: Vector2=frog.frog_front24.mouth_offset(index)
  var end: Vector2=origin+direction*60.0
  # 只读实验：让原图前端中心经过正式人物可见身体中心，不改变判定实现。
  var point: Vector2=end+offset-hero_center
  maze.player.position=point
  var c: Dictionary=sm.data[Run.KEY].combat
  c.hero=[point.x,point.y]
  c.actors[Boss.ID].frog_shots=[{"position":[origin.x,origin.y],"direction":[direction.x,direction.y],"distance":0.0}]
  water._process(0.0)
  var before: float=c.hp
  var events: Array=[]
  var run: Dictionary=sm.data[Run.KEY].duplicate(true)
  preload("res://scripts/maze/wind_frog_combat.gd").advance_projectiles(run,point,0.5,events)
  var detail: Dictionary={"angle":angle,"direction":str(direction),"mouth_offset":str(offset),"hero_center_offset":str(hero_center),"hero":str(point),"perpendicular_distance":absf((point-origin).cross(direction)),"water":Boss.water(point),"hit":run.combat.hp<before,"hp_before":before,"hp_after":run.combat.hp}
  trace.append(detail)
  _check(water.pool.size()>0 and water.pool[0].position.distance_to(origin+offset)<0.01,"实际水炮显示从嘴部偏移出发",detail)
  if _arg("--phase=")=="water-red":
   _check(bool(detail.hit),"画面前端经过身体中心时实际应当命中："+str(angle),detail)
  if _arg("--phase=")=="water-probe":
   var aligned: Dictionary=sm.data[Run.KEY].duplicate(true)
   var corrected: Vector2=origin+offset-hero_center
   aligned.combat.actors[Boss.ID].frog_shots[0].position=[corrected.x,corrected.y]
   var aligned_events: Array=[]
   preload("res://scripts/maze/wind_frog_combat.gd").advance_projectiles(aligned,point,0.5,aligned_events)
   detail.probe_hit=aligned.combat.hp<before
   _check(bool(detail.probe_hit),"仅在隔离实验对齐起点后命中恢复，不扩大20半径",detail)
  c.actors[Boss.ID].frog_shots[0].position=[end.x,end.y]
  c.actors[Boss.ID].frog_shots[0].distance=60.0
  water._process(0.0)
  _check(water.pool[0].position.distance_to(point+hero_center)<0.01,"图像前端经过人物实际身体中心，非仅擦过透明画布",detail)
  await picture("water_"+str(index)+"_"+str(angle))

func moving_pose_freeze() -> void:
 setup(HURT_POINT)
 var visual: Node=maze.capture_flow.player_hurt_visual
 visual.clear()
 Input.action_press("ui_right")
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return maze.player.animation_name==&"right_walk",0.4),"真实持键先让人物进入侧向行走")
 var walking: Texture2D=maze.player.body.texture
 var received: int=visual.received
 maze.capture_flow.set_process(false)
 seed_hurt("water")
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return visual.received>received,0.7),"侧向行走中被原水炮实际击中")
 _check(await until_true(func(): return visual.age>=0.3,0.7),"侧向行走受击后连续保持到300毫秒")
 _check(visual.pose.texture is AtlasTexture and visual.pose.texture.atlas.resource_path.ends_with("three_directions_v1.png") and visual.pose_frame==2,"侧向行走受击消费专用持续痛态，不继续行走或冻结普通身体",{"before":walking.atlas.resource_path,"after":visual.pose.texture.atlas.resource_path if visual.pose.texture is AtlasTexture else visual.pose.texture.resource_path})
 await picture("moving_hurt_held")
 maze.capture_flow.set_process(false)
 received=visual.received
 seed_hurt("water")
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return visual.received>received,0.6),"连续真实受击刷新原600毫秒恢复")
 _check(visual.pose.texture is AtlasTexture and visual.pose.texture.atlas.resource_path.ends_with("three_directions_v1.png"),"连续受击仍消费专用方向图，不在第二击跳回待机")
 release_move()
 _check(await until_true(func(): return not visual.active(),0.8),"实际600毫秒结束后正常解冻")

func crowd_live() -> void:
 setup(Vector2(880,490))
 var c: Dictionary=sm.data[Run.KEY].combat
 var fish: Dictionary=c.actors[FISH]
 fish.position=[880.0,471.5]
 fish.fish_origin=fish.position.duplicate()
 fish.fish_aim=[0.0,1.0]
 fish.fish_hit=false
 Run.Combat.Silverfish.phase(fish,"idle",0.0)
 _check(Run.valid(state()),"两怪贴身自然战斗检查点合法")
 if failures: return
 maze.capture_flow.set_process(true)
 await key(KEY_SPACE)
 var attempts:=0
 var accepted:=0
 var start_clock: float=state().combat.elapsed
 var deadline:=Time.get_ticks_msec()+8500
 while Time.get_ticks_msec()<deadline and state().combat.hp>0.0 and not maze.capture_flow.busy:
  var before: Dictionary=state().combat
  var ready: bool=not maze.capture_flow.combat_paused() and before.cooldown<=0.00001 and before.action_left<=0.0 and not maze.capture_flow.player_recovering()
  var throws: int=before.throws
  await click()
  attempts+=1
  var fired: bool=state().combat.throws>throws
  if fired: accepted+=1
  trace.append({"time":state().combat.elapsed,"ready":ready,"fired":fired,"recovery":state().combat.get("hurt_recovery_left",0.0),"cooldown":state().combat.cooldown,"action_left":state().combat.action_left,"hp":state().combat.hp,"paused":maze.capture_flow.combat_paused(),"busy":maze.capture_flow.busy})
  _check(not ready or fired,"两怪真实交战中可攻击状态的左键不能丢失",trace.back())
  await get_tree().create_timer(0.15).timeout
 _check(accepted>=2 and state().combat.elapsed>start_clock+2.0,"8.5秒同场未出现永久禁攻或模拟时钟锁死",{"attempts":attempts,"accepted":accepted,"elapsed":state().combat.elapsed,"busy":maze.capture_flow.busy,"pending":state().pending})
 await picture("crowd_live_end")
