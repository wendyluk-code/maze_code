extends Node2D
const STATS_FONT: Font = preload("res://assets/ui/combat_stats_font.tres")
const FrogCounter=preload("res://scripts/maze/wind_frog_counter.gd")
const FrogFrames=preload("res://scripts/maze/wind_frog_frames.gd")
## 四方向四帧动画；移动时切换朝向，停下保留最后方向。
var config: Dictionary
var body: Sprite2D
var label: Label
var health_bar: ProgressBar
var hp_label: Label
var frames: Array[Texture2D] = []
var elapsed := 0.0
var combat_label_offset := 0.0
var combat_label_avoid: Control
var shadow: Sprite2D
var ground_contacts: Array[Vector2] = []
var all_frames: Array[Texture2D] = []
var all_ground_contacts: Array[Vector2] = []
var facing := 0
var frame_width := 1.0
var action := "idle"
var action_time := 0.0
var action_paused := false
var action_sheets := {}
var action_duration := 0.72
var frog_state: Dictionary = {}
var frog_combat: Dictionary = {}
var frog_motion: RefCounted
var frog_motion_direction := -1
var frog_front24: RefCounted
var frog_defeated_belly := false
var rock_state: Dictionary = {}
var rock_lunge_pose: Dictionary = {}
var rock_entry_pose: Dictionary = {}
var rock_previous_phase: String = ""
var rock_visible_bounds: Dictionary = {}
var rock_gait:=0.0
var rock_pose_age:=0.0
var rock_sync_age:=0.0
var rock_sync_clock:=-1.0
var rock_move_velocity:=Vector2.ZERO
var rock_turn_candidate:=-1
var rock_turn_age:=0.0
var roar_visual: Node2D
var water_velocity := Vector2.ZERO
var wake_clock := 0.0
var wake_rings: Array[Dictionary] = []
var membrane: Sprite2D
var membrane_clock := 0.0
var membrane_phase := 0.0
var membrane_scale := 1.0
var fish_combat: Dictionary={}
var fish_state: Dictionary={}
var eel_combat: Dictionary={}
var eel_state: Dictionary={}
var eel_contacts: Array[float]=[]
var membrane_pieces: Array[Sprite2D]=[]
var return_water_visual: Node2D
var hit_visual: Node2D
var heal_visual: Node2D
var exhaustion_visual: Node2D

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
			for key in ["charge","rush","brake","exhausted"]: action_sheets[key]=load(config.animation_dir+key+".png")
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
	if config.kind=="wind_frog":
		frog_motion=FrogFrames.new()
		frog_motion.load_frames(148.0/192.0*float(config.width))
		frog_motion.prepare_directions(action_sheets)
		membrane=Sprite2D.new()
		membrane.texture=load("res://assets/effects/fenshui/protection_bubble.png")
		membrane.scale=Vector2.ONE*float(config.width)*(220.0/155.0)/membrane.texture.get_width()
		membrane_scale=membrane.scale.x
		membrane.position=Vector2(0,-27)
		membrane.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		membrane.hide()
		add_child(membrane)
	if config.kind in ["silverfish","thunder_eel"]:
		if config.kind=="silverfish":
			action_sheets.stranded=load(config.animation_dir+"stranded.png") as Texture2D
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
		# Godot资源缓存让所有实例共用一张已认可的原图，不逐只解码膜图集。
		membrane.texture=load("res://assets/effects/fenshui/protection_bubble.png")
		var bubble_ratio:=190.0/128.0 if config.kind=="silverfish" else 220.0/155.0
		membrane.scale=Vector2.ONE*float(config.width)*bubble_ratio/membrane.texture.get_width()
		membrane_scale=membrane.scale.x
		membrane_phase=fposmod(float(str(config.id).hash())*2.399963,TAU)
		membrane.position=Vector2(0,(0.5-float(config.get("anchor",0.65)))*float(config.width))
		membrane.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		membrane.hide()
		add_child(membrane)
		# 分水庭独立命中图集替换旧四块碎膜，保留空列表兼容旧观察入口。
		if config.kind=="thunder_eel":
			exhaustion_visual=preload("res://scripts/maze/eel_exhaustion_visual.gd").new()
			exhaustion_visual.width=float(config.width)
			add_child(exhaustion_visual)
	if config.kind in ["silverfish","thunder_eel","wind_frog"]:
		return_water_visual=preload("res://scripts/maze/return_water_visual.gd").new()
		add_child(return_water_visual)
		visibility_changed.connect(_clear_return_water_when_hidden)
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
	if config.kind=="rockmane":
		roar_visual=preload("res://scripts/maze/rockmane_roar_visual.gd").new()
		roar_visual.monster=self
		get_parent().add_child.call_deferred(roar_visual)
		visibility_changed.connect(func():
			if not is_visible_in_tree() and is_instance_valid(roar_visual): roar_visual.clear())

