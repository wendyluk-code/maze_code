extends RefCounted
## 已确认效果图的五处封闭路口，坐标使用1715×917世界尺寸。
const GATES := [
 {"name":"青苔池","a":Vector2(174,191),"b":Vector2(205,150),"front":Vector2(239,194)},
 {"name":"树根庭院","a":Vector2(190,480),"b":Vector2(249,505),"front":Vector2(274,463)},
 {"name":"污水池","a":Vector2(619,766),"b":Vector2(665,807),"front":Vector2(702,787)},
 {"name":"浅滩","a":Vector2(929,813),"b":Vector2(1010,814),"front":Vector2(956,778)},
 {"name":"水轮工坊","a":Vector2(1475,652),"b":Vector2(1530,615),"front":Vector2(1438,612)}
]
static func center(gate: Dictionary) -> Vector2:
 return (gate.a+gate.b)*0.5
static func blocks(point: Vector2, radius: float) -> bool:
 for gate in GATES:
  # 延长到路肩，防止从栏柱旁的窄缝穿过；木栏本体仍按设计图绘制。
  var direction: Vector2 = (gate.b-gate.a).normalized()
  if point.distance_to(Geometry2D.get_closest_point_to_segment(point,gate.a-direction*18.0,gate.b+direction*18.0)) < radius+5.0: return true
 return false
