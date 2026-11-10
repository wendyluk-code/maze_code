extends Node2D
## 已认可网页的原图复用显示；只消费提交状态，不修改战斗或另开时钟。
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
var bubble: Texture2D
var electric: Texture2D
var width:=58.0
var age:=0.0
var exhausted:=false
var recovering:=false
var center:=Vector2.ZERO

func _ready() -> void:
 bubble=load("res://assets/effects/fenshui/protection_bubble.png")
 electric=load("res://assets/monsters/thunder_eel/discharge.png")
 z_index=1
 hide()

func clear() -> void:
 exhausted=false
 recovering=false
 age=0.0
 hide()

func apply(body: Sprite2D, membrane: Sprite2D, actor: Dictionary, combat: Dictionary, id: String) -> void:
 # 父节点每次先重建原身体尺寸；位移只补偿本次低伏，不继承到命中图层。
 body.position=Vector2.ZERO
 if actor.is_empty() or combat.is_empty() or not Eel.enabled(combat,id) or actor.hp<=0 or combat.hp<=0 or not get_parent().is_visible_in_tree():
  clear()
  return
 exhausted=actor.get("eel_phase","")=="exhausted"
 recovering=actor.get("eel_phase","")=="forming" and int(actor.get("eel_discharges",0))==3
 if not exhausted and not recovering:
  clear()
  return
 age=maxf(0.0,(Eel.EXHAUST_TIME if exhausted else Eel.FORM_TIME)-float(actor.eel_left))
 var low:=minf(1.0,age/0.18) if exhausted else 1.0-minf(1.0,age/0.45)
 var breath:=sin(age*5.0)*0.012*low
 var ground:=body.get_rect().end.y*body.scale.y
 body.scale*=Vector2(1.0+0.05*low,1.0-0.23*low+breath)
 body.position.y=ground-body.get_rect().end.y*body.scale.y
 center=membrane.position
 if exhausted: membrane.hide()
 else:
  # 先抬身恢复电光，再在原1秒成泡剩余时段淡入；保护仍由逻辑判断。
  membrane.visible=age>=0.45
  membrane.modulate.a=clampf((age-0.45)/0.55,0.0,1.0)
 show()
 queue_redraw()

func _draw() -> void:
 var ratio:=width/160.0
 if exhausted and age<0.55:
  var p:=age/0.55
  for i in 7:
   var angle:=i*TAU/7.0
   var point:=center+Vector2(cos(angle)*(75.0+p*60.0),sin(angle)*(48.0+p*30.0))*ratio
   var texture_size:=Vector2(bubble.get_width(),bubble.get_height())
   var source_center:=texture_size*(Vector2.ONE*0.5+Vector2(cos(angle),sin(angle))*0.36)
   var source_size:=texture_size*0.13
   draw_set_transform(point,angle)
   draw_texture_rect_region(bubble,Rect2(Vector2(-15,-13)*ratio,Vector2(30,26)*ratio),Rect2(source_center-source_size*0.5,source_size),Color(1,1,1,(1.0-p)*0.65))
  draw_set_transform(Vector2.ZERO)
 if exhausted:
  var side:= -1.0 if get_parent().facing in [1,3] else 1.0
  for i in 3:
   var p:=fposmod(age*0.75+i*0.31,1.0)
   var points:=PackedVector2Array()
   for j in 7:
    var t:=j/6.0
    var a:=Vector2(62+i*7,-44-p*23)
    var b:=Vector2(70+i*7,-51-p*23)
    var c:=Vector2(64+i*7,-58-p*23)
    var point:=a*(1-t)*(1-t)+b*2*(1-t)*t+c*t*t
    points.append(Vector2(point.x*side,point.y)*ratio)
   draw_polyline(points,Color(0.816,0.957,0.898,sin(p*PI)*0.55),2.0*ratio,true)
 elif recovering and age>0.1:
  var cell:=Vector2(electric.get_width()/2.0,electric.get_height()/2.0)
  var size:=Vector2.ONE*width*0.9
  draw_texture_rect_region(electric,Rect2(center-size*0.5,size),Rect2(Vector2.ZERO,cell),Color(1,1,1,minf(0.45,(age-0.1)*0.6)))