func _exit_tree() -> void:
	if is_instance_valid(roar_visual): roar_visual.queue_free()

func _clear_return_water_when_hidden() -> void:
	# 隐藏事件不等显示时钟，局部停顿或地图暂停时也要清除旧汗滴。
	if not is_visible_in_tree() and is_instance_valid(return_water_visual): return_water_visual.clear()
	if not is_visible_in_tree() and is_instance_valid(hit_visual): hit_visual.clear()
	if not is_visible_in_tree() and is_instance_valid(heal_visual): heal_visual.clear()
	if not is_visible_in_tree() and is_instance_valid(exhaustion_visual): exhaustion_visual.clear()

func enable_hit_feedback() -> void:
	if hit_visual!=null: return
	hit_visual=preload("res://scripts/maze/fenshui_hit_feedback.gd").new()
	add_child(hit_visual)
	# 巨蛙命中层固定采用普通鱼48宽的标定，身体大小和受击形变不传给特效。
	hit_visual.install(body,float(config.get("width",48.0)),config.kind=="wind_frog")
	if config.kind=="rockmane": body.material.shader=preload("res://scripts/maze/rock_motion.gdshader")
	if config.kind=="wind_frog":
		heal_visual=preload("res://scripts/maze/fenshui_heal_visual.gd").new()
		add_child(heal_visual)
		heal_visual.clear()

