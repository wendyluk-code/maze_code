extends Control
const Art := preload("res://scripts/ui/components/ganlu_art.gd")
const Service := preload("res://scripts/restaurant/ganlu_service.gd")
var amount := 0.0
var pouring := false
var elapsed := 0.0
var pot := Art.pot()
var cup := Art.cup()
var drops: Array[Vector2] = []
var velocities: Array[Vector2] = []
var ripples: Array[Vector2] = []
var tilt := 0.0
var wall_hits := 0
var volumes: Array[float] = []
var pending_volume := 0.0
var emitted_volume := 0.0
var surface_offsets := PackedFloat32Array()
var surface_speeds := PackedFloat32Array()
var simulation_time := 0.0
var calm_time := 0.0
var depths := PackedFloat32Array()
var flows := PackedFloat32Array()
const CELL_WIDTH := 80.0/33.0
const MOUTH := Vector2(-90,-33)
const STEP := 1.0/240.0
const PARCEL := 0.0077
const POINTS := 33

func mouth_position() -> Vector2:
	return Vector2(406,95)+MOUTH.rotated(tilt)

func _cup_left(y: float) -> float:
	return lerpf(230,240,clampf((y-125)/139,0,1))

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	reset_motion()

func reset_motion() -> void:
	drops.clear()
	velocities.clear()
	volumes.clear()
	ripples.clear()
	pending_volume = 0.0
	emitted_volume = 0.0
	amount = 0.0
	tilt = 0.0
	wall_hits = 0
	simulation_time = 0.0
	calm_time = 0.0
	surface_offsets.resize(POINTS)
	surface_speeds.resize(POINTS)
	depths.resize(POINTS)
	flows.resize(POINTS-1)
	depths.fill(0)
	flows.fill(0)
	surface_offsets.fill(0)
	surface_speeds.fill(0)

func emit_water(volume: float) -> void:
	pending_volume += volume
	emitted_volume += volume
	while pending_volume>=PARCEL:
		pending_volume -= PARCEL
		var age := pending_volume/0.22
		drops.append(mouth_position()+Vector2(-150*age,8*age+340*age*age))
		velocities.append(Vector2(-150,8+680*age))
		volumes.append(PARCEL)

func has_airborne_water() -> bool:
	return pending_volume>0.000001 or not drops.is_empty()

func _land(index: int) -> void:
	amount += volumes[index]
	var edge := lerpf(40,49,minf(amount,1.0))
	var impact := clampf((drops[index].x-(280-edge))/(edge*2),0,1)*(POINTS-1)
	var weights := PackedFloat32Array()
	var total := 0.0
	for j in range(POINTS):
		var distance := (float(j)-impact)/3.0
		var weight := exp(-distance*distance)
		weights.append(weight)
		total += weight
	# 入杯水量只进入撞击附近的单元，之后靠重力和流量向落点左右两侧铺开。
	for j in range(POINTS):
		depths[j] += volumes[index]*139*POINTS*weights[j]/total
		if j<POINTS-1 and absf(j-impact)<4:
			var direction := signf(float(j)+0.5-impact)
			var spread := 43.0*direction*exp(-pow((float(j)+0.5-impact)/3.0,2))
			flows[j] = lerpf(flows[j],spread,0.28)
	ripples.append(Vector2(drops[index].x,0))
	drops.remove_at(index)
	velocities.remove_at(index)
	volumes.remove_at(index)

func _depth_at(x: float) -> float:
	var edge := lerpf(40,49,minf(amount,1.0))
	var at := clampf((x-(280-edge))/(edge*2)*(POINTS-1),0,POINTS-1)
	return lerpf(depths[int(at)],depths[mini(int(at)+1,POINTS-1)],at-floorf(at))

func _process(delta: float) -> void:
	elapsed += delta
	tilt = lerpf(tilt,-0.27 if pouring else 0.0,1.0-exp(-delta*12.0))
	simulation_time += delta
	while simulation_time >= STEP:
		simulation_time -= STEP
		_simulate(STEP)
	queue_redraw()

func _simulate(dt: float) -> void:
	while pending_volume >= PARCEL or (not pouring and pending_volume>0.000001):
		var parcel := minf(PARCEL,pending_volume)
		pending_volume -= parcel
		drops.append(mouth_position())
		velocities.append(Vector2(-150,8))
		volumes.append(parcel)
	for i in range(drops.size()-1,-1,-1):
		velocities[i].y += dt*680
		drops[i] += velocities[i]*dt
		if drops[i].y>130 and drops[i].x<_cup_left(drops[i].y)+4:
			drops[i].x = _cup_left(drops[i].y)+4
			if velocities[i].x<0: wall_hits += 1
			# 碰壁后贴内壁下流，仍在空中的水不能计入杯内。
			velocities[i].x = 0
		var surface_y := 264-_depth_at(drops[i].x)
		if drops[i].y>=surface_y: _land(i)
	calm_time = calm_time+dt if not pouring and not has_airborne_water() else 0.0
	# 封闭杯壁处通量为零。内部相邻水柱的高度差驱动流动，波到壁后回返。
	var transfer := PackedFloat32Array()
	for i in range(POINTS-1):
		flows[i] += -680.0*(depths[i+1]-depths[i])/CELL_WIDTH*dt
		flows[i] *= exp(-dt*(3.8+minf(calm_time*12.0,10.0)))
		flows[i] = clampf(flows[i],-85,85)
		var source_depth := depths[i] if flows[i]>=0 else depths[i+1]
		var moved := flows[i]*source_depth*dt/CELL_WIDTH
		moved = clampf(moved,-depths[i+1]*0.45,depths[i]*0.45)
		transfer.append(moved)
	for i in range(POINTS-1):
		depths[i] -= transfer[i]
		depths[i+1] += transfer[i]
	# 守恒的相邻混合抑制单格尖刺，不增加或删除水量。
	var smooth := PackedFloat32Array()
	for i in range(POINTS-1): smooth.append((depths[i]-depths[i+1])*(0.095+minf(calm_time*0.24,0.145)))
	for i in range(POINTS-1):
		depths[i] -= smooth[i]
		depths[i+1] += smooth[i]
	for i in range(POINTS):
		surface_offsets[i] = amount*139-depths[i]
	for i in range(ripples.size()-1,-1,-1):
		ripples[i].y += dt
		if ripples[i].y>0.65: ripples.remove_at(i)

