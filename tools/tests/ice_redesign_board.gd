extends Control
var page := 0
const FONT = preload("res://assets/ui/game_font.tres")
const CUP = preload("res://scripts/ui/components/ganlu_art.gd")
func label_at(p: Vector2, value: String, font_size := 22, ink := Color("644a35")) -> void:
	draw_string(FONT,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
func box(r: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.draw(get_canvas_item(),r)
func cup(p: Vector2, scale_factor: float, state: int) -> void:
	draw_set_transform(p,0,Vector2.ONE*scale_factor)
	draw_texture_rect(CUP.cup(),Rect2(0,0,54,74),false,Color("a3a5a1") if state==3 else Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(7,25),Vector2(47,25),Vector2(43,62),Vector2(12,62)]),Color("969b9a") if state==3 else Color("80bec8b0"))
	draw_line(Vector2(8,25),Vector2(46,25),Color("bde8e8") if state!=3 else Color("c0c2bc"),3,true)
	if state==2:
		box(Rect2(14,30,12,11),Color("e5faf5"))
		box(Rect2(29,34,11,10),Color("c8eced"))
	if state==3:
		draw_polyline(PackedVector2Array([Vector2(30,15),Vector2(24,29),Vector2(33,39),Vector2(22,51),Vector2(27,64)]),Color("565b58"),2.5,true)
	draw_set_transform(Vector2.ZERO)
func meter(p: Vector2, state: int) -> void:
	box(Rect2(p,Vector2(23,95)),Color("a9b7af") if state!=3 else Color("d85e56"))
	box(Rect2(p+Vector2(5,5),Vector2(13,85)),Color("ece8d7") if state!=3 else Color("ee7c70"))
	var h := 37.0 if state==1 else 65.0
	if state!=3: box(Rect2(p+Vector2(6,89-h),Vector2(11,h)),Color("80c6d5"))
	draw_line(p+Vector2(-5,25),p+Vector2(28,25),Color("64c47e") if state==2 else (Color("fba39a") if state==3 else Color("607e81")),3,true)
	if state==2:
		draw_line(p+Vector2(-6,25),p+Vector2(29,25),Color("80e89b55"),10,true)
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("eee4cf"))
	label_at(Vector2(52,55),"甘露水冰镇 · 交互效果预览" if page==0 else "点单气泡与携带图标 · 效果预览",30)
	if page==0:
		for i in 3:
			var x := 48.0+i*404
			box(Rect2(x,88,380,540),Color("f8efd9"))
			label_at(Vector2(x+24,132),["冰镇中","达标窗口","超时损坏"][i],24)
			# 同一台面内统一轴向的凹槽，杯底落在槽的中央。
			var p := Vector2(x+28,230)
			var top := PackedVector2Array([p+Vector2(0,32),p+Vector2(255,0),p+Vector2(322,134),p+Vector2(67,166)])
			draw_colored_polygon(PackedVector2Array([top[0],top[3],top[2],top[2]+Vector2(0,28),top[3]+Vector2(0,28),top[0]+Vector2(0,28)]),Color("75938c"))
			draw_colored_polygon(top,Color("b5cbc0"))
			var hole := PackedVector2Array([p+Vector2(65,53),p+Vector2(208,35),p+Vector2(250,114),p+Vector2(107,132)])
			draw_colored_polygon(hole,Color("526d68"))
			var inner := hole.duplicate()
			for j in inner.size(): inner[j]+=Vector2(3,8)
			draw_colored_polygon(inner,Color("7caaa6"))
			cup(p+Vector2(131,5),1.15,i+1)
			meter(p+Vector2(264,-14),i+1)
			hole.append(hole[0]); draw_polyline(hole,Color("c4ceca") if i==0 else Color("ddf6e8"),2,true)
			box(Rect2(p+Vector2(141,-43),Vector2(32,32)),Color("cfcec5") if i==0 else Color("f7efd5"))
			label_at(p+Vector2(149,-19),"E",22,Color("96998e") if i==0 else Color("426044"))
			label_at(Vector2(x+24,490),["连续温度条向上增长","刻度线绿色呼吸","整条温度计变红"][i],21)
			label_at(Vector2(x+24,529),["E 置灰，无法取出","E 可用，取出为加冰水","E 可用，可取出处理"][i],19)
		label_at(Vector2(52,677),"注：卡片标题与说明仅用于审稿；游戏内不显示倒计时秒数或状态文字。",19)
	else:
		for i in 2:
			var x := 70.0+i*590
			box(Rect2(x,95,550,255),Color("f8efd9"))
			label_at(Vector2(x+24,137),["常温订单","加冰订单"][i],24)
			box(Rect2(x+200,164,127,135),Color("fff4dc"))
			box(Rect2(x+204,275,119,20),Color("df8b7d"))
			cup(Vector2(x+233,179),1.15,0 if i==0 else 2)
			label_at(Vector2(x+24,326),"普通水杯，无温度计" if i==0 else "杯中有冰块，无温度计",18)
		for i in 3:
			var x := 70.0+i*395
			box(Rect2(x,380,365,245),Color("f8efd9"))
			label_at(Vector2(x+20,422),["常温携带","加冰携带","损坏携带"][i],23)
			cup(Vector2(x+58,455),1.35,[0,2,3][i])
			cup(Vector2(x+244,483),0.48,[0,2,3][i])
			label_at(Vector2(x+207,564),"地图小图标",17)
			label_at(Vector2(x+20,606),["明显水位","水中冰块，保留冷色","灰杯与裂纹持续显示"][i],19)
		label_at(Vector2(70,677),"订单红底保留等待倒计时；温度计仅在杯子放入冰柜时显示。",19)
