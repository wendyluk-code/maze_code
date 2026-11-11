extends "res://tools/tests/fenshui_feedback_repair.gd"
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
const GAP=Vector2(880,507)

func sprite_bounds(sprite: Sprite2D) -> Rect2:
 var used:=Rect2(sprite.texture.get_image().get_used_rect())
 used.position+=sprite.offset
 var box:=Rect2(sprite.to_global(used.position),Vector2.ZERO)
 for point in [used.position+Vector2(used.size.x,0),used.end,used.position+Vector2(0,used.size.y)]: box=box.expand(sprite.to_global(point))
 return box

func alpha_at(sprite: Sprite2D, world: Vector2) -> float:
 var point:=Vector2i((sprite.to_local(world)-sprite.offset).floor())
 var image:=sprite.texture.get_image()
 if point.x<0 or point.y<0 or point.x>=image.get_width() or point.y>=image.get_height(): return 0.0
 return image.get_pixelv(point).a

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"覆盖从真实七怪入口开始")
 var frog: Node=maze.capture_flow.monsters[Boss.ID]
 splash=frog.get_node_or_null("LandingSplashCandidate")
 _check(is_instance_valid(splash),"正式场景安装实际水花消费者")
 if failures: return
 setup(Vector2(1140,470))
 seed_hurt("slam")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.frog_phase="warning"
 a.frog_left=0.15
 a.position=a.frog_origin.duplicate()
 var original: Dictionary=sm.data.duplicate(true)
 splash.clear()
 splash._process(0.0)
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return splash.landings>0 and actor().frog_phase=="landing",2.0),"真实跳跃实际落地并播放水花")
 maze.process_mode=Node.PROCESS_MODE_DISABLED
 var center: Vector2=splash.anchor
 var shape:=Area.polygon(center,Boss.ID+"_slam")
 _check(Area.radius(Boss.ID+"_slam")==180.0,"正式攻击半径仍为180")
 var area_box:=Rect2(shape[0],Vector2.ZERO)
 for point in shape: area_box=area_box.expand(point)
 var union:=Rect2()
 var frames: Array=[]
 var gap_alpha:=0.0
 for i in 6:
  splash.age=(float(i)+0.5)*float(splash.DURATIONS.landing)/6.0
  splash._process(0.0)
  var box:=sprite_bounds(splash.back).merge(sprite_bounds(splash.front)).merge(sprite_bounds(splash.ripple))
  union=box if i==0 else union.merge(box)
  var alpha:=maxf(maxf(alpha_at(splash.back,GAP),alpha_at(splash.front,GAP)),alpha_at(splash.ripple,GAP)*splash.ripple.modulate.a)
  gap_alpha=maxf(gap_alpha,alpha)
  frames.append({"frame":splash.frame,"gap_alpha":alpha,"bounds":[box.position.x,box.position.y,box.size.x,box.size.y]})
  if i in [0,2,5]: await picture("landing_frame_"+str(splash.frame))
 var samples:=0
 var missing:=0
 for y in range(floori(area_box.position.y),ceili(area_box.end.y),4):
  for x in range(floori(area_box.position.x),ceili(area_box.end.x),4):
   var point:=Vector2(x,y)
   if not Area.contains(shape,point) or not Boss.water(point): continue
   samples+=1
   if not union.grow(1.0).has_point(point): missing+=1
 _check(missing==0,"所有合法伤害点至少进入水花动画的可见外框",{"samples":samples,"missing":missing})
 _check(gap_alpha>=0.1,"原漏区实际出现水花或原图薄波纹像素，不只扩大空白外框",{"alpha":gap_alpha})

 splash.age=0.27
 splash._process(0.0)
 var radius:=Area.radius(Boss.ID+"_slam")
 _check(absf(float(splash._peaks.landing)*splash.back.scale.x-radius*2.0)<0.01,"落地主浪横向标定读取实际攻击直径")
 _check(is_equal_approx(splash.back.scale.x,splash.back.scale.y),"上半部浪柱保持原图比例，不随地面纵深拉成高墙")
 _check(splash.front.scale.is_equal_approx(splash.back.scale),"新图前后主浪统一等比，不拉伸前沿")
 _check(absf(splash.ripple.scale.y*67.0-radius)<0.01,"贴水薄波纹纵深读取实际攻击半径")
 var saved: Dictionary=Tuning.values.duplicate(true)
 for value in [125.0,220.0]:
  Tuning.values=saved.duplicate(true)
  Tuning.values["frog.skill"]={"range":value}
  splash._process(0.0)
  _check(absf(float(splash._peaks.landing)*splash.back.scale.x-value*2.0)<0.01,"调整半径同步改变水花尺寸："+str(value))
  _check(splash.area_snapshot().shape==Area.polygon(center,Boss.ID+"_slam"),"调整半径后仍使用实际水域裁切："+str(value))
 Tuning.values=saved
 splash._process(0.0)
 _check(Area.radius("fenshui_thunder_eel_1")==125.0,"电鳗原攻击半径不变")

 # 只隐藏该冲击地面层作真实绘制前后对照，检查旧漏区不只是元数据覆盖。
 splash.back.hide()
 splash.front.hide()
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 var shown:=viewport.get_texture().get_image()
 splash.ground.hide()
 await get_tree().process_frame
 RenderingServer.force_draw(false)
 var hidden:=viewport.get_texture().get_image()
 var pixel:=Vector2i((maze.get_canvas_transform()*GAP).round())
 var difference:=0.0
 if Rect2i(Vector2i.ZERO,shown.get_size()).has_point(pixel):
  var with_ground:=shown.get_pixelv(pixel)
  var without_ground:=hidden.get_pixelv(pixel)
  difference=maxf(absf(with_ground.r-without_ground.r),maxf(absf(with_ground.g-without_ground.g),absf(with_ground.b-without_ground.b)))
 _check(difference>=0.02,"原漏区在实际画面出现地面冲击水色",{"pixel":[pixel.x,pixel.y],"difference":difference})
 splash.ground.show()
 splash._render()

 for point in [GAP,center+Vector2(180.1,0)]:
  sm.data=original.duplicate(true)
  a=sm.data[Run.KEY].combat.actors[Boss.ID]
  a.frog_phase="airborne"
  a.frog_air_duration=0.8
  a.frog_left=0.05
  a.position=Run.Combat.pack(Run.Combat.vec(a.frog_origin).lerp(center,1.0-0.05/0.8))
  var hp: float=state().combat.hp
  var result:=Run.combat_tick(sm,point,0.05)
  var slam:=false
  for event in result.get("player_hurt_feedback",[]):
   if event.kind=="slam": slam=true
  _check(result.success and slam==(point==GAP),"原伤害事务保留范围内外："+str(point),{"hp_before":hp,"hp_after":state().combat.hp,"slam":slam})

 splash._begin("takeoff",center)
 splash.age=0.15
 splash._render()
 _check(absf(float(splash._peaks.takeoff)*splash.back.scale.x-float(frog.frog_front24.reference_width)*105.0/132.0)<0.01,"起跳水花仍按原蛙体比例")
 trace.append({"center":[center.x,center.y],"samples":samples,"missing":missing,"gap_alpha":gap_alpha,"ground_difference":difference,"frames":frames})
 maze.queue_free()
 await get_tree().process_frame
