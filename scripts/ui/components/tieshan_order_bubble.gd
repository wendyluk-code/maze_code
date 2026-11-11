extends "res://scripts/ui/components/customer_order_bubble.gd"
## 首单只扩展近距选中提示，交单仍由原教学事务处理。
var selected := false:
	set(value):
		if selected == value: return
		selected = value
		queue_redraw()
var keycap := StyleBoxFlat.new()
var font: Font = preload("res://assets/ui/game_font.tres")
var anchor_position := Vector2.ZERO
var body_offset := Vector2.ZERO

func fit_to_viewport() -> void:
	position = anchor_position
	var transform := get_global_transform_with_canvas()
	var tip := transform * Vector2.ZERO
	modulate.a = 1.0 if get_viewport_rect().grow(2).has_point(tip) else 0.0
	body_offset = Vector2.ZERO
	var top := transform * Vector2(0,-72 if selected else -62)
	if top.y < 8:
		body_offset = transform.affine_inverse().basis_xform(Vector2(0,8-top.y))
		body_offset.x = 52.0
	queue_redraw()

func _draw() -> void:
	panel.border_color = Color("e2b34f") if selected else Color("a77d54")
	panel.set_border_width_all(3 if selected else 2)
	if body_offset.is_zero_approx():
		super._draw()
	else:
		var box := Rect2(Vector2(-31,-62)+body_offset,Vector2(62,50))
		var outline := PackedVector2Array()
		_arc(outline,Vector2(box.end.x-12,box.position.y+12),-90)
		_arc(outline,Vector2(box.end.x-12,box.end.y-12),0)
		_arc(outline,Vector2(box.position.x+12,box.end.y-12),90)
		var tail_y := clampf(0,box.position.y+17,box.end.y-17)
		outline.append_array(PackedVector2Array([Vector2(box.position.x,tail_y+5),Vector2.ZERO,Vector2(box.position.x,tail_y-5)]))
		_arc(outline,Vector2(box.position.x+12,box.position.y+12),180)
		draw_colored_polygon(outline,panel.bg_color)
		outline.append(outline[0])
		draw_polyline(outline,panel.border_color,3 if selected else 2,true)
		if dish:
			var extent := dish.get_size()*minf(42.0/dish.get_width(),36.0/dish.get_height())
			draw_texture_rect(dish,Rect2(body_offset+Vector2(0,-37)-extent*0.5,extent),false)
	draw_set_transform(body_offset)
	if selected:
		keycap.bg_color = Color("f5da93")
		keycap.set_corner_radius_all(5)
		keycap.draw(get_canvas_item(),Rect2(20,-72,23,23))
		draw_string(font,Vector2(26,-54),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("654c34"))

func _arc(points: PackedVector2Array, center: Vector2, start: float) -> void:
	for step in 7: points.append(center+Vector2.from_angle(deg_to_rad(start+step*15))*12)
