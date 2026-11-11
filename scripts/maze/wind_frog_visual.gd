extends Node2D
## 水团显示只读已提交的模拟状态，不结算伤害。
const Run = preload("res://scripts/maze/capture_run.gd")
var flow: Node
var pool: Array[Sprite2D]=[]
var texture: Texture2D
var waterjet: Texture2D
var mouth_offsets: Array[Vector2]=[]
func _ready() -> void:
	texture=load("res://assets/monsters/wind_frog/water.png")
	waterjet=load("res://assets/monsters/wind_frog/waterjet_v2.png")
	var image: Image=load("res://assets/monsters/wind_frog/attack.png").get_image()
	for direction in 4:
		var bottom:=-1
		for y in 192:
			for x in 192:
				if image.get_pixel(384+x,direction*192+y).a>=0.5: bottom=maxi(bottom,y)
		var mouth: Vector2=[Vector2(132,83),Vector2(55,83),Vector2(129,55),Vector2(63,55)][direction]
		mouth_offsets.append((mouth-Vector2(96,bottom+1))*float(Run.Catalog.Frog.TYPE.width)/192.0)
func _process(_dt: float) -> void:
	if not is_instance_valid(flow): return
	var run: Dictionary=flow.display_run()
	var shots: Array=run.get("combat",{}).get("actors",{}).get(Run.Catalog.Frog.ID,{}).get("frog_shots",[])
	var enhanced: bool=run.get("active",false) and run.get("combat",{}).get("region","")=="fenshui" and not run.combat.get("fs01_trial",false) and flow.sparring()==null
	while pool.size()<shots.size():
		var s := Sprite2D.new()
		s.texture=texture
		s.scale=Vector2.ONE*26.0/texture.get_width()
		s.z_index=3
		add_child(s)
		pool.append(s)
	for i in pool.size():
		pool[i].visible=i<shots.size() and flow.sparring()==null
		if i>=shots.size(): continue
		var offset:=Vector2(0,-16)
		if not run.combat.get("fs01_trial",false):
			var direction: int=preload("res://scripts/maze/wind_frog_counter.gd").direction_for(Run.Combat.vec(shots[i].direction))
			offset=mouth_offsets[direction]
			var frog: Node=flow.monsters.get(Run.Catalog.Frog.ID)
			if is_instance_valid(frog) and frog.frog_front24!=null: offset=frog.frog_front24.mouth_offset(direction)
		pool[i].position=Run.Combat.vec(shots[i].position)+offset
		if enhanced:
			var factor:=80.0/1694.0
			# 前端跟随真实弹体；出生时从嘴部揭出尾迹，不把长尾画到蛙身后。
			var cut:=clampf(1645.02-float(shots[i].get("distance",0.0))/factor,0.0,1645.02)
			pool[i].texture=waterjet
			pool[i].centered=false
			pool[i].region_enabled=true
			pool[i].region_rect=Rect2(cut,0.0,float(waterjet.get_width())-cut,float(waterjet.get_height()))
			pool[i].offset=Vector2(cut-1645.02,-356.0)
			pool[i].scale=Vector2.ONE*factor
			pool[i].rotation=Run.Combat.vec(shots[i].direction).angle()
		else:
			pool[i].texture=texture
			pool[i].centered=true
			pool[i].region_enabled=false
			pool[i].offset=Vector2.ZERO
			pool[i].scale=Vector2.ONE*26.0/texture.get_width()
			pool[i].rotation=Run.Combat.vec(shots[i].direction).angle()+PI