func _draw_frame(index: int) -> void:
	if config.kind=="wind_frog" and frog_front24!=null and not frog_state.is_empty():
		var direction: int=FrogCounter.facing(frog_state)%2
		var pose: int=frog_front24.pose(frog_state,action_time,action=="defeated",frog_defeated_belly)
		frog_front24.draw_pose(body,pose,direction)
		if frog_state.frog_phase=="airborne" and action!="defeated": body.position.y=-36.0*sin((1.0-float(frog_state.frog_left)/FrogCounter.flight_time(frog_state))*PI)
		membrane.position=frog_front24.body_center(body)
		var forming: bool=float(frog_state.get("frog_form_left",0.0))>0 and float(frog_state.get("electric_left",0.0))<=0 and frog_state.frog_phase not in ["exposed","recovering"] and FrogCounter.Boss.water(FrogCounter.vec(frog_state.position))
		membrane.visible=action!="defeated" and (FrogCounter.shielded(frog_combat,config.id) or forming)
		membrane.modulate.a=1.0-float(frog_state.get("frog_form_left",0.0)) if forming else 1.0
		layout_frog_label()
		return
	if config.kind=="wind_frog" and action=="special" and frog_motion!=null and not frog_state.is_empty() and frog_state.hp>0 and FrogCounter.enabled(frog_combat,config.id):
		var direction: int=frog_motion_direction if frog_motion_direction>=0 else FrogCounter.facing(frog_state)
		var phase: String=frog_state.frog_phase
		if float(frog_state.get("frog_spit_left",0.0))>0.0 and phase not in ["toppling","exposed","recovering"]:
			frog_motion.draw_sheet(body,action_sheets.attack,2 if float(frog_state.frog_spit_left)>0.14 else 3,direction,float(config.width))
		elif frog_state.mode=="windup" and phase=="active":
			frog_motion.draw_sheet(body,action_sheets.attack,0 if float(frog_state.windup)>preload("res://scripts/maze/combat_tuning.gd").effect("water","windup",800.0)/2000.0 else 1,direction,float(config.width))
		elif phase in ["dormant","active","emerging"]:
			frog_motion.draw_sheet(body,action_sheets.idle,int(action_time/0.18)%4,direction,float(config.width))
		else:
			frog_motion.draw_direction_pose(body,FrogFrames.pose(frog_state),direction)
		if frog_state.frog_phase=="airborne": body.position.y=-36.0*sin((1.0-float(frog_state.frog_left)/FrogCounter.flight_time(frog_state))*PI)
		elif frog_state.frog_phase=="dormant": body.position.y=-18.0*sin(float(frog_state.frog_left)/0.35*PI) if frog_state.frog_left<0.35 else 0.0
		# 膜包裹可见身体，沿用原图与尺度；不能留在地面锚点。
		membrane.position=frog_motion.body_center(body,FrogFrames.pose(frog_state),direction)
		var forming: bool=float(frog_state.get("frog_form_left",0.0))>0.0 and float(frog_state.get("electric_left",0.0))<=0.0 and frog_state.frog_phase not in ["exposed","recovering"] and FrogCounter.Boss.water(FrogCounter.vec(frog_state.position))
		membrane.visible=FrogCounter.shielded(frog_combat,config.id) or forming
		membrane.modulate.a=1.0-float(frog_state.get("frog_form_left",0.0)) if forming else 1.0
		layout_frog_label()
		return
	if config.kind=="wind_frog" and action=="defeated" and frog_motion!=null:
		frog_motion.draw_sheet(body,action_sheets.defeated,index,facing,float(config.width))
		membrane.hide()
		layout_frog_label()
		return
	if not action_sheets.is_empty():
		var texture: Texture2D = action_sheets[action]
		var cell := Vector2(texture.get_width()/4.0,texture.get_height()/4.0)
		body.texture=texture
		body.region_enabled=true
		body.region_rect=Rect2(Vector2(index,facing)*cell,cell)
		if config.kind=="rockmane" and body.material!=null and body.material.shader==preload("res://scripts/maze/rock_motion.gdshader"):
			var p: Dictionary=rock_lunge_pose
			body.material.set_shader_parameter("next_sheet",action_sheets.get(p.get("next_action",action),texture))
			body.material.set_shader_parameter("next_cell",Vector2(p.get("next_frame",index),facing))
			body.material.set_shader_parameter("pose_blend",p.get("blend",0.0))
			body.material.set_shader_parameter("motion_scale",p.get("squash",Vector2.ONE))
			body.material.set_shader_parameter("motion_angle",p.get("angle",0.0))
			var entry: Dictionary=p.get("entry",{})
			var entry_action: String=str(entry.get("action",action))
			var entry_row: int=int(entry.get("row",facing))
			body.material.set_shader_parameter("entry_sheet",action_sheets.get(entry_action,texture))
			body.material.set_shader_parameter("entry_next_sheet",action_sheets.get(entry.get("next_action",entry_action),texture))
			body.material.set_shader_parameter("entry_cell",Vector2(entry.get("frame",index),entry_row))
			body.material.set_shader_parameter("entry_next_cell",Vector2(entry.get("next_frame",index),entry_row))
			body.material.set_shader_parameter("entry_pose_blend",entry.get("blend",0.0))
			body.material.set_shader_parameter("entry_mix",p.get("entry_mix",1.0))
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
			membrane.visible=formal and not broken and (shielded or forming) and action!="defeated"
			if membrane.visible:
				membrane.modulate.a=1.0-clampf(float(state.get("eel_left" if is_eel else "fish_left",0.0)),0,1) if forming else 1.0
		if is_instance_valid(exhaustion_visual): exhaustion_visual.apply(body,membrane,eel_state,eel_combat,str(config.id))
		label.position.y=-cell.y*body.scale.y*0.65-38-combat_label_offset
		if config.kind=="rockmane": _update_rock_occlusion()
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

