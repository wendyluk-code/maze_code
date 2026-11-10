extends "res://tools/tests/ch2_entry_state.gd"
const Frames=preload("res://scripts/maze/wind_frog_frames.gd")

func _run() -> void:
 sm=get_node("/root/SaveManager")
 tm=get_node("/root/TutorialManager")
 _check(_verify_isolation(),"背向完整消费者使用隔离存档")
 var frames:=Frames.new()
 frames.load_frames(80.0)
 var body:=Sprite2D.new()
 for direction in [2,3]:
  for index in 18:
   var drawn: bool=frames.draw_direction_pose(body,index,direction)
   _check(drawn,"背向完整18姿态可消费：%d/%d"%[direction,index])
   if not drawn: continue
   var expected: String="back-right" if direction==2 else "back-left"
   _check(body.texture.atlas.resource_path.contains(expected),"实际读取同向交付而非镜像或右前回退")
   _check(not body.flip_h and not body.flip_v and is_zero_approx(body.rotation),"完整独立方向不镜像旋转")
   _check(body.scale.x>0 and is_equal_approx(body.scale.x,body.scale.y),"背向主体统一等比缩放")
 var saved: Texture2D=body.texture
 for direction in [-1,4]:
  _check(not frames.draw_direction_pose(body,4,direction) and body.texture==saved,"非法方向不改当前画面")
 body.free()
 var file:=FileAccess.open(_arg("--report="),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "))
 get_tree().quit(1 if failures else 0)
