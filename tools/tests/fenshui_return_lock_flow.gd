extends "res://tools/tests/fenshui_return_water_flow.gd"

func shore_fixture(run: Dictionary, kind: String="silverfish") -> Dictionary:
 var fixture:=super.shore_fixture(run,kind)
 if kind=="thunder_eel" and not fixture.is_empty():
  var goal: Vector2=fixture.hero+fixture.start.direction_to(fixture.hero)*26.0
  _check(Fish.Roads.is_walkable(goal) and not Fish.Water.protected(goal),"雷鳗上岸引导给脚底实体留空间，原地形与55像素限制不变")
  fixture.hero=goal
 return fixture

func picture(label: String) -> void:
 if label.contains("_returning_"):
  await key(KEY_Q)
  for i in 8:
   await key(KEY_TAB)
   if maze.capture_flow.locked_target_id==test_id: break
  _check(maze.capture_flow.locked_target_id==test_id and maze.capture_flow.target_marker.visible,"真实回水时锁定标记与冒汗共同显示："+label)
  var marker: Node2D=maze.capture_flow.target_marker
  var bounds:=Rect2(marker.global_position-Vector2(10,9)*marker.scale,Vector2(20,18)*marker.scale)
  _check(not bounds.intersects(maze.capture_flow.power_label.get_global_rect()),"倒三角不遮主角信息文字："+label)
 await super.picture(label)