func set_frog_motion_direction(direction: int) -> bool:
	# 仅完整方向可启用；固定候选方向不等于自动四向已经补齐。
	if config.kind!="wind_frog" or frog_motion==null: return false
	var index: int=FrogFrames.pose(frog_state) if not frog_state.is_empty() else 0
	if not frog_motion.draw_direction_pose(body,index,direction): return false
	frog_motion_direction=direction
	_draw_frame(frame_index())
	return true

func enable_frog_front24() -> bool:
	if config.kind!="wind_frog": return false
	if frog_front24!=null: return true
	var candidate=preload("res://scripts/maze/wind_frog_front24.gd").new()
	if not candidate.load_frames(148.0/192.0*float(config.width)*1.4): return false
	frog_front24=candidate
	membrane_scale*=1.4
	membrane.scale=Vector2.ONE*membrane_scale
	shadow.scale*=1.4
	_draw_frame(frame_index())
	return true

func preview_frog_direction_key(direction: int, index: int) -> bool:
	# 仅核对四张已交付关键姿态；正常战斗不从这里补造连续方向动画。
	if config.kind!="wind_frog" or frog_motion==null: return false
	if not frog_motion.draw_direction_key(body,index,direction): return false
	membrane.position=body.position+body.get_rect().get_center()*body.scale
	membrane.visible=index in [0,3] and FrogCounter.shielded(frog_combat,config.id)
	layout_frog_label()
	return true

func _update_rock_occlusion() -> void:
	# 岩鬃兽始终不透明；实体互斥由脚底碰撞负责，前后关系由排序负责。
	body.self_modulate.a=1.0

func _rock_visible_rect(sprite: Sprite2D) -> Rect2:
	# 缓存各帧的非透明外接框，避免每帧读取图像，也不把留白当遮挡。
	var key:=str(sprite.texture.get_instance_id())+str(sprite.region_rect if sprite.region_enabled else Rect2())
	if not rock_visible_bounds.has(key):
		var image:=sprite.texture.get_image()
		if sprite.region_enabled: image=image.get_region(Rect2i(sprite.region_rect))
		rock_visible_bounds[key]=Rect2(image.get_used_rect())
	var used: Rect2=rock_visible_bounds[key]
	return sprite.get_global_transform()*Rect2(sprite.get_rect().position+used.position,used.size)

func layout_frog_label() -> void:
	# 正式巨蛙原短条样式不变；只在与主角标签相撞时向上留出间距。
	label.position=Vector2(-30,-float(config.width)*0.65*(1.4 if frog_front24!=null else 1.0)-38)
	combat_label_offset=0.0
	if not is_instance_valid(combat_label_avoid) or not label.is_visible_in_tree() or not combat_label_avoid.is_visible_in_tree(): return
	var own:=label.get_global_rect()
	var hero:=combat_label_avoid.get_global_rect()
	if config.kind=="rockmane":
		var hero_body:=combat_label_avoid.get_parent().get_node_or_null("Body") as Sprite2D
		if is_instance_valid(hero_body) and hero_body.is_visible_in_tree():
			hero=hero.merge(hero_body.get_global_transform()*hero_body.get_rect())
	if own.grow(2.0).intersects(hero.grow(2.0)):
		combat_label_offset=own.end.y-hero.position.y+6.0
		label.position.y-=combat_label_offset
	if config.kind=="rockmane":
		var view: Rect2=get_viewport().get_canvas_transform().affine_inverse()*get_viewport_rect()
		# 给顶部资源栏与锁定标记留出屏幕像素安全区，而非仅防止裁出视口。
		var zoom: float=get_viewport().get_canvas_transform().y.length()
		var min_y: float=view.position.y+110.0/maxf(zoom,0.01)
		if label.global_position.y<min_y:
			label.global_position.y=min_y
			if label.get_global_rect().grow(2.0).intersects(hero.grow(2.0)):
				label.global_position.x=hero.end.x+6.0
				if label.get_global_rect().end.x>view.end.x-6.0:
					label.global_position.x=hero.position.x-label.size.x-6.0
			combat_label_offset=-float(config.width)*0.65-38-label.position.y

