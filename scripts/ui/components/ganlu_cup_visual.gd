extends RefCounted
const Art := preload("res://scripts/ui/components/ganlu_art.gd")
static func draw_cup(target: CanvasItem, rect: Rect2, grade: int) -> void:
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if grade==1:
		var texture := Art.iced_cup()
		# 按杯身对齐原杯，不把杯外冰块计入杯身的缩放尺寸。
		var body := Rect2(250,100,715,1000)
		var warm_body := Rect2(rect.position+rect.size*Vector2(0.04,0.03),rect.size*Vector2(0.94,0.94))
		var ratio := warm_body.size/body.size
		target.draw_texture_rect(texture,Rect2(warm_body.position-body.position*ratio,texture.get_size()*ratio),false)
		return
	target.draw_texture_rect(Art.result_cup(),rect,false,Color("939995") if grade==4 else Color.WHITE)
	var p := rect.position
	var s := rect.size
	if grade==4:
		var points := PackedVector2Array()
		for q in [Vector2(.52,.18),Vector2(.42,.35),Vector2(.57,.48),Vector2(.40,.66),Vector2(.48,.83)]: points.append(p+q*s)
		target.draw_polyline(points,Color("4e5550"),maxf(1.4,s.x*.04),true)
