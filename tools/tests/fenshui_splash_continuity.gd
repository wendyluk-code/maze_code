extends "res://tools/tests/fenshui_feedback_repair.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"连续性检查进入真实七怪场景")
 var frog: Node=maze.capture_flow.monsters[Boss.ID]
 splash=frog.get_node("LandingSplashCandidate")
 setup(Vector2(1140,470))
 seed_hurt("slam")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.frog_phase="warning"
 a.frog_left=0.15
 a.position=a.frog_origin.duplicate()
 splash.clear()
 splash._process(0.0)
 maze.capture_flow.set_process(true)
 _check(await until_true(func(): return splash.landings>0 and actor().frog_phase=="landing",2.0),"原战斗状态自然落地")
 maze.process_mode=Node.PROCESS_MODE_DISABLED
 splash.age=0.27
 splash._process(0.0)
 await picture("01-current")
 _check(splash.back.texture is AtlasTexture and splash.back.texture.atlas.resource_path.ends_with("landing_v2.png"),"落地实际消费本次六帧图，不沿用旧九格水花")
 var front_mask: Node2D=splash.front.get_parent()
 var original_z: int=splash.front.z_index
 _check(splash.front.z_index==0,"前景水花与裁切父节点保持同一绘制层，避免跨层绕过裁切",{"sprite_z":original_z,"mask_z":front_mask.z_index})
 var original_scale: Vector2=splash.front.scale
 for i in 6:
  splash.age=(float(i)+0.5)*float(splash.DURATIONS.landing)/6.0
  splash._render()
  _check(splash.frame==i+3 and splash.back.offset==Vector2(-256,-300) and splash.front.offset==Vector2(-256,0),"六帧顺序与固定落点一致："+str(i))
  _check(splash.front.scale.is_equal_approx(splash.back.scale) and is_equal_approx(splash.front.scale.x,splash.front.scale.y),"前后主体等比且接缝一致："+str(i))
  await picture("landing_"+str(i))
 if original_z==0:
  splash.age=0.45
  splash._render()
  var early_alpha: float=splash.front.modulate.a
  splash.age=0.62
  splash._render()
  _check(splash.front.modulate.a<early_alpha and splash.front.modulate.a>0.0,"末段水花渐隐而非满透明度突然消失")
  await picture("04-fade")
  splash.age=float(splash.DURATIONS.landing)
  splash._render()
  _check(not splash.front.visible and not splash.back.visible,"渐隐结束前后水花同时隐藏")
  _check(not splash.ripple.visible,"渐隐结束地面薄波纹也隐藏")
 splash._begin("takeoff",splash.anchor)
 splash.age=0.15
 splash._render()
 _check(splash.back.texture.atlas.resource_path.ends_with("candidate_v1.png") and not splash.ripple.visible,"起跳保留旧素材且不出现落地波纹")
 trace.append({"original_front_z":original_z,"back_scale":str(splash.back.scale),"front_scale":str(original_scale)})
 maze.queue_free()
 await get_tree().process_frame
