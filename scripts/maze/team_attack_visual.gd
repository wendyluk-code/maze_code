extends Node2D
## 只读成功事务的状态；人物动作、飞行弹、碰撞特效分别绘制。
const Run = preload("res://scripts/maze/capture_run.gd")
var flow: Node
var textures: Dictionary={}
var hero: Sprite2D
var pool: Array[Sprite2D]=[]
var slime_sprites: Dictionary={}
var beams: Array=[]
var beam_layer: Node2D

func _ready() -> void:
	process_priority=50
	for id in ["throw","light","axe","slime","light_orb","slime_orb"]:
		textures[id]=load("res://assets/combat/team_skills/"+id+".png")
	textures.hero=load("res://assets/combat/spatula_projectile_v1.png")
	textures.light_orb=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load("res://assets/ui/combat_skills/yaya.png"))
	beam_layer=Node2D.new()
	beam_layer.z_index=3
	add_child(beam_layer)
	beam_layer.draw.connect(_draw_beams)
	hero=Sprite2D.new()
	hero.centered=false
	hero.offset=Vector2(-256,-440)
	hero.z_index=2
	add_child(hero)

func frame(id: String, index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas=textures[id]
	texture.region=Rect2((index%4)*512,(index/4)*512,512,512)
	return texture

func _process(_delta: float) -> void:
	if not is_instance_valid(flow) or not is_instance_valid(flow.maze): return
	var run: Dictionary = flow.display_run()
	if not run.has("combat"): return
	var c: Dictionary=run.combat
	var player: Node2D=flow.maze.player
	var action: String=c.get("action","")
	var remaining: float=c.get("action_left",0.0)
	hero.visible=remaining>0
	player.body.visible=not hero.visible
	if hero.visible:
		var id: String={"hero":"throw","yaya":"light","tieshan":"axe"}.get(action,"throw")
		var total := 0.48 if action=="tieshan" else 0.30
		var aim: Vector2=Run.Combat.vec(c.get("aim",[1.0,0.0]))
		var index := clampi(int((1.0-remaining/total)*8),0,7)
		hero.texture=frame(id,index)
		hero.flip_h=aim.x<0
		hero.position=player.position
		var zoom: float=player.get_viewport().get_camera_2d().zoom.y
		hero.scale=Vector2.ONE*(130.0/330.0)*0.85/zoom
		hero.material=player.body.material
	var draws: Array=[]
	beams.clear()
	var camera_zoom: float=player.get_viewport().get_camera_2d().zoom.y
	for shot in c.shots:
		var kind: String=shot.get("kind","hero")
		var progress: float=shot.time/float(shot.get("flight",Run.Combat.FLIGHT))
		var point := Run.Combat.vec(shot.position)+Vector2(0,-30)
		if kind=="hero": point.y-=28*sin(progress*PI)
		var direction := Run.Combat.vec(shot.origin).direction_to(Run.Combat.vec(shot.target))
		if kind=="yaya":
			beams.append({"head":point,"direction":direction,"length":minf(140.0/camera_zoom,Run.Combat.vec(shot.origin).distance_to(Run.Combat.vec(shot.position))),"zoom":camera_zoom})
		draws.append({"texture":textures.hero if kind=="hero" else textures.light_orb,"position":point,"size":28 if kind=="hero" else 24.0/camera_zoom,"angle":progress*TAU if kind=="hero" else direction.angle()+PI/4})
	beam_layer.queue_redraw()
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
	# 束线仅由仍存活的投射物派生，无独立碰撞或伤害；暂停时原位冻结。
	for beam in beams:
		for i in 28:
			var u := float(i)/28.0
			var p: Vector2=beam.head-beam.direction*beam.length*(1-u)
			var q: Vector2=p+beam.direction*beam.length/28.0
			beam_layer.draw_line(p,q,Color(0.5,0.85,0.16,u*0.4),maxf(0.1,9*u/beam.zoom),true)
			beam_layer.draw_line(p,q,Color(0.72,1,0.30,u),maxf(0.1,5*u/beam.zoom),true)
			beam_layer.draw_line(p,q,Color(1,1,0.72,u),maxf(0.1,2.2*u/beam.zoom),true)