func _set_direction(direction: int) -> void:
	facing = direction
	frames.assign(all_frames.slice(direction*4,direction*4+4))
	ground_contacts.assign(all_ground_contacts.slice(direction*4,direction*4+4))

func update_motion(velocity: Vector2) -> void:
	water_velocity=velocity
	# 岩鬃兽由同一显示入口选择移动朝向或技能锁向，不在一次同步中切两次行。
	if config.kind=="rockmane": return
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

func _rock_face(velocity: Vector2, locked: bool) -> void:
	if velocity.length_squared()<0.01: return
	var left: bool=facing in [1,3]
	var up: bool=facing in [2,3]
	if absf(velocity.x)>absf(velocity.y)*0.28: left=velocity.x<0.0
	if absf(velocity.y)>absf(velocity.x)*0.28: up=velocity.y<0.0
	elif locked: up=false
	var direction: int=(1 if left else 0)+(2 if up else 0)
	if direction==facing:
		rock_turn_candidate=-1
		rock_turn_age=0.0
		return
	if locked:
		_set_direction(direction)
		rock_turn_candidate=-1
		rock_turn_age=0.0
	elif rock_turn_candidate!=direction:
		rock_turn_candidate=direction
		rock_turn_age=0.0
	elif rock_turn_age>=0.10:
		_set_direction(direction)
		rock_turn_candidate=-1
		rock_turn_age=0.0

func _refresh_rock_pose() -> void:
	if rock_state.is_empty() or rock_state.hp<=0: return
	var phase: String=str(rock_state.get("rock_phase","active"))
	var mapping=preload("res://scripts/maze/rock_lunge_visual_mapping.gd")
	if phase in ["active","combo_reposition"]:
		rock_lunge_pose=mapping.walk(rock_gait,rock_entry_pose,rock_pose_age,rock_move_velocity.length_squared()>0.01)
		_rock_face(rock_move_velocity,false)
	else:
		var durations: Dictionary=preload("res://scripts/maze/rockmane_combat.gd").LUNGE_DURATIONS.duplicate()
		var tune=preload("res://scripts/maze/combat_tuning.gd")
		durations.merge({"charge":tune.number("rock.roar","charge",1.1),"rush":tune.number("rock.roar","release",0.45),"rest":tune.number("rock.roar","rest",5.0)})
		if rock_state.get("rock_combo",false):
			durations.lunge_charge=preload("res://scripts/maze/rockmane_combat.gd").charge_duration(rock_state)
			durations.lunge_recover=preload("res://scripts/maze/rockmane_combat.gd").recover_duration(rock_state)
		if durations.has(phase):
			rock_lunge_pose=mapping.pose(phase,maxf(0.0,float(rock_state.rock_left)-rock_sync_age),float(durations[phase]),rock_entry_pose,bool(rock_state.get("rock_combo",false)),int(rock_state.get("rock_chain_left",0))==1)
		_rock_face(Vector2(rock_state.rock_aim[0],rock_state.rock_aim[1]),true)
	if not rock_lunge_pose.is_empty(): action=str(rock_lunge_pose.action)

func _animate_membrane(delta: float) -> void:
	# 只在真实保护可见时计算两个正弦；暂停沿用父流程的set_process(false)。
	if not is_instance_valid(membrane) or not membrane.visible or not is_visible_in_tree(): return
	if not get_viewport_rect().grow(float(config.width)*2.0).has_point(get_global_transform_with_canvas().origin): return
	membrane_clock+=delta
	var angle:=membrane_clock/2.4*TAU+membrane_phase
	var stretch:=sin(angle)*0.025
	membrane.scale=Vector2(1.0+stretch,1.0-stretch)*membrane_scale
	membrane.rotation=deg_to_rad(sin(angle*0.8)*1.2)

