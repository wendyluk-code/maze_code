extends RefCounted
## 捕获共用绳网、编织进度和弧形蓄力显示；不处理业务状态。
const T = preload("res://scripts/ui/components/sprout_theme.gd")
class Rope extends Control:
	var t := 0.0
	var spread := 0.0
	var time := 0.0
	var strength := 1.0
	var target_rect := Rect2(162,164,180,166)
	func configure_target(rect: Rect2) -> void:
		target_rect = rect
	func animate(stage: String, elapsed: float, pulse: float, passed: bool) -> void:
		match stage:
			"throw": t = 0.65 + clampf(elapsed / 1.1, 0, 1) * 1.6
			"restrain": t = 2.25 + clampf(elapsed / 1.5, 0, 1) * 1.7
			"suppress": t = 3.95 + fmod(elapsed, 2.6)
			"complete", "settling": t = 6.6 + elapsed if passed else 2.25
			_: t = 0.0
		strength = pulse
		queue_redraw()
	func point(u: float, v: float) -> Vector2:
		var angle := u * PI - PI/2
		var pile := Vector2(84 + (u-0.5)*102 + sin(v*20)*12, 355+(v-0.5)*44+sin(u*19)*8)
		var phase := clampf((t-0.65)/1.6, 0, 1)
		var spread := smoothstep(0.05,0.85,phase)
		var center := Vector2(84,355).lerp(Vector2(target_rect.get_center().x, target_rect.position.y + target_rect.size.y * 0.5 + 8),phase)
		center.y -= sin(PI*phase)*150
		var shake := sin(t*23)*4.5 if t>2.25 and t<3.95 else 0.0
		var press := strength * 9.0 if t>=3.95 and t<6.6 else 0.0
		var squeeze := smoothstep(3.95,6.6,t)
		var radius := 126.0 * pow(v, 0.68) * (1.0-squeeze*0.06)
		var sag := sin(u*PI*5 + v*7)*4*v + sin(u*PI)*sin(v*PI*5)*3
		var flutter := sin(t*15+u*9+v*7)*3*v if t>2.25 and t<6.6 else 0.0
		var dome := Vector2(sin(angle)*radius + shake*v + sin(v*10+u*8)*4*v + flutter, -100 + v*(181-press-squeeze*12) + cos(angle)*24*v + press + sag)
		if v>0.94: dome.x += sin(u*30)*6*(v-0.94)/0.06
		dome *= Vector2((target_rect.size.x+60)/252.0, (target_rect.size.y+40)/207.0)
		return (pile-Vector2(84,355)).lerp(dome,spread)+center
	func strand(points: PackedVector2Array) -> void:
		draw_polyline(points, Color("#795535"), 4.5, true)
		draw_polyline(points, Color("#d6b581"), 2.7, true)
		draw_polyline(points, Color("#f5dfae"), 0.8, true)
	func _draw() -> void:
		var columns := [0.0, 0.14, 0.31, 0.51, 0.70, 0.86, 1.0]
		var rows := [0.0, 0.19, 0.42, 0.68, 0.94, 1.0]
		for u in columns:
			var pts := PackedVector2Array()
			for j in range(51): pts.append(point(u,j/50.0))
			strand(pts)
		for v in rows.slice(1):
			var pts := PackedVector2Array()
			for i in range(101): pts.append(point(i/100.0,v))
			strand(pts)
		for u in columns:
			for v in rows.slice(1):
				var pos := point(u,v)
				var knot := PackedVector2Array()
				for k in range(21):
					var a := k*TAU/20
					knot.append(pos+Vector2(cos(a)*3.8,sin(a)*2.7).rotated(0.6))
				strand(knot)
		var top := point(0.5,0)
		for k in range(3):
			var knot := PackedVector2Array()
			for j in range(21):
				var a := j*TAU/20
				knot.append(top+Vector2(cos(a)*5,sin(a)*3).rotated(k*PI/3))
			strand(knot)
		if t>=6.6:
			for i in range(7):
				var a := i*TAU/7
				var pos := Vector2(250,250)+Vector2(cos(a)*140,sin(a)*100)
				var r := 3+2*sin(t*5+i)
				draw_line(pos-Vector2(r,0),pos+Vector2(r,0),Color("#ffe6a0"),2,true)
				draw_line(pos-Vector2(0,r),pos+Vector2(0,r),Color("#ffe6a0"),2,true)


