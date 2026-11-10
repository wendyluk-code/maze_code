extends Node2D
## 与实际生命增长绑定的已认可七道短弧；不驱动治疗。
var active:=false
var clock:=0.0
var ratio:=1.0

func clear() -> void:
 active=false
 clock=0.0
 hide()
 queue_redraw()

func sync(healing: bool) -> void:
 if not healing:
  clear()
  return
 active=true
 show()

func advance(delta: float,sprite: Sprite2D,width: float) -> void:
 if not active: return
 if not get_parent().is_visible_in_tree():
  clear()
  return
 clock+=delta
 ratio=width/160.0
 position=sprite.position
 queue_redraw()

func _draw() -> void:
 if not active: return
 for j in 7:
  var p:=fposmod(clock+float(j)*0.18,1.3)/1.3
  var x: float=-63+j*21+sin(j*2+p*3)*5
  var y: float=-12-p*86
  var points:=PackedVector2Array()
  for i in 13:
   var t:=float(i)/12.0
   points.append((Vector2(x,y+10)*(1-t)*(1-t)+Vector2(x-6,y)*2*(1-t)*t+Vector2(x+3,y-9)*t*t)*ratio)
  var color:=Color("edffe0") if j%2 else Color("3e9b92")
  color.a=sin(p*PI)*0.95
  draw_polyline(points,color,4.0*ratio,true)