func _process(delta: float) -> void:
	if is_instance_valid(hit_visual): hit_visual.advance(delta)
	if is_instance_valid(heal_visual): heal_visual.advance(delta,body,float(config.width)*(1.4 if frog_front24!=null else 1.0))
	if action_paused: return
	elapsed += delta
	if config.kind=="rockmane" and not rock_state.is_empty() and rock_state.hp>0:
		rock_pose_age+=delta
		rock_sync_age=minf(0.10,rock_sync_age+delta)
		rock_turn_age+=delta
		if rock_state.get("rock_phase","") in ["active","combo_reposition"]:
			rock_gait=fposmod(rock_gait+rock_move_velocity.length()*delta/16.0,4.0)
		_refresh_rock_pose()
	# 正式鱼的预警、冲刺和搁浅帧直接跟随已提交剩余时间，不再叠加一遍渲染delta。
	if action=="defeated" or fish_combat.is_empty() or not preload("res://scripts/maze/silverfish_combat.gd").enabled(fish_combat,config.id) or fish_state.get("fish_phase","") not in ["warning","rush","stranded"]:
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
	_animate_membrane(delta)
	if is_instance_valid(return_water_visual):
		# 汗滴按基础体型定尺寸；实际头部锚点仍由body矩形与缩放提供。
		return_water_visual.advance(delta,body,float(config.width),config.kind,facing)

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
	if config.kind=="rockmane" and not rock_lunge_pose.is_empty(): return int(rock_lunge_pose.frame)
	if config.kind=="wind_frog" and action=="special" and not frog_state.is_empty() and FrogCounter.enabled(frog_combat,config.id): return FrogFrames.pose(frog_state)
	if config.kind=="thunder_eel" and not eel_combat.is_empty() and preload("res://scripts/maze/thunder_eel_combat.gd").enabled(eel_combat,config.id):
		if eel_state.get("eel_phase","")=="exhausted": return 0
		if eel_state.get("eel_phase","")=="charging": return clampi(int((1.2-float(eel_state.eel_left))/1.2*2),0,1)
		if eel_state.get("eel_phase","")=="discharge": return clampi(2+int((0.35-float(eel_state.eel_left))/0.35*2),2,3)
	if is_instance_valid(return_water_visual) and return_water_visual.returning and config.kind in ["silverfish","thunder_eel"]: return int(action_time/0.12)%4
	if action=="shore": return int(action_time/0.32)%4
	if action=="stranded": return 2+int(action_time/0.18)%2
	if action=="special":
		if frog_state.get("frog_phase","")=="dormant": return 2 if float(frog_state.frog_left)<0.35 else 3
		return {"emerging":0,"warning":1,"airborne":2,"landing":3}.get(frog_state.get("frog_phase",""),1)
	if action in ["attack","defeated"]: return mini(3,int(action_time/action_duration*4.0))
	return int(action_time/0.18)%4 if not action_sheets.is_empty() else int(elapsed/0.18)%4

