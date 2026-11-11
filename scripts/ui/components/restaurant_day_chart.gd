extends Control
## v11双柱折线共用数值轴；只画已有日期，一天只画节点。
const GOLD_LINE := Color("a4742e")
const REP_LINE := Color("527e75")
const ANIMATION_SECONDS := 0.8
const LINE_SECONDS := 0.4
signal animation_progress(value: float)
var entries: Array = []
var today := 1
var gold_points := PackedVector2Array()
var rep_points := PackedVector2Array()
var axis_min := 0.0
var axis_max := 200.0
var axis_ticks: Array[float] = []
var gold_labels: Array[Label] = []
var rep_labels: Array[Label] = []
var progress := 0.0
var line_progress := 0.0
var _elapsed := 0.0

func _text(text: String, rect: Rect2, font_size: int, ink := SproutTheme.INK, center := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if center: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",ink)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text("每日营业额 / 声望",Rect2(20,10,360,36),22)
	var maximum := 0.0
	var minimum := 0.0
	for entry in entries:
		maximum = maxf(maximum,maxf(float(entry.income),float(entry.reputation)))
		minimum = minf(minimum,minf(float(entry.income),float(entry.reputation)))
	var step := pow(10.0,floor(log(maxf(1,maximum-minimum))/log(10.0)))
	axis_max = maxf(step,ceil(maximum/step)*step)
	# 负端留出标签空间，但不人为放大负柱；正负仍共用同一线性轴。
	axis_min = 0.0
	if minimum<0:
		var negative_step := pow(10.0,floor(log(absf(minimum))/log(10.0)))
		axis_min = -maxf(ceil(absf(minimum)*1.2/negative_step)*negative_step,axis_max*0.1)
	axis_ticks.assign([axis_max,axis_max/2,0.0] if maximum>0 else [0.0])
	if minimum<0 and maximum<=0: axis_ticks.assign([0.0,axis_min/2,axis_min])
	elif minimum<0 and _y(axis_min)-_y(0)>30: axis_ticks.append(axis_min)
	for value in axis_ticks:
		_text(_number(value),Rect2(2,_y(value)-13,48,26),16,SproutTheme.INK_MUTED)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var x := 80.0+(6-entries.size())*43+i*86
		var gold_y := _y(0)
		var rep_y := _y(0)
		gold_points.append(Vector2(x+13,gold_y))
		rep_points.append(Vector2(x+37,rep_y))
		gold_labels.append(_text("0",Rect2(x-10,gold_y-32,46,30),19,SproutTheme.INK,true))
		rep_labels.append(_text("0",Rect2(x+23,rep_y-23,38,22),14,REP_LINE,true))
		_text("第 %d 天" % int(entry.day),Rect2(x-14,283,70,28),17,SproutTheme.INK,true)
		if int(entry.day)==today: _text("今日",Rect2(x-14,311,70,24),16,Color("5e823f"),true)
	if entries.is_empty(): _text("暂无可确认的营业记录",Rect2(56,130,544,70),20,SproutTheme.INK_MUTED,true)
	_apply_progress(0.0)
	set_process(not entries.is_empty())

func _process(delta: float) -> void:
	_elapsed = minf(_elapsed+delta,ANIMATION_SECONDS+LINE_SECONDS)
	line_progress = clampf((_elapsed-ANIMATION_SECONDS)/LINE_SECONDS,0.0,1.0)
	_apply_progress(_elapsed/ANIMATION_SECONDS)
	if line_progress>=1.0: stop_animation()

func stop_animation() -> void:
	set_process(false)

func _exit_tree() -> void:
	stop_animation()

func _apply_progress(value: float) -> void:
	progress = clampf(value,0.0,1.0)
	if progress==0.0:
		_elapsed = 0.0
		line_progress = 0.0
	for i in entries.size():
		var fraction := progress if int(entries[i].day)==today else 1.0
		var income := float(entries[i].income)*fraction
		var reputation := float(entries[i].reputation)*fraction
		gold_points[i].y = _y(income)
		rep_points[i].y = _y(reputation)
		var p := gold_points[i]
		var q := rep_points[i]
		gold_labels[i].text = _number(round(income))
		rep_labels[i].text = _number(round(reputation))
		gold_labels[i].position = Vector2(p.x-23,p.y+5 if float(entries[i].income)<0 else p.y-32)
		rep_labels[i].position = Vector2(q.x+10,q.y+5) if float(entries[i].reputation)<0 else Vector2(q.x-14,q.y-23)
	animation_progress.emit(progress)
	queue_redraw()

func _number(value: float) -> String:
	if absf(value)>=1000000: return "%.1f百万" % (value/1000000)
	if absf(value)>=10000: return "%.1f万" % (value/10000)
	return str(int(value)) if is_equal_approx(value,round(value)) else str(value)

func _y(value: float) -> float:
	return 264-(value-axis_min)/(axis_max-axis_min)*188

func _draw() -> void:
	SproutTheme.thin_panel_style().draw(get_canvas_item(),Rect2(0,0,622,344))
	for value in axis_ticks:
		draw_line(Vector2(56,_y(value)),Vector2(600,_y(value)),Color("e1d3b7"),1)
	var zero := _y(0)
	draw_line(Vector2(56,zero),Vector2(600,zero),Color("8e7958"),2)
	for i in gold_points.size():
		var current := int(entries[i].day)==today
		var p := gold_points[i]
		var q := rep_points[i]
		var gold_style := SproutTheme.thin_panel_style(SproutTheme.GREEN if current else Color("d7bf8f"))
		var rep_style := SproutTheme.thin_panel_style(Color("658b60") if current else Color("b0bba6"))
		if absf(zero-p.y)>0.1:
			if p.y>zero: draw_rect(Rect2(p.x-13,zero,26,p.y-zero),SproutTheme.GREEN if current else Color("d7bf8f"))
			else: gold_style.draw(get_canvas_item(),Rect2(p.x-13,p.y,26,zero-p.y))
		if absf(zero-q.y)>0.1:
			# 极短负柱直接实色绘制，避免圆角样式最小尺寸夸大-3。
			if q.y>zero: draw_rect(Rect2(q.x-5,zero,10,q.y-zero),Color("658b60") if current else Color("b0bba6"))
			else: rep_style.draw(get_canvas_item(),Rect2(q.x-5,q.y,10,zero-q.y))
		if float(entries[i].reputation)<0:
			draw_line(Vector2(q.x+5,q.y),Vector2(q.x+15,q.y+9),REP_LINE,1,true)
	for i in range(1,gold_points.size()):
		if int(entries[i].day)==int(entries[i-1].day)+1:
			var fraction := line_progress if int(entries[i].day)==today else 1.0
			if fraction<=0.0: continue
			draw_line(gold_points[i-1],gold_points[i-1].lerp(gold_points[i],fraction),GOLD_LINE,2,true)
			draw_line(rep_points[i-1],rep_points[i-1].lerp(rep_points[i],fraction),REP_LINE,1.5,true)
	for i in gold_points.size():
		if int(entries[i].day)==today and (progress<1.0 or (i>0 and line_progress<1.0)): continue
		var p := gold_points[i]
		draw_circle(p,3.5,GOLD_LINE,true,-1,true)
		draw_circle(p,1.5,SproutTheme.CREAM,true,-1,true)
		var q := rep_points[i]
		draw_rect(Rect2(q-Vector2(2.5,2.5),Vector2(5,5)),REP_LINE)
	draw_line(Vector2(470,29),Vector2(495,29),GOLD_LINE,2,true)
	draw_circle(Vector2(483,29),3,GOLD_LINE,true,-1,true)
	draw_line(Vector2(552,29),Vector2(574,29),REP_LINE,1.5,true)
	draw_rect(Rect2(561,26.5,5,5),REP_LINE)
