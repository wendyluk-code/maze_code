extends Control
var fill := 0.78
var overflow := false
var backing := false
func _draw() -> void:
	if backing:
		var center := size * 0.5
		draw_circle(center+Vector2(0,1),12,Color("c8b695"),true,-1,true)
		draw_circle(center,12,Color("a87950"),true,-1,true)
		draw_arc(center,11.5,0,TAU,64,Color("946239"),1,true)
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(100,140))
	draw_texture_rect(preload("res://scripts/ui/components/ganlu_art.gd").cup(),Rect2(0,0,100,140),false)
	var surface := 116.0 - fill * 88.0
	draw_colored_polygon(PackedVector2Array([Vector2(10,surface),Vector2(90,surface),Vector2(82,116),Vector2(22,116)]),Color("70b9c7b8"))
	draw_set_transform(Vector2(50,surface) * size / Vector2(100,140),0,size / Vector2(100,140) * Vector2(1,0.23))
	draw_circle(Vector2.ZERO,40,Color("b6e5e2"),true,-1,true)
	draw_set_transform(Vector2.ZERO,0,size / Vector2(100,140))
	draw_line(Vector2(22,surface+10),Vector2(26,98),Color("e7f5e4b0"),4,true)
	if overflow:
		draw_polyline(PackedVector2Array([Vector2(14,15),Vector2(6,26),Vector2(8,55),Vector2(5,76)]),Color("70b9c7"),7,true)
		draw_polyline(PackedVector2Array([Vector2(87,15),Vector2(95,25),Vector2(94,48)]),Color("70b9c7"),6,true)
		draw_circle(Vector2(6,87),4,Color("9edcde"),true,-1,true)
		draw_circle(Vector2(94,61),4,Color("9edcde"),true,-1,true)