func sync_action(actor: Dictionary, combat: Dictionary={}) -> void:
	if actor.hp<=0:
		if is_instance_valid(hit_visual): hit_visual.clear()
		if is_instance_valid(heal_visual): heal_visual.clear()
	if is_instance_valid(return_water_visual): return_water_visual.sync(actor,combat,config.kind)
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
				action_duration=preload("res://scripts/maze/silverfish_editor.gd").seconds("windup")
				action_time=action_duration-float(actor.fish_left) if phase=="warning" else action_duration
			if phase=="stranded": action_time=2.5-float(actor.fish_left)
			_draw_frame(frame_index())
			return
	if config.kind=="wind_frog":
		if actor.hp<=0 and action!="defeated": frog_defeated_belly=actor.get("frog_phase","") in ["exposed","recovering"]
		frog_state=actor
		frog_combat=combat
		if FrogCounter.enabled(combat,config.id):
			# 同层只按地面脚底比较主角，身体跃起不改变深度；保留其他层级。
			var player:=get_parent().get_node_or_null("Player") as Node2D
			if is_instance_valid(player) and z_index==player.z_index:
				var behind: bool=global_position.y<player.global_position.y
				if behind==(get_index()>player.get_index()):
					get_parent().move_child(self,player.get_index())
		body.position.y=-36.0*sin((1.0-float(actor.frog_left)/FrogCounter.flight_time(actor))*PI) if actor.frog_phase=="airborne" else 0.0
		if actor.frog_phase=="dormant" and actor.hp>0:
			body.position.y=-18.0*sin(float(actor.frog_left)/0.35*PI) if actor.frog_left<0.35 else 0.0
		queue_redraw()
		if FrogCounter.enabled(combat,config.id): _set_direction(FrogCounter.facing(actor))
		else:
			if actor.mode=="windup": update_motion(Vector2(actor.frog_aim[0],actor.frog_aim[1]))
			if actor.frog_phase in ["warning","airborne"]: update_motion(Vector2(actor.frog_target[0],actor.frog_target[1])-Vector2(actor.frog_origin[0],actor.frog_origin[1]))
		if actor.hp>0:
			action="special"
			_draw_frame(frame_index())
			return
	if config.kind=="rockmane":
		var incoming_phase: String=str(actor.get("rock_phase",""))
		var incoming_key: String=incoming_phase
		if incoming_phase=="active": incoming_key+="_walk" if Vector2(actor.velocity[0],actor.velocity[1]).length_squared()>0.01 else "_idle"
		if incoming_key!=rock_previous_phase:
			rock_entry_pose=rock_lunge_pose.duplicate() if not rock_lunge_pose.is_empty() else {"action":action,"frame":frame_index(),"next_action":action,"next_frame":frame_index(),"blend":0.0}
			rock_entry_pose.erase("entry")
			rock_entry_pose.erase("entry_mix")
			rock_entry_pose.row=facing
			rock_previous_phase=incoming_key
			rock_pose_age=0.0
			rock_sync_age=0.0
			if incoming_phase in ["active","combo_reposition"]: rock_gait=0.0
		rock_lunge_pose={}
		rock_state=actor.duplicate(true)
		rock_move_velocity=Vector2(actor.velocity[0],actor.velocity[1])
		var incoming_clock: float=float(combat.get("elapsed",-1.0))
		if not is_equal_approx(incoming_clock,rock_sync_clock):
			rock_sync_age=0.0
			rock_sync_clock=incoming_clock
		# 与巨蛙一致，只按地面脚底排序；身体尺寸不改变碰撞或站位。
		var player:=get_parent().get_node_or_null("Player") as Node2D
		if is_instance_valid(player) and z_index==player.z_index:
			var behind: bool=global_position.y<player.global_position.y
			if behind==(get_index()>player.get_index()):
				get_parent().move_child(self,player.get_index())
		_refresh_rock_pose()
		if actor.hp>0:
			if is_instance_valid(roar_visual): roar_visual.apply(actor,combat)
			_draw_frame(frame_index())
			queue_redraw()
			return
	if config.kind=="rockmane" and actor.hp>0 and actor.rock_phase in ["charge","rush"]:
		if is_instance_valid(roar_visual): roar_visual.apply(actor,combat)
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
		if is_instance_valid(roar_visual): roar_visual.apply(actor,combat)
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
	if config.get("kind","") in ["silverfish","thunder_eel"]:
		for ring in wake_rings:
			var progress: float=ring.age/1.1
			_draw_ripple(ring.point-position,9.0+progress*23.0,(1.0-progress)*0.55)
	if config.get("kind","")!="wind_frog" or frog_state.is_empty() or frog_state.hp<=0: return
	# 仅L候选由同水域显示消费者接管，原K/G入口不改。
	if has_meta("slam_area_preview"): return
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
