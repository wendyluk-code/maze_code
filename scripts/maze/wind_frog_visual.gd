extends Node2D
## 水团显示只读已提交的模拟状态，不结算伤害。
const Run = preload("res://scripts/maze/capture_run.gd")
var flow: Node
var pool: Array[Sprite2D]=[]
var texture: Texture2D
func _ready() -> void:
	texture=load("res://assets/monsters/wind_frog/water.png")
func _process(_dt: float) -> void:
	if not is_instance_valid(flow): return
	var run: Dictionary=flow.display_run()
	var shots: Array=run.get("combat",{}).get("actors",{}).get(Run.Catalog.Frog.ID,{}).get("frog_shots",[])
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
		pool[i].position=Run.Combat.vec(shots[i].position)+Vector2(0,-16)
		pool[i].rotation=Run.Combat.vec(shots[i].direction).angle()+PI