class Track extends Control:
	const ICONS = [preload("res://assets/ui/capture/track/throw_icon.png"), preload("res://assets/ui/capture/track/restrain_icon.png"), preload("res://assets/ui/capture/track/suppress_icon.png"), preload("res://assets/ui/capture/track/finish_icon.png")]
	const COMPLETED_FRAME = preload("res://assets/ui/capture/track/completed_frame.png")
	const PENDING_FRAME = preload("res://assets/ui/capture/track/pending_frame.png")
	const BRAID = preload("res://assets/ui/capture/track/rope_progress.png")
	const PENDING_BRAID = preload("res://assets/ui/capture/track/rope_pending.png")
	var progress := 0.0
	var phase := 0.0
	func is_node_complete(index: int) -> bool:
		return progress >= float(index) / 3.0
	func _draw():
		var names = ["抛网", "牵制", "镇压", "完成"]
		# Preserve braid proportions instead of stretching one tile across a segment.
		for segment in 3:
			var filled = clampf(progress * 3 - segment, 0, 1) * 210
			for tile in range(4):
				var offset = tile * 64.0
				var width = minf(64, 210 - offset)
				var rect = Rect2(segment * 210 + offset, -8, width, 16)
				draw_texture_rect_region(PENDING_BRAID, rect, Rect2(0, 0, width / 64 * 220, 66))
				var green_width = clampf(filled - offset, 0, width)
				if green_width > 0:
					draw_texture_rect_region(BRAID, Rect2(rect.position, Vector2(green_width, 16)), Rect2(0, 0, green_width / 64 * 220, 66))
		for i in 4:
			var pos = Vector2(i * 210, 0)
			var complete = is_node_complete(i)
			var current = i == 2 and progress >= 2.0 / 3.0 and progress < 1
			var radius = 33.0
			if current: radius += sin(phase * 5) * 1.2
			# Icon, neutral fill and mutually exclusive frame are independent layers.
			draw_circle(pos, radius * 0.84, T.CREAM)
			var icon_radius = radius * 0.73
			draw_texture_rect(ICONS[i], Rect2(pos - Vector2.ONE * icon_radius, Vector2.ONE * icon_radius * 2), false)
			var border = COMPLETED_FRAME if complete else PENDING_FRAME
			draw_texture_rect(border, Rect2(pos - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
			draw_string(T.FONT_CN, Vector2(i * 210 - 40, 48), names[i], HORIZONTAL_ALIGNMENT_CENTER, 80, 16, T.INK)
class Fan extends Control:
	var amount := 0.72
	var pulse := 0.0
	var keycap: Control
	func _ready():
		keycap=preload("res://scenes/ui/key_button.tscn").instantiate()
		add_child(keycap)
		keycap.get_node("KeyIcon/KeyLabel").text="J"
		keycap.position=Vector2(25,59)
		keycap.size=Vector2(48,48)
		keycap.pivot_offset=Vector2(24,24)
	func _draw():
		var center=Vector2(-35,150)
		var start=deg_to_rad(-65)
		var finish=deg_to_rad(65)
		draw_arc(center,125,start,finish,64,Color("#695338"),24,true)
		draw_arc(center,125,start,finish,64,Color("#d6bd8b"),19,true)
		draw_arc(center,125,start,finish,64,Color("#fff1cf"),12,true)
		for j in range(100):
			var f=j/100.0
			if f>=amount: break
			var color=Color("#cf624b").lerp(Color("#e5c565"),f/0.55) if f<0.55 else Color("#e5c565").lerp(Color("#82ac63"),(f-0.55)/0.25) if f<0.80 else Color("#82ac63")
			draw_arc(center,125,finish-(finish-start)*minf(f+0.014,amount),finish-(finish-start)*f,3,color,10,true)
		var target=finish-(finish-start)*0.90
		var direction=Vector2(cos(target),sin(target))
		draw_line(center+direction*111,center+direction*141,Color("#fff4dc"),6,true)
		draw_line(center+direction*111,center+direction*141,Color("#755334"),2,true)
		if is_instance_valid(keycap): keycap.scale=Vector2.ONE*(1+pulse*0.07)
		for i in range(24):
			var a=start+(finish-start)*i/23.0
			var v=Vector2(cos(a),sin(a))
			draw_line(center+v*136,center+v.rotated(0.025)*140,Color("#ae8c5b"),2,true)
		var tip=center+Vector2(cos(finish-(finish-start)*amount),sin(finish-(finish-start)*amount))*125
		draw_circle(tip,7,Color("#fff6d5"))



