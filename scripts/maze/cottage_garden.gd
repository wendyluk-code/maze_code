extends Node2D
## 室外园圃装饰：根部不动、错峰轻摇，进入附近只回应一次；不写经营或探索状态。
signal plant_reacted(index: int)
const WIND = preload("res://scripts/maze/cottage_plant.gdshader")
const TOMATO = preload("res://assets/props/cottage_garden/tomato.png")
const TURNIP = preload("res://assets/props/cottage_garden/turnip.png")
const ROWS := [
	{"kind":"tomato","point":Vector2(321,350),"size":0.44},
	{"kind":"tomato","point":Vector2(360,350),"size":0.50},
	{"kind":"tomato","point":Vector2(401,335),"size":0.53},
	{"kind":"tomato","point":Vector2(440,326),"size":0.46},
	{"kind":"turnip","point":Vector2(416,422),"size":0.46},
	{"kind":"turnip","point":Vector2(452,425),"size":0.49},
	{"kind":"turnip","point":Vector2(487,411),"size":0.51},
	{"kind":"turnip","point":Vector2(522,398),"size":0.49},
	{"kind":"turnip","point":Vector2(553,388),"size":0.43}
]
var plants: Array[Node2D]=[]
var player: Node2D
var _materials: Array[ShaderMaterial]=[]
var _near: Array[bool]=[]
var _reaction_time: Array[float]=[]
var _elapsed:=0.0

func _ready() -> void:
	for i in ROWS.size():
		var row: Dictionary=ROWS[i]
		var root:=Node2D.new()
		root.name="Plant%d"%i
		root.position=row.point
		add_child(root)
		var sprite:=Sprite2D.new()
		sprite.texture=TOMATO if row.kind=="tomato" else TURNIP
		sprite.centered=false
		sprite.position=Vector2(-80,-136)*row.size
		sprite.scale=Vector2.ONE*row.size
		sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.self_modulate=Color(0.95,0.98,0.94,1)
		var material:=ShaderMaterial.new()
		material.shader=WIND
		material.set_shader_parameter("phase",float(i)*1.83)
		material.set_shader_parameter("period",4.8+float(i%4)*0.37)
		sprite.material=material
		root.add_child(sprite)
		plants.append(root)
		_materials.append(material)
		_near.append(false)
		_reaction_time.append(10.0)
	advance_motion(0,Vector2(1400,200),false)
	queue_redraw()

func _draw() -> void:
	# 接地阴影固定在根部，不随叶片摇动或呼吸缩放。
	for row in ROWS:
		draw_set_transform(row.point+Vector2(0,-2),0,Vector2(1,0.30))
		draw_circle(Vector2.ZERO,12,Color(0.23,0.18,0.09,0.05))
		draw_circle(Vector2.ZERO,8,Color(0.23,0.18,0.09,0.11))
	draw_set_transform(Vector2.ZERO)

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	advance_motion(delta,player.position,not player.input_locked)

func advance_motion(delta: float, hero: Vector2, reactions_allowed: bool) -> void:
	_elapsed+=maxf(0,delta)
	for i in plants.size():
		var distance:=hero.distance_to(plants[i].position)
		if reactions_allowed:
			if not _near[i] and distance<65:
				_near[i]=true
				_reaction_time[i]=0
				plant_reacted.emit(i)
			elif _near[i] and distance>85: _near[i]=false
		_reaction_time[i]+=maxf(0,delta)
		var phase:=float(i)*1.83
		var wave:=sin(_elapsed*TAU/(4.8+float(i%4)*0.37)+phase)
		var quiet:=0.65+0.35*sin(_elapsed*0.43+phase)
		var flutter:=sin(_reaction_time[i]*15.0)*exp(-_reaction_time[i]*4.2)
		plants[i].rotation=wave*quiet*0.025+flutter*0.045
		var breath: float=sin(_elapsed*1.2+phase)*0.008+flutter*0.025
		plants[i].scale=Vector2(1.0+breath,1.0-breath*0.35)
		plants[i].z_index=1 if plants[i].position.y>hero.y else 0
		_materials[i].set_shader_parameter("garden_time",_elapsed)
		_materials[i].set_shader_parameter("flutter",flutter)
