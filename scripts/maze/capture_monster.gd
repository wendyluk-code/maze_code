extends Node2D
const STATS_FONT: Font = preload("res://assets/ui/combat_stats_font.tres")
## 四方向四帧动画；移动时切换朝向，停下保留最后方向。
var config: Dictionary
var body: Sprite2D
var label: Label
var health_bar: ProgressBar
var hp_label: Label
var frames: Array[Texture2D] = []
var elapsed := 0.0
var combat_label_offset := 0.0
var shadow: Sprite2D
var ground_contacts: Array[Vector2] = []
var all_frames: Array[Texture2D] = []
var all_ground_contacts: Array[Vector2] = []
var facing := 0
var frame_width := 1.0
var action := "idle"
var action_time := 0.0
var action_sheets := {}
var action_duration := 0.72
var frog_state: Dictionary = {}
var rock_state: Dictionary = {}
var water_velocity := Vector2.ZERO
var wake_clock := 0.0
var wake_rings: Array[Dictionary] = []

func _ready() -> void:
	position = config.position
	var source: Texture2D = load(config.sheet)
	var image := source.get_image()
	var cell := Vector2i(image.get_width()/4,image.get_height()/4)
	for i in 16:
		var region := Rect2i(Vector2i((i%4)*cell.x,(i/4)*cell.y),cell)
		var part := image.get_region(region)
		var bounds := part.get_used_rect()
		var texture := AtlasTexture.new()
		texture.atlas = source
		texture.region = Rect2(region.position+bounds.position,bounds.size)
		all_frames.append(texture)
		frame_width = maxf(frame_width, texture.get_width())
		# 保持立绘原有裁切与位置，只定位不透明主体的最低接地点。
		var bottom := -1
		for y in part.get_height():
			for x in part.get_width():
				if part.get_pixel(x,y).a >= 0.5: bottom = maxi(bottom,y)
		var total_x := 0.0
		var count := 0
		for y in range(maxi(0,bottom-6),bottom+1):
			for x in part.get_width():
				if part.get_pixel(x,y).a >= 0.5:
					total_x += x
					count += 1
		all_ground_contacts.append(Vector2(total_x/maxi(1,count),bottom+1)-Vector2(bounds.position))
	if config.has("animation_dir"):
		for key in ["idle","swim","attack","defeated"]:
			action_sheets[key]=load(config.animation_dir+key+".png")
		if config.kind=="rockmane":
			for key in ["charge","rush"]: action_sheets[key]=load(config.animation_dir+key+".png")
		if config.kind=="wind_frog": action_sheets.special=load(config.animation_dir+"special.png")
	_set_direction(clampi(int(config.direction),0,3))
	shadow = Sprite2D.new()
	shadow.texture = preload("res://assets/characters/tieshan/ground_shadow.png")
	shadow.scale = Vector2(0.34,0.22)*(1.4 if config.kind=="lizard" else 1.0)
	add_child(shadow)
	body = Sprite2D.new()
	body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(body)
	label = Label.new()
	label.text = str(config.power)
	label.add_theme_font_override("font",STATS_FONT)
	label.add_theme_font_size_override("font_size",9)
	label.add_theme_color_override("font_color",SproutTheme.CREAM)
	label.add_theme_color_override("font_outline_color",SproutTheme.INK)
	label.add_theme_constant_override("outline_size",2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(60,40)
	label.position = Vector2(-30,-85 if config.kind=="lizard" else -66)
	add_child(label)
	hp_label=make_hp_label()
	label.add_child(hp_label)
	health_bar = make_health_bar(Color("d96b60"))
	label.add_child(health_bar)
	_draw_frame(0)

func _draw_frame(index: int) -> void:
	if not action_sheets.is_empty():
		var texture: Texture2D = action_sheets[action]
		var cell := Vector2(texture.get_width()/4.0,texture.get_height()/4.0)
		body.texture=texture
		body.region_enabled=true
		body.region_rect=Rect2(Vector2(index,facing)*cell,cell)
		body.scale=Vector2.ONE*float(config.width)/cell.x
		body.offset=-cell*Vector2(0.5,158.0/192.0 if config.kind=="wind_frog" else float(config.get("anchor",0.65)))
		label.position.y=-cell.y*body.scale.y*0.65-38-combat_label_offset
		return
	body.texture = frames[index]
	var width := 72.0 if config.kind=="lizard" else (36.4 if config.kind=="slime" else 52.0)
	# 四个方向使用统一缩放，转向时不因裁切宽度变化而忽大忽小。
	body.scale = Vector2.ONE*(width/frame_width)
	label.position.y = -frames[index].get_height()*body.scale.y-38-combat_label_offset
	body.offset = Vector2(-frames[index].get_width()/2.0,-frames[index].get_height())
	if config.kind in ["lizard", "snail"]:
		var contact := ground_contacts[index]
		if body.flip_h: contact.x = frames[index].get_width()-contact.x
		shadow.position = (body.offset + contact) * body.scale + Vector2(0,-2)

func _set_direction(direction: int) -> void:
	facing = direction
	frames.assign(all_frames.slice(direction*4,direction*4+4))
	ground_contacts.assign(all_ground_contacts.slice(direction*4,direction*4+4))

func update_motion(velocity: Vector2) -> void:
	water_velocity=velocity
	if velocity.length_squared() < 0.01: return
	# 原图行顺序：右下、左下、右上、左上。近水平/垂直时保留次轴，避免贴墙抖向。
	var left := facing in [1,3]
	var up := facing in [2,3]
	if absf(velocity.x) > absf(velocity.y)*0.12: left = velocity.x < 0
	if absf(velocity.y) > absf(velocity.x)*0.12: up = velocity.y < 0
	var direction := (1 if left else 0) + (2 if up else 0)
	if direction == facing: return
	_set_direction(direction)
	_draw_frame(frame_index())

func _process(delta: float) -> void:
	elapsed += delta
	action_time += delta
	if config.kind in ["silverfish","thunder_eel"]:
		for ring in wake_rings: ring.age+=delta
		wake_rings=wake_rings.filter(func(r): return r.age<1.1)
		wake_clock+=delta
		if water_velocity.length_squared()>1.0 and action!="defeated" and wake_clock>=0.22:
			wake_clock=0.0
			wake_rings.append({"point":position-water_velocity.normalized()*8.0,"age":0.0})
		queue_redraw()
	_draw_frame(frame_index())

func update_power_color(current_power: int) -> void:
	label.add_theme_color_override("font_color",Color("#ef7165") if int(config.power)>=current_power else SproutTheme.CREAM)

## 沿用角色详情的原生抗锯齿圆角进度条与米色轨道/绿色填充。
static func make_health_bar(fill := Color("a6b967"), height := 6.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position=Vector2(0,26)
	bar.size=Vector2(60,height)
	bar.show_percentage=false
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.step=0.0
	bar.add_theme_font_size_override("font_size",1)
	for entry in [["background",Color("#f2dfc2"),Color("#cda575")],["fill",fill,Color("#876b47")]]:
		var style := StyleBoxFlat.new()
		style.bg_color=entry[1]
		style.border_color=entry[2]
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.anti_aliasing=true
		bar.add_theme_stylebox_override(entry[0],style)
	bar.size=Vector2(60,height)
	bar.set_deferred("size",Vector2(60,height))
	return bar

static func make_hp_label() -> Label:
	var text := Label.new()
	text.add_theme_font_override("font",STATS_FONT)
	text.add_theme_font_size_override("font_size",9)
	text.add_theme_color_override("font_color",SproutTheme.CREAM)
	text.add_theme_color_override("font_outline_color",SproutTheme.INK)
	text.add_theme_constant_override("outline_size",2)
	text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	text.position=Vector2(0,12)
	text.size=Vector2(60,12)
	text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return text


func frame_index() -> int:
	if action=="special":
		if frog_state.get("frog_phase","")=="dormant": return 2 if float(frog_state.frog_left)<0.35 else 3
		return {"emerging":0,"warning":1,"airborne":2,"landing":3}.get(frog_state.get("frog_phase",""),1)
	if action in ["attack","defeated"]: return mini(3,int(action_time/action_duration*4.0))
	return int(action_time/0.18)%4 if not action_sheets.is_empty() else int(elapsed/0.18)%4

func sync_action(actor: Dictionary) -> void:
	if action_sheets.is_empty(): return
	if config.kind=="wind_frog":
		frog_state=actor
		body.position.y=-36.0*sin((1.0-float(actor.frog_left)/0.35)*PI) if actor.frog_phase=="airborne" else 0.0
		if actor.frog_phase=="dormant" and actor.hp>0:
			body.position.y=-18.0*sin(float(actor.frog_left)/0.35*PI) if actor.frog_left<0.35 else 0.0
		queue_redraw()
		if actor.mode=="windup": update_motion(Vector2(actor.frog_aim[0],actor.frog_aim[1]))
		if actor.frog_phase in ["warning","airborne"]: update_motion(Vector2(actor.frog_target[0],actor.frog_target[1])-Vector2(actor.frog_origin[0],actor.frog_origin[1]))
		if actor.hp>0:
			action="special"
			_draw_frame(frame_index())
			return
	if config.kind=="rockmane" and actor.hp>0 and actor.rock_phase in ["charge","rush"]:
		rock_state=actor
		queue_redraw()
		var roar_action: String="charge" if actor.rock_phase=="charge" else "attack"
		if action!=roar_action:
			action=roar_action
			action_time=0.0
		update_motion(Vector2(actor.rock_aim[0],actor.rock_aim[1]))
		_draw_frame(frame_index())
		return
	if config.kind=="rockmane":
		rock_state=actor
		queue_redraw()
	var next := "defeated" if actor.hp<=0 else ("attack" if actor.mode=="windup" else ("swim" if Vector2(actor.velocity[0],actor.velocity[1]).length_squared()>0.01 else "idle"))
	if next!=action:
		action=next
		action_time=0.0
	if action=="attack":
		if actor.has("attack_aim"): update_motion(Vector2(actor.attack_aim[0],actor.attack_aim[1]))
		action_duration=preload("res://scripts/maze/combat_simulation.gd").STATS[config.kind].get("windup",0.8)
		action_time=maxf(0.0,action_duration-float(actor.windup))
	else: action_duration=0.72
	_draw_frame(frame_index())

func _draw() -> void:
	if config.get("kind","")=="rockmane" and not rock_state.is_empty() and rock_state.hp>0 and rock_state.rock_phase=="rush":
		var aim:=Vector2(rock_state.rock_aim[0],rock_state.rock_aim[1]).angle()
		var progress:=clampf(1.0-float(rock_state.rock_left)/0.45,0,1)
		for i in 3:
			var radius:=30.0+fmod(progress+float(i)/3.0,1.0)*230.0
			draw_arc(Vector2(0,-16),radius,aim-deg_to_rad(35),aim+deg_to_rad(35),32,Color(1,0.87,0.64,(1.0-radius/280)*0.65),2,true)
	if config.get("kind","") in ["silverfish","thunder_eel"]:
		for ring in wake_rings:
			var progress: float=ring.age/1.1
			_draw_ripple(ring.point-position,9.0+progress*23.0,(1.0-progress)*0.55)
	if config.get("kind","")!="wind_frog" or frog_state.is_empty() or frog_state.hp<=0: return
	var phase: String=frog_state.frog_phase
	if phase=="landing":
		var progress:=1.0-float(frog_state.frog_left)/1.2
		_draw_ripple(Vector2.ZERO,25.0+progress*45.0,(1.0-progress)*0.9)
		_draw_ripple(Vector2.ZERO,15.0+progress*33.0,(1.0-progress)*0.6)
	if phase=="dormant" and frog_state.frog_left>=0.35:
		var progress: float=(frog_state.frog_left-0.35)/0.85
		_draw_ripple(Vector2.ZERO,20.0+progress*32.0,(1.0-progress)*0.7)
	if phase not in ["emerging","warning","airborne"]: return
	var center := Vector2.ZERO if phase=="emerging" else Vector2(frog_state.frog_target[0],frog_state.frog_target[1])-position
	_draw_ripple(center,30.0,0.5)

func _draw_ripple(center: Vector2, radius: float, alpha: float) -> void:
	var points:=PackedVector2Array()
	for i in 49:
		var angle:=float(i)*TAU/48.0
		points.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*0.38))
	draw_polyline(points,Color(0.74,0.96,1.0,alpha),1.4,true)
