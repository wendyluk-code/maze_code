extends "res://tools/tests/fenshui_feedback_repair.gd"
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"可见范围从真实七怪场景开始")
 var frog: Node=maze.capture_flow.monsters[Boss.ID]
 _check(is_instance_valid(frog.get_node_or_null("LandingSplashCandidate")),"正式分水庭场景自动安装范围水花")
 var entry: Node=load("res://tools/previews/fenshui_feedback_play.gd").new()
 entry.maze=maze
 _check(entry._prepare_frog(),"安装实际候选消费者")
 splash=entry.splash
 _check(splash==frog.get_node_or_null("LandingSplashCandidate"),"试玩入口复用正式场景水花，不重复安装")
 entry.free()
 if _arg("--phase=")=="legacy":
  splash.free()
  splash=load("res://scripts/maze/frog_splash_visual.gd").new()
  splash.flow=maze.capture_flow
  maze.capture_flow.monsters[Boss.ID].add_child(splash)
  await get_tree().process_frame
 setup(Vector2(1140,470))
 seed_hurt("slam")
 var a: Dictionary=sm.data[Run.KEY].combat.actors[Boss.ID]
 a.frog_phase="warning"
 a.frog_left=0.5
 a.position=a.frog_origin.duplicate()
 _check(Run.valid(state()),"自然跳跃检查点合法")
 maze.capture_flow.set_process(true)
 await get_tree().process_frame
 await picture("01-warning")
 var aligned: bool=splash.has_method("area_snapshot")
 _check(aligned or _arg("--phase=")=="legacy","预警必须显示真实伤害水域，旧版仅作明确标记的对照")
 if not aligned:
  if _arg("--phase=")=="legacy":
   _check(await until_true(func(): return actor().frog_phase=="airborne",1.0),"旧版对照正常起跳")
   await picture("02-airborne")
   _check(await until_true(func(): return actor().frog_phase=="landing" and splash.age>=0.24,1.8),"旧版对照正常落地峰值")
   await picture("03-landing")
  return
 var warning: Dictionary=splash.area_snapshot()
 var shape:=Area.polygon(Vector2(1040,450),Boss.ID+"_slam")
 _check(warning.visible and warning.shape==shape,"预警完整消费当前巨蛙砸击的实际伤害水域多边形")
 _check(await until_true(func(): return actor().frog_phase=="airborne",1.0),"真实预警后自然起跳")
 _check(splash.area_snapshot().shape==shape,"腾空中范围固定在已锁定落点，不追着身体或玩家移动")
 await picture("02-airborne")
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 var left: float=actor().frog_left
 var snapshot: Dictionary=splash.area_snapshot()
 await get_tree().create_timer(0.15).timeout
 _check(maze.map_ui.expanded and actor().frog_left==left and splash.area_snapshot()==snapshot,"地图暂停冻结跳跃与范围显示")
 await key(KEY_ESCAPE)
 _check(await until_true(func(): return actor().frog_phase=="landing",1.2),"关闭暂停后自然落地")
 _check(splash.area_snapshot().shape==shape,"落地沿同一块预警水域显示与裁切")
 _check(await until_true(func(): return splash.age>=0.24,0.5),"正常播放到主浪峰值")
 await picture("03-landing")
 var back_mask: Node=splash.back.get_parent()
 var front_mask: Node=splash.front.get_parent()
 var local_shape:=PackedVector2Array()
 for point in shape: local_shape.append(point-splash.anchor)
 _check(back_mask is Polygon2D and front_mask is Polygon2D and back_mask.polygon==local_shape and front_mask.polygon==local_shape,"水花前后层实际裁切到同一伤害多边形")
 _check(back_mask.clip_children==CanvasItem.CLIP_CHILDREN_ONLY and front_mask.clip_children==CanvasItem.CLIP_CHILDREN_ONLY,"前后水花均开启真实绘制裁切，不只存一个范围字段")
 _check(splash.ripple_mask.polygon==local_shape and splash.ripple_mask.clip_children==CanvasItem.CLIP_CHILDREN_ONLY,"地面薄波纹也裁切到实际伤害水域")
 _check(await until_true(func(): return splash.frame<0,1.0),"落地水花自然结束")
 _check(not splash.area_snapshot().visible,"水花结束范围层不残留")
 splash.hide()
 await get_tree().process_frame
 _check(not splash.area_snapshot().visible,"消费者隐藏清理独立地面层")
 _check(not splash.ripple.visible,"消费者隐藏同时清理薄波纹")
 splash.show()
 maze.capture_flow.set_process(false)
 a.frog_phase="warning"
 a.hp=0.0
 splash._process(0.0)
 _check(not splash.area_snapshot().visible,"巨蛙生命归零后不继续显示预警")
 _check(not splash.ripple.visible,"巨蛙生命归零后不残留薄波纹")
 var ground: Node=splash.ground
 splash.queue_free()
 await get_tree().process_frame
 await get_tree().process_frame
 _check(not is_instance_valid(ground),"水花节点释放后独立地面层随之释放")
 _check(not frog.has_meta("slam_area_preview"),"水花节点释放后移除巨蛙显示标记")
