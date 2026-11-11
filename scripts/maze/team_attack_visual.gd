extends Node2D
## 只读成功事务的状态；人物动作、飞行弹、碰撞特效分别绘制。
const Run = preload("res://scripts/maze/capture_run.gd")
const Rules=preload("res://scripts/maze/player_combat_rules.gd")
var flow: Node
var textures: Dictionary={}
var hero: Sprite2D
var pool: Array[Sprite2D]=[]
var slime_sprites: Dictionary={}
var beams: Array=[]
var short_trails: Array=[]
var leaf_blades: Array=[]
var beam_layer: Node2D
var sweep: Sprite2D
var smoke_sprite: Sprite2D
var smoke_ground: Node2D
var smoke_radius: float=0.0
var smoke_layer: Node2D
var tide_layer: Node2D
var trail_layer: Node2D

func _exit_tree() -> void:
	if is_instance_valid(tide_layer) and tide_layer.get_parent()!=self: tide_layer.queue_free()
	if is_instance_valid(trail_layer) and trail_layer.get_parent()!=self: trail_layer.queue_free()
	if is_instance_valid(smoke_layer) and smoke_layer.get_parent()!=self:
		smoke_layer.queue_free()

func _ready() -> void:
	process_priority=50
	for id in ["throw","light","axe","slime","light_orb","slime_orb"]:
		textures[id]=load("res://assets/combat/team_skills/"+id+".png")
	textures.hero=load("res://assets/combat/spatula_projectile_v1.png")
	for id in ["yufeng","salia","dingdang"]:
		textures[id]=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load("res://assets/ui/combat_skills/"+id+".png"))
	if ResourceLoader.exists("res://assets/ui/combat_skills/jiaopopo.png"):
		textures.jiaopopo=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load("res://assets/ui/combat_skills/jiaopopo.png"))
	tide_layer=preload("res://scripts/maze/xiluomei_visual.gd").new()
	add_child(tide_layer)
	trail_layer=preload("res://scripts/maze/ahong_visual.gd").new()
	add_child(trail_layer)
	smoke_layer=Node2D.new()
	add_child(smoke_layer)
	smoke_sprite=Sprite2D.new()
	smoke_sprite.modulate.a=0.75
	smoke_sprite.visible=false
	if ResourceLoader.exists("res://assets/combat/jiaopopo/smoke.png"):
		smoke_sprite.texture=load("res://assets/combat/jiaopopo/smoke.png")
		smoke_sprite.hframes=4
		smoke_sprite.vframes=2
	smoke_layer.add_child(smoke_sprite)
	smoke_ground=Node2D.new()
	smoke_layer.add_child(smoke_ground)
	smoke_layer.move_child(smoke_ground,0)
	smoke_ground.draw.connect(func():
		if smoke_radius>0:
			smoke_ground.draw_circle(Vector2.ZERO,smoke_radius,Color(0.9,0.35,0.1,0.10))
			smoke_ground.draw_arc(Vector2.ZERO,smoke_radius,0,TAU,80,Color(0.85,0.35,0.1,0.4),1.2,true))
	textures.light_orb=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load("res://assets/ui/combat_skills/yaya.png"))
	if get_parent().region_id in Rules.REGIONS:
		textures.fenshui_yaya=load("res://assets/combat/team_skills/fenshui_yaya_point.png")
		textures.fenshui_tieshan=load("res://assets/combat/team_skills/fenshui_tieshan_sweep.png")
	beam_layer=Node2D.new()
	beam_layer.z_index=3
	add_child(beam_layer)
	beam_layer.draw.connect(_draw_beams)
	hero=Sprite2D.new()
	hero.centered=false
	hero.offset=Vector2(-256,-440)
	hero.z_index=2
	add_child(hero)
	sweep=Sprite2D.new()
	sweep.centered=false
	sweep.offset=Vector2(-0.15,-0.55)*1254.0
	sweep.texture=textures.get("fenshui_tieshan")
	sweep.z_index=3
	sweep.hide()
	add_child(sweep)

