extends Node2D
## 可复用头顶情绪动画；Godot实时绘制，GIF仅用于效果审阅。
var kind := "confusion"
var elapsed := 0.0
var animate := true
func _process(delta: float) -> void:
	if animate:
		elapsed += delta
		queue_redraw()
func _draw() -> void:
	var wave := sin(elapsed*TAU*2.0)
	var ink := Color("80678b")
	if kind == "confusion":
		# 近圆形轮廓保持稳定，环线在内部扭转，不横向漂移。
		var points := PackedVector2Array()
		for i in 241:
			var t := float(i)/240.0*TAU
			var radius := 7.5+1.0*sin(t*3.0+elapsed*TAU)
			var p := Vector2(cos(t*7.0+sin(elapsed*TAU)*0.3),sin(t*7.0+sin(elapsed*TAU)*0.3))*radius
			p += Vector2(cos(t*2.0+elapsed*TAU),sin(t*3.0-elapsed*TAU))*3.0
			points.append(p)
		draw_polyline(points,Color("fff0d5"),3.4,true)
		draw_polyline(points,ink,1.6,true)
	elif kind == "anger":
		ink = Color("bd5f4b")
		var amplitude := 1.0+0.10*wave
		draw_set_transform(Vector2(0,-abs(wave)*2),0,Vector2.ONE*amplitude)
		for rotation in 4:
			var points := PackedVector2Array()
			for p in [Vector2(-11,-4),Vector2(-6,-4),Vector2(-4,-6),Vector2(-4,-11)]:
				points.append(p.rotated(rotation*PI/2))
			draw_polyline(points,Color("fff0d5"),5.4,true)
			draw_polyline(points,ink,3.0,true)
	else:
		draw_set_transform(Vector2(0,wave*3),sin(elapsed*TAU)*0.07)
		var font := SproutTheme.FONT_CN
		draw_string_outline(font,Vector2(-8,10),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,30,2,Color("fff0d5"))
		draw_string(font,Vector2(-8,10),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("8c7050"))
