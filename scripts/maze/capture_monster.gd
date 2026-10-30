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
var membrane: Sprite2D
var membrane_sheets: Dictionary={}
var fish_combat: Dictionary={}
var fish_state: Dictionary={}
var eel_combat: Dictionary={}
var eel_state: Dictionary={}
var eel_contacts: Array[float]=[]
var membrane_pieces: Array[Sprite2D]=[]

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
	if config.kind in ["silverfish","thunder_eel"]:
		# 新位图只在建节点时解码；保留独立透明膜，不用程序重画膜面。
		for key in ["idle","swim","attack"]:
			membrane_sheets[key]=ImageTexture.create_from_image(Image.load_from_file(config.animation_dir+"shield_"+key+".png"))
		if config.kind=="silverfish":
			action_sheets.stranded=ImageTexture.create_from_image(Image.load_from_file(config.animation_dir+"stranded.png"))
		else:
			# 岸行候选复用主体，不重画：去水纹、慢蜿蜒，逐帧脚底贴地。
			action_sheets.shore=action_sheets.swim
			var swim_image: Image=action_sheets.swim.get_image()
			var side:=swim_image.get_width()/4
			for frame in 16:
				var bottom:=0
				for y in side:
					for x in side:
						if swim_image.get_pixel((frame%4)*side+x,(frame/4)*side+y).a>=0.5: bottom=maxi(bottom,y)
				eel_contacts.append(float(bottom+1))
		membrane=Sprite2D.new()
		membrane.centered=false
		membrane.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		membrane.hide()
		add_child(membrane)
		if config.kind=="silverfish":
			for i in 4:
				var piece:=Sprite2D.new()
				piece.centered=false
				piece.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
				piece.hide()
				add_child(piece)
				membrane_pieces.append(piece)
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
		if action=="shore": body.offset.y=-eel_contacts[facing*4+index]+2.0
		if is_instance_valid(membrane):
			var Fish=preload("res://scripts/maze/silverfish_combat.gd")
			var Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
			var is_eel: bool=config.kind=="thunder_eel"
			var combat: Dictionary=eel_combat if is_eel else fish_combat
			var state: Dictionary=eel_state if is_eel else fish_state
			var formal: bool=not combat.is_empty() and (Eel.enabled(combat,config.id) if is_eel else Fish.enabled(combat,config.id))
			var forming: bool=formal and state.get("eel_phase" if is_eel else "fish_phase","")=="forming"
			var shielded: bool=formal and (Eel.shielded(combat,config.id) if is_eel else Fish.shielded(combat,config.id))
			var broken: bool=not is_eel and float(state.get("electric_left",0.0))>0.0
			membrane.visible=formal and not broken and (shielded or forming) and membrane_sheets.has(action)
			if membrane.visible:
				membrane.texture=membrane_sheets[action]
				membrane.region_enabled=true
				membrane.region_rect=body.region_rect
				membrane.scale=body.scale
				membrane.offset=body.offset
				membrane.modulate.a=1.0-clampf(float(state.get("eel_left" if is_eel else "fish_left",0.0)),0,1) if forming else 1.0
			for i in membrane_pieces.size():
				var piece: Sprite2D=membrane_pieces[i]
				var progress: float=(4.0-float(state.get("electric_left",0.0)))/0.3
				piece.visible=formal and broken and progress>=0 and progress<1 and membrane_sheets.has(action)
				if piece.visible:
					var quadrant:=Vector2(i%2,i/2)
					piece.texture=membrane_sheets[action]
					piece.region_enabled=true
					piece.region_rect=Rect2(body.region_rect.position+quadrant*cell*0.5,cell*0.5)
					piece.scale=body.scale
					piece.position=(body.offset+quadrant*cell*0.5)*body.scale+(quadrant*2-Vector2.ONE)*9.0*progress
					piece.modulate.a=1.0-progress
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
	# 正式鱼的预警、冲刺和搁浅帧直接跟随已提交剩余时间，不再叠加一遍渲染delta。
	if fish_combat.is_empty() or not preload("res://scripts/maze/silverfish_combat.gd").enabled(fish_combat,config.id) or fish_state.get("fish_phase","") not in ["warning","rush","stranded"]:
		action_time += delta
	if config.kind in ["silverfish","thunder_eel"]:
		for ring in wake_rings: ring.age+=delta
		wake_rings=wake_rings.filter(func(r): return r.age<1.1)
		wake_clock+=delta
		if action=="shore": wake_rings.clear()
		if water_velocity.length_squared()>1.0 and action not in ["defeated","shore"] and wake_clock>=0.22:
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
	if config.kind=="thunder_eel" and not eel_combat.is_empty() and preload("res://scripts/maze/thunder_eel_combat.gd").enabled(eel_combat,config.id):
		if eel_state.get("eel_phase","")=="charging": return clampi(int((1.2-float(eel_state.eel_left))/1.2*2),0,1)
		if eel_state.get("eel_phase","")=="discharge": return clampi(2+int((0.35-float(eel_state.eel_left))/0.35*2),2,3)
	if action=="shore": return int(action_time/0.32)%4
	if action=="stranded": return 2+int(action_time/0.18)%2
	if action=="special":
		if frog_state.get("frog_phase","")=="dormant": return 2 if float(frog_state.frog_left)<0.35 else 3
		return {"emerging":0,"warning":1,"airborne":2,"landing":3}.get(frog_state.get("frog_phase",""),1)
	if action in ["attack","defeated"]: return mini(3,int(action_time/action_duration*4.0))
	return int(action_time/0.18)%4 if not action_sheets.is_empty() else int(elapsed/0.18)%4

func sync_action(actor: Dictionary, combat: Dictionary={}) -> void:
	if action_sheets.is_empty(): return
	if config.kind=="thunder_eel":
		eel_combat=combat
		eel_state=actor
		var Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
		if actor.hp>0 and Eel.enabled(combat,config.id):
			var phase: String=actor.get("eel_phase","idle")
			var on_shore: bool=not Eel.Water.water(Vector2(actor.position[0],actor.position[1]))
			var next: String="shore" if on_shore else ("attack" if phase in ["charging","discharge"] else ("swim" if Vector2(actor.velocity[0],actor.velocity[1]).length_squared()>0.01 else "idle"))
			if next!=action:
				action=next
				action_time=0.0
			if phase=="charging":
				action_duration=Eel.CHARGE_TIME
				action_time=maxf(0.0,action_duration-float(actor.eel_left))
			_draw_frame(frame_index())
			return
	if config.kind=="silverfish":
		fish_combat=combat
		fish_state=actor
		if actor.hp>0 and preload("res://scripts/maze/silverfish_combat.gd").enabled(combat,config.id):
			var phase: String=actor.get("fish_phase","idle")
			var next: String="stranded" if phase=="stranded" else ("attack" if phase in ["warning","rush"] else ("swim" if Vector2(actor.velocity[0],actor.velocity[1]).length_squared()>0.01 else "idle"))
			if next!=action:
				action=next
				action_time=0.0
			if phase in ["warning","rush"]:
				update_motion(Vector2(actor.fish_aim[0],actor.fish_aim[1]))
				action_duration=preload("res://scripts/maze/fenshui_borrow_lightning.gd").WARNING_FISH
				action_time=action_duration-float(actor.fish_left) if phase=="warning" else action_duration
			if phase=="stranded": action_time=2.5-float(actor.fish_left)
			_draw_frame(frame_index())
			return
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
