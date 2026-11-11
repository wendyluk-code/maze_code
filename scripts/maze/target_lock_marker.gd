extends Node2D
## 只显示已认可的暖橙倒三角；不选择目标、不接收输入、不写存档。
var target_id: String=""
var elapsed:=0.0
var acquired:=0.0

func _ready() -> void:
 z_index=100
 hide()

func sync(flow: Node, dt: float) -> void:
 var id: String=flow.locked_target_id if flow.target_lock_enabled() else ""
 if id.is_empty() or not flow.monsters.has(id) or not flow.monsters[id].is_visible_in_tree():
  target_id=""
  hide()
  return
 if not flow.combat_paused(): elapsed+=dt
 if target_id!=id:
  target_id=id
  acquired=elapsed
 var monster: Node2D=flow.monsters[id]
 var anchor:=Vector2(0,monster.label.position.y-16.0+minf(0.0,monster.body.position.y))
 if monster.config.kind=="rockmane": anchor.x=monster.label.position.x+monster.label.size.x*0.5
 global_position=monster.to_global(anchor)+Vector2(0,sin(elapsed/0.45)*1.5)
 var settle:=maxf(0.0,1.0-(elapsed-acquired)/0.18)
 scale=Vector2.ONE*(1.0+settle*0.25)
 # 标记不压到主角的攻击/生命信息；只移动标记，不改现有短条布局。
 var half_size:=Vector2(10,9)*scale
 var hero_stats: Rect2=flow.power_label.get_global_rect()
 if Rect2(global_position-half_size,half_size*2.0).intersects(hero_stats.grow(2.0)):
  global_position.y=hero_stats.position.y-half_size.y-3.0
 # 小视口或目标贴上沿时保留完整标记，不改变目标或外观。
 var canvas:=get_viewport().get_canvas_transform()
 var pad:=Vector2(canvas.x.length()*10.0,canvas.y.length()*9.0)*scale
 var rect:=get_viewport_rect()
 var screen:=canvas*global_position
 screen.x=clampf(screen.x,rect.position.x+pad.x,rect.end.x-pad.x)
 screen.y=clampf(screen.y,rect.position.y+pad.y,rect.end.y-pad.y)
 global_position=canvas.affine_inverse()*screen
 show()
 queue_redraw()

func _draw() -> void:
 var points:=PackedVector2Array()
 for i in 9:
  var t:=float(i)/8.0
  points.append(Vector2(-8,-5)*(1.0-t)*(1.0-t)+Vector2(0,-7)*2.0*(1.0-t)*t+Vector2(8,-5)*t*t)
 points.append(Vector2(0,6))
 draw_colored_polygon(points,Color("e9a34e"))
 points.append(points[0])
 draw_polyline(points,Color("684b34"),2.0,true)