func frame(id: String, index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas=textures[id]
	texture.region=Rect2((index%4)*512,(index/4)*512,512,512)
	return texture

func _process(_delta: float) -> void:
	if not is_instance_valid(flow) or not is_instance_valid(flow.maze): return
	if smoke_layer.get_parent()==self:
		# 背景是迷宫第一个节点；烟层位于背景之后、所有实体及血条之前。
		smoke_layer.reparent(flow.maze)
		flow.maze.move_child(smoke_layer,1)
	var run: Dictionary = flow.display_run()
	sweep.hide()
	if not run.has("combat"): return
	var c: Dictionary=run.combat
	var fenshui: bool=run.get("active",false) and (Rules.enabled(c) or (c.get("region","")=="fenshui" and not c.get("fs01_trial",false)))
	var enhanced: bool=fenshui and flow.sparring()==null
	if trail_layer.get_parent()==self:
		trail_layer.reparent(flow.maze)
		flow.maze.move_child(trail_layer,2)
	trail_layer.sync(c)
	if tide_layer.get_parent()==self:
		tide_layer.reparent(flow.maze)
		flow.maze.move_child(tide_layer,3)
	tide_layer.sync(c)
	var smoke: Dictionary=c.get("jiaopopo_smoke",{})
	smoke_sprite.visible=not smoke.is_empty() and smoke_sprite.texture!=null
	smoke_radius=0.0
	if smoke_sprite.visible:
		var radius: float=Run.Combat.Skills.Smoke.rules(int(smoke.rank)).radius
		smoke_radius=radius
		smoke_sprite.position=Run.Combat.vec(smoke.position)
		smoke_ground.position=smoke_sprite.position
		smoke_sprite.frame=int(float(smoke.elapsed)*8.0)%8
		smoke_sprite.scale=Vector2.ONE*(radius*2.0/240.0)
	smoke_ground.queue_redraw()
	var player: Node2D=flow.maze.player
	var action: String=c.get("action","")
	var remaining: float=c.get("action_left",0.0)
	hero.visible=remaining>0
	player.body.visible=not hero.visible
	if hero.visible:
		var id: String={"hero":"throw","yaya":"light","tieshan":"axe","yufeng":"throw","salia":"light"}.get(action,"throw")
		var total := Run.Combat.Skills.action_duration(action)
		var aim: Vector2=Run.Combat.vec(c.get("aim",[1.0,0.0]))
		var index := clampi(int((1.0-remaining/total)*8),0,7)
		hero.texture=frame(id,index)
		hero.flip_h=aim.x<0
		hero.position=player.position
		var zoom: float=player.get_viewport().get_camera_2d().zoom.y
		hero.scale=Vector2.ONE*(130.0/330.0)*0.85/zoom
		hero.material=player.body.material
		if fenshui and action=="tieshan" and index in [2,3]:
			# 保留已认可预览相对原512格动作的叠加位置、转轴和比例。
			var action_scale:=preload("res://scripts/maze/combat_tuning.gd").effect(action,"action_scale",100.0)/100.0
			var phase:=clampf((0.48*action_scale-remaining-0.12*action_scale)/(0.12*action_scale),0.0,1.0)
			var side: float=-1.0 if hero.flip_h else 1.0
			sweep.position=hero.position+Vector2(40.32*side,-171.84)*hero.scale
			sweep.scale=hero.scale*Vector2(side,1.0)*(512.0/1254.0)*(145.0/200.0)
			sweep.rotation=deg_to_rad(-35.0+70.0*phase)*side
			sweep.modulate.a=sin(phase*PI)*0.85
			sweep.show()
	var draws: Array=[]
	beams.clear()
	short_trails.clear()
	leaf_blades.clear()
	var camera_zoom: float=player.get_viewport().get_camera_2d().zoom.y
	for key in c.actors:
		var actor: Dictionary=c.actors[key]
		if float(actor.get("lock_mark",{}).get("left",0.0))>0 and Run.Catalog.targetable(c,str(key)):
			draws.append({"texture":textures.dingdang,"position":Run.Combat.vec(actor.position)+Vector2(0,-65),"size":18.0/camera_zoom,"angle":0.0})
	for shot in c.shots:
		var kind: String=shot.get("kind","hero")
		var progress: float=shot.time/float(shot.get("flight",Run.Combat.FLIGHT))
		var point := Run.Combat.vec(shot.position)+Vector2(0,-30)
		if kind in ["hero","jiaopopo"]: point.y-=28*sin(progress*PI)
		var direction := Run.Combat.vec(shot.origin).direction_to(Run.Combat.vec(shot.target))
		var watercolor: bool=kind=="yaya" and fenshui
		if kind=="yaya" and enhanced:
			leaf_blades.append({"point":point,"angle":direction.angle()+float(shot.time)*TAU*2.5,"zoom":camera_zoom})
			continue
		if kind=="hero" and enhanced:
			# 从当前原弹道推回历史进度；不保留跨弹体缓存，暂停与消失自然同步。
			for trail in [[0.07,0.12],[0.035,0.20]]:
				var past:=maxf(0.0,progress-float(trail[0]))
				var previous:=point-(Run.Combat.vec(shot.target)-Run.Combat.vec(shot.origin))*(progress-past)
				previous.y+=28.0*(sin(progress*PI)-sin(past*PI))
				draws.append({"texture":textures.hero,"position":previous,"size":40.0,"angle":past*TAU,"alpha":trail[1]})
			for edge in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				draws.append({"texture":textures.hero,"position":point+edge/camera_zoom,"size":40.0,"angle":progress*TAU,"color":Color("314c39"),"alpha":0.35})
		if kind=="yaya" and not watercolor:
			beams.append({"head":point,"direction":direction,"length":minf(140.0/camera_zoom,Run.Combat.vec(shot.origin).distance_to(Run.Combat.vec(shot.position))),"zoom":camera_zoom})
		if watercolor and enhanced:
			short_trails.append({"head":point,"direction":direction,"length":minf(42.0/camera_zoom,Run.Combat.vec(shot.origin).distance_to(Run.Combat.vec(shot.position))),"zoom":camera_zoom})
		# 光核而非透明画布中心跟随原弹道；只替换正式分水庭的显示。
		draws.append({"texture":textures.fenshui_yaya if watercolor else textures.get(kind,textures.light_orb),"position":point,"size":(60.0 if enhanced else 32.0)/camera_zoom if watercolor else ((40.0 if enhanced else 28.0) if kind=="hero" else 24.0/camera_zoom),"angle":direction.angle() if watercolor else (progress*TAU if kind=="hero" else direction.angle()+PI/4),"offset":Vector2(-373,-23) if watercolor else Vector2.ZERO,"alpha":0.9+0.1*sin(float(shot.time)*TAU*2.0) if watercolor else 1.0})
	beam_layer.queue_redraw()
	for chain in c.get("lightning_chains",[]):
		beams.append({"lightning":true,"from":Run.Combat.vec(chain.from)+Vector2(0,-30),"to":Run.Combat.vec(chain.to)+Vector2(0,-30)})
	for shot in c.get("enemy_shots",[]):
		if flow.sparring()!=null: continue
		draws.append({"texture":textures.slime_orb,"position":Run.Combat.vec(shot.position)+Vector2(0,-30),"size":20,"angle":Run.Combat.vec(shot.direction).angle()})
	while pool.size()<draws.size():
		var sprite := Sprite2D.new()
		sprite.z_index=3
		add_child(sprite)
		pool.append(sprite)
	for i in pool.size():
		pool[i].visible=i<draws.size()
		if i>=draws.size(): continue
		var row: Dictionary=draws[i]
		pool[i].texture=row.texture
		pool[i].position=row.position
		pool[i].rotation=row.angle
		pool[i].scale=Vector2.ONE*float(row.size)/maxf(row.texture.get_width(),row.texture.get_height())
		pool[i].offset=row.get("offset",Vector2.ZERO)
		pool[i].modulate=row.get("color",Color.WHITE)
		pool[i].modulate.a=float(row.get("alpha",1.0))
	for key in flow.monsters:
		if not str(key).begins_with("slime_"): continue
		var monster: Node2D=flow.monsters[key]
		var a: Dictionary=c.actors[key]
		var cast: float=a.get("cast",0.0)
		var spit: float=a.get("spit_left",0.0)
		var active: bool=(cast>0 or spit>0) and run.monsters[key].status=="alive" and a.hp>0
		if not slime_sprites.has(key):
			var sprite := Sprite2D.new()
			sprite.centered=false
			sprite.offset=Vector2(-256,-440)
			add_child(sprite)
			slime_sprites[key]=sprite
		var sprite: Sprite2D=slime_sprites[key]
		sprite.visible=active
		monster.body.visible=not active
		if active:
			var index := clampi(int((0.65-cast)/0.65*3),0,2) if cast>0 else clampi(3+int((0.28-spit)/0.28*5),3,7)
			sprite.texture=frame("slime",index)
			sprite.scale=Vector2.ONE*0.12
			sprite.position=monster.position
			sprite.flip_h=Run.Combat.vec(a.get("cast_aim",[1.0,0.0])).x<0
			sprite.material=monster.body.material

func _draw_beams() -> void:
	for leaf in leaf_blades:
		beam_layer.draw_set_transform(leaf.point,leaf.angle,Vector2.ONE/float(leaf.zoom))
		var edge:=PackedVector2Array([Vector2(-17,0),Vector2(-12,-5),Vector2(-6,-8),Vector2(2,-7),Vector2(10,-3),Vector2(20,0),Vector2(11,3),Vector2(5,6),Vector2(-3,8),Vector2(-10,5),Vector2(-17,0)])
		beam_layer.draw_arc(Vector2.ZERO,17.0,0.3,1.9,18,Color(0.76,0.85,0.57,0.3),1.2,true)
		beam_layer.draw_colored_polygon(edge,Color("789b52"))
		beam_layer.draw_colored_polygon(PackedVector2Array([Vector2(-16,0),Vector2(-12,-5),Vector2(-6,-8),Vector2(2,-7),Vector2(10,-3),Vector2(20,0),Vector2(2,-1)]),Color("b3cd7c"))
		beam_layer.draw_polyline(edge,Color("426546"),1.1,true)
		beam_layer.draw_line(Vector2(-14,0),Vector2(17,0),Color("e0e8b0"),1.0,true)
		for x in [-7.0,0.0,7.0]:
			beam_layer.draw_line(Vector2(x,0),Vector2(x-4,-4),Color("6d914e"),0.8,true)
			beam_layer.draw_line(Vector2(x,0),Vector2(x-4,4),Color("b4cb80"),0.8,true)
	beam_layer.draw_set_transform(Vector2.ZERO)
	# 束线仅由仍存活的投射物派生，无独立碰撞或伤害；暂停时原位冻结。
	for trail in short_trails:
		for i in 8:
			var u:=float(i)/8.0
			var p: Vector2=trail.head-trail.direction*trail.length*(1.0-u)
			var q: Vector2=p+trail.direction*trail.length/8.0
			beam_layer.draw_line(p,q,Color(62.0/255.0,104.0/255.0,59.0/255.0,0.08+u*0.28),(2.0+u*4.0)/trail.zoom,true)
	for beam in beams:
		if beam.get("lightning",false):
			beam_layer.draw_line(beam.from,beam.to,Color(0.65,0.45,1.0),5,true)
			beam_layer.draw_line(beam.from,beam.to,Color(1,0.95,0.65),2,true)
			continue
		for i in 28:
			var u := float(i)/28.0
			var p: Vector2=beam.head-beam.direction*beam.length*(1-u)
			var q: Vector2=p+beam.direction*beam.length/28.0
			beam_layer.draw_line(p,q,Color(0.5,0.85,0.16,u*0.4),maxf(0.1,9*u/beam.zoom),true)
			beam_layer.draw_line(p,q,Color(0.72,1,0.30,u),maxf(0.1,5*u/beam.zoom),true)
			beam_layer.draw_line(p,q,Color(1,1,0.72,u),maxf(0.1,2.2*u/beam.zoom),true)