func _draw() -> void:
	var scale_factor := size/Vector2(560,350)
	draw_set_transform(Vector2.ZERO,0,scale_factor)
	draw_texture_rect(preload("res://assets/ui/ganlu/table.png"),Rect2(0,0,560,350),false)
	draw_texture_rect(cup,Rect2(218.5,108,123,183),false)
	if amount > 0:
		var front := PackedVector2Array()
		var back := PackedVector2Array()
		var floor_line := PackedVector2Array()
		for i in range(POINTS):
			var t := float(i)/(POINTS-1)
			var arc := sqrt(maxf(0,1-pow(2*t-1,2)))
			var bottom := 256+8*arc
			var center_y := clampf(256-depths[i],139,256)
			var ellipse := minf(11,depths[i]*0.6+2)*arc
			var left := _cup_left(center_y)
			var x := lerpf(left,560-left,t)
			front.append(Vector2(x,minf(center_y+ellipse,bottom-0.1)))
			back.append(Vector2(x,maxf(128,center_y-ellipse)))
			floor_line.append(Vector2(lerpf(_cup_left(256),560-_cup_left(256),t),bottom))
		# 按相邻截面分片，低水位干湿交界不生成自交的大多边形。
		for i in range(POINTS-1):
			_water_quad(front[i],front[i+1],floor_line[i+1],floor_line[i],Color(0.33,0.67,0.72,0.32))
			_water_quad(back[i],back[i+1],front[i+1],front[i],Color(0.53,0.79,0.80,0.52))
		draw_polyline(back,Color(0.73,0.89,0.86,0.5),1.2,true)
		draw_polyline(front,Color(0.78,0.94,0.91,0.8),1.8,true)
	var line_y := 264-Service.TARGET*139
	draw_dashed_line(Vector2(218,line_y),Vector2(342,line_y),Color("527e86"),2.0,6.0,true,true)
	draw_string(SproutTheme.FONT_CN,Vector2(101,line_y+5),"倒到这里：",HORIZONTAL_ALIGNMENT_LEFT,-1,20,SproutTheme.INK)
	draw_set_transform(Vector2(406,95)*scale_factor,tilt,scale_factor)
	draw_texture_rect(pot,Rect2(-106,-75,212,148),false)
	draw_set_transform(Vector2.ZERO,0,scale_factor)
	_draw_stream()

# 密集粒子合为单一轮廓，重力拉开间距后才断开；不逐颗画圆形高光。
func _draw_stream() -> void:
	var centers := PackedVector2Array()
	var widths := PackedFloat32Array()
	if pouring:
		centers.append(mouth_position())
		widths.append(6.8)
	for i in range(drops.size()-1,-1,-1):
		var speed := velocities[i].length()
		var radius := clampf(6.8*sqrt(85.0/maxf(speed,85.0)),3.6,6.8)
		if not centers.is_empty() and centers[-1].distance_to(drops[i]) > 48.0:
			_draw_water_segment(centers,widths)
			centers.clear()
			widths.clear()
		centers.append(drops[i])
		widths.append(radius)
	_draw_water_segment(centers,widths)

func _draw_water_segment(centers: PackedVector2Array, widths: PackedFloat32Array) -> void:
	if centers.is_empty(): return
	if centers.size()==1:
		var center := centers[0]
		var radius := widths[0]
		var oval := PackedVector2Array()
		for i in range(24):
			var angle := TAU*i/24.0
			oval.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*1.65))
		draw_colored_polygon(oval,Color("7bbac4"))
		draw_polyline(oval,Color(0.65,0.85,0.86,0.6),0.8,true)
		return
	# 分段凸四边形避免壶嘴转动时短水流轮廓自交；同色接缝合为连续水柱。
	var highlight := PackedVector2Array()
	for i in range(centers.size()):
		draw_circle(centers[i],widths[i],Color("7bbac4"),true,-1,true)
		if i==centers.size()-1: continue
		var tangent := (centers[i+1]-centers[i]).normalized()
		if tangent.length_squared()<0.5: continue
		var normal := Vector2(-tangent.y,tangent.x)
		draw_colored_polygon(PackedVector2Array([
			centers[i]+normal*widths[i],centers[i+1]+normal*widths[i+1],
			centers[i+1]-normal*widths[i+1],centers[i]-normal*widths[i]]),Color("7bbac4"))
		highlight.append(centers[i]+normal*widths[i]*0.4)
		if i==centers.size()-2: highlight.append(centers[i+1]+normal*widths[i+1]*0.4)
	if highlight.size()>1:
		draw_polyline(highlight,Color(0.85,0.95,0.94,0.75),1.5,true)

func _water_quad(a: Vector2,b: Vector2,c: Vector2,d: Vector2,color: Color) -> void:
	if absf((b-a).cross(c-a))>0.001:
		draw_colored_polygon(PackedVector2Array([a,b,c]),color)
	if absf((c-a).cross(d-a))>0.001:
		draw_colored_polygon(PackedVector2Array([a,c,d]),color)
