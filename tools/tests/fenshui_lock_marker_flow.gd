extends "res://tools/tests/fenshui_target_lock_flow.gd"

func battle() -> void:
 _check(await until_true(func(): return maze._entry_ready and not maze.player.input_locked),"锁定显示在真实七怪入口验收")
 maze.capture_flow.window_focused=true
 var marker: Node2D=maze.capture_flow.get("target_marker")
 _check(marker!=null,"正式分水庭已安装认可的倒三角显示消费者")
 if marker==null: return
 await key(KEY_TAB)
 var id: String=maze.capture_flow.locked_target_id
 _check(marker.visible and marker.target_id==id,"Tab锁定当帧显示倒三角，没有等待另一次攻击")
 var node: Node2D=maze.capture_flow.monsters[id]
 _check(marker.global_position.y<node.label.global_position.y-7.0,"倒三角位于标签上方，不遮血条文字")
 await key(KEY_TAB)
 _check(marker.target_id==maze.capture_flow.locked_target_id and marker.target_id!=id,"切换锁定立即转移倒三角，不留旧目标拖尾")
 await key(KEY_Q)
 _check(not marker.visible,"Q解除即刻隐藏倒三角")
 _check(maze.capture_flow.monsters[Boss.ID].enable_frog_front24(),"同一正式巨蛙启用已认可1.4倍双前向图")
 _check(await until_true(func(): return actor().frog_phase=="airborne",6.0),"倒三角跟随验收等待实际自然腾空")
 for i in 8:
  await key(KEY_TAB)
  if maze.capture_flow.locked_target_id==Boss.ID: break
 _check(maze.capture_flow.locked_target_id==Boss.ID and marker.visible,"自然腾空中实际Tab锁定巨蛙")
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 var body_before: float=frog.body.position.y
 var mark_before: float=marker.global_position.y-frog.global_position.y
 _check(await until_true(func(): return absf(frog.body.position.y-body_before)>8.0,1.0),"真实跳跃产生足够可观察的身体高度变化")
 var body_after: float=frog.body.position.y
 var mark_after: float=marker.global_position.y-frog.global_position.y
 _check(absf((mark_after-mark_before)-(body_after-body_before))<4.0,"腾空标记跟随可见身体偏移而不留在地面",{"body_delta":body_after-body_before,"marker_delta":mark_after-mark_before})
 for size in [Vector2i(1152,648),Vector2i(1280,720)]:
  viewport.size=size
  maze.camera.snap_to_target()
  await picture("frog_locked_"+str(size.x))
  var screen:=marker.get_global_transform_with_canvas().origin
  _check(screen.y>10.0 and screen.y<float(size.y)-10.0,"当前分辨率倒三角不裁到屏幕外："+str(size.x),{"screen":str(screen)})
 await mouse(maze.map_ui.mini_button.get_global_rect().get_center())
 _check(maze.map_ui.expanded,"真实展开地图暂停标记")
 var marker_clock: float=marker.elapsed
 var marker_position: Vector2=marker.position
 await get_tree().create_timer(0.25).timeout
 _check(marker.elapsed==marker_clock and marker.position==marker_position,"地图暂停冻结倒三角的收拢与微动")
 await key(KEY_ESCAPE)
 await key(KEY_Q)
 if failures: return
 await super.battle()
