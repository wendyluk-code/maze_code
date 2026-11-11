extends "res://scripts/ui/components/customer_order_bubble.gd"
## 预览用：同一套四种表情供全部冒险者复用。
var message := ""
var emotion := 0
func _draw() -> void:
	panel.draw(get_canvas_item(),Rect2(-126,-58,252,48))
	draw_rect(Rect2(-7,-13,14,3),panel.bg_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-10),Vector2(0,0),Vector2(7,-10)]),panel.bg_color)
	draw_polyline(PackedVector2Array([Vector2(-7,-10),Vector2(0,0),Vector2(7,-10)]),panel.border_color,2,true)
	var font := SproutTheme.FONT_CN
	draw_string(font,Vector2(-108,-28),message,HORIZONTAL_ALIGNMENT_LEFT,-1,18,SproutTheme.INK)