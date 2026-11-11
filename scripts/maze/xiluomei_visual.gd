extends Node2D
## 复用水元素图标与范围线，只读事务状态；没有新增图片或逐帧动画资源。
const Tide=preload("res://scripts/maze/xiluomei_net.gd")
var state: Dictionary={}
var feedback: Dictionary={}
var controlled: Array=[]
var texture: Texture2D

func _ready() -> void:
	texture=load("res://assets/ui/factions/water.png")

func sync(c: Dictionary) -> void:
	state=c.get("xiluomei_net",{})
	feedback=c.get("xiluomei_feedback",{})
	controlled.clear()
	for a in c.get("actors",{}).values():
		if Tide.speed(a)<1 or Tide.rooted(a): controlled.append({"position":Tide.vec(a.position),"root":Tide.rooted(a)})
	queue_redraw()

func _draw() -> void:
	var current: Dictionary=state if not state.is_empty() else feedback
	if not current.is_empty():
		var p:=Tide.vec(current.position)
		var radius:=float(Tide.rules(int(current.rank)).radius)
		var color:=Color("70ccdf")
		if state.is_empty(): color=Color("b6f3ff") if feedback.stage=="out" else Color("4ba3c9")
		draw_circle(p,radius,Color(color,0.10))
		draw_arc(p,radius,0,TAU,64,Color(color,0.85),2.0,true)
		# 静态菱形网格，裁在实际命中圆内。
		for offset in range(-3,4):
			var x:=float(offset)*radius/4.0
			var y:=sqrt(maxf(0.0,radius*radius-x*x))
			for angle in [PI/4,-PI/4]:
				draw_line(p+Vector2(x,-y).rotated(angle),p+Vector2(x,y).rotated(angle),Color(color,0.42),1.0,true)
		if texture: draw_texture_rect(texture,Rect2(p-Vector2(12,12),Vector2(24,24)),false)
		if not state.is_empty(): draw_arc(p,radius+5,-PI/2,-PI/2+TAU*float(state.left)/1.5,64,Color("e0faff"),2.0,true)
	for marker in controlled:
		var p: Vector2=marker.position
		draw_arc(p,17,0,TAU,32,Color("70ccdf"),2 if marker.root else 1,true)
		if texture: draw_texture_rect(texture,Rect2(p-Vector2(8,42),Vector2(16,16)),false)
