extends "res://scripts/ui/components/customer_order_bubble.gd"
## 反馈主体可避让，尖角始终停留在人物头顶锚点(0,0)。
var message := ""
var emotion := 0
var body_offset := Vector2.ZERO
const FONT_SIZE := 18
const MAX_TEXT_WIDTH := 240.0
var _measured_message := "\u0000"
var text_lines: Array[String] = []
var body_size := Vector2.ZERO

func body_rect() -> Rect2:
	if _measured_message != message:
		_measured_message = message
		text_lines.clear()
		var line := ""
		var font := SproutTheme.FONT_CN
		for character in message:
			if character == "\n":
				text_lines.append(line)
				line = ""
			elif not line.is_empty() and font.get_string_size(line+character,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x>MAX_TEXT_WIDTH:
				text_lines.append(line)
				line = character
			else: line += character
		text_lines.append(line)
		var width := 0.0
		for text in text_lines: width = maxf(width,font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE).x)
		body_size = Vector2(maxf(56,width+24),ceilf(font.get_height(FONT_SIZE))*text_lines.size()+20)
	return Rect2(Vector2(-body_size.x*0.5,-body_size.y-10),body_size)

func _draw() -> void:
	var body := body_rect()
	body.position += body_offset
	var base_x := clampf(0,body.position.x+20,body.end.x-20)
	var side := body_offset.y > 1
	var base_y := clampf(0,body.position.y+20,body.end.y-20)
	var outline := PackedVector2Array()
	_arc(outline,Vector2(body.end.x-12,body.position.y+12),-90)
	if side and body.end.x<0:
		outline.append_array(PackedVector2Array([Vector2(body.end.x,base_y-7),Vector2.ZERO,Vector2(body.end.x,base_y+7)]))
	_arc(outline,Vector2(body.end.x-12,body.end.y-12),0)
	if not side:
		outline.append_array(PackedVector2Array([Vector2(base_x+7,body.end.y),Vector2.ZERO,Vector2(base_x-7,body.end.y)]))
	_arc(outline,Vector2(body.position.x+12,body.end.y-12),90)
	if side and body.position.x>0:
		outline.append_array(PackedVector2Array([Vector2(body.position.x,base_y+7),Vector2.ZERO,Vector2(body.position.x,base_y-7)]))
	_arc(outline,Vector2(body.position.x+12,body.position.y+12),180)
	draw_colored_polygon(outline,panel.bg_color)
	outline.append(outline[0])
	draw_polyline(outline,panel.border_color,2,true)
	var font := SproutTheme.FONT_CN
	for i in text_lines.size():
		var baseline := body.position+Vector2(12,10+font.get_ascent(FONT_SIZE)+i*ceilf(font.get_height(FONT_SIZE)))
		draw_string(font,baseline,text_lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,FONT_SIZE,SproutTheme.INK)

func _arc(points: PackedVector2Array, center: Vector2, start: float) -> void:
	for step in 7: points.append(center+Vector2.from_angle(deg_to_rad(start+step*15))*12)
