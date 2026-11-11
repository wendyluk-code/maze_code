extends Node2D
## 复用既有雷元素图和萨莉亚紫金配色，只读已提交的雷印状态。
const Trail=preload("res://scripts/maze/ahong_trail.gd")
var state: Dictionary={}
var controlled: Array[Vector2]=[]
var texture: Texture2D
var water_masks: Dictionary={}

func _ready() -> void:
	texture=load("res://assets/ui/factions/lightning.png")

func sync(c: Dictionary) -> void:
	state=c.get("ahong_trail",{})
	controlled.clear()
	for actor in c.get("actors",{}).values():
		if Trail.paralyzed(actor): controlled.append(Vector2(actor.position[0],actor.position[1]))
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	var config:=Trail.rules(int(state.rank))
	var shown: Dictionary={}
	for mark in state.marks:
		var p:=Vector2(mark.position[0],mark.position[1])
		var alpha:=minf(1.0,float(mark.left)/0.25)
		var radius:=float(config.radius)
		if int(mark.water)>0:
			var id:=int(mark.water)
			if not shown.has(id):
				shown[id]=true
				_draw_water(id,alpha)
		else:
			draw_circle(p,radius,Color(0.60,0.40,1.0,0.16*alpha))
			draw_arc(p,radius,0,TAU,48,Color(0.80,0.62,1.0,0.7*alpha),1.3,true)
		if texture: draw_texture_rect(texture,Rect2(p-Vector2(11,11),Vector2(22,22)),false,Color(1,1,1,alpha))
	for p in controlled:
		draw_arc(p,18,0,TAU,32,Color(1,0.90,0.40,0.9),2,true)
		if texture: draw_texture_rect(texture,Rect2(p-Vector2(8,45),Vector2(16,16)),false)

func _draw_water(id: int,alpha: float) -> void:
	Trail.Water.prepare()
	if not water_masks.has(id):
		var size:=Vector2i(ceili(Trail.Water.Roads.SIZE.x/4.0)+1,ceili(Trail.Water.Roads.SIZE.y/4.0)+1)
		var mask:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		for cell in Trail.Water.cells.get(id,[]): mask.set_pixel(cell.x,cell.y,Color.WHITE)
		water_masks[id]=ImageTexture.create_from_image(mask)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var mask: Texture2D=water_masks[id]
	draw_texture_rect(mask,Rect2(Vector2(-2,-2),mask.get_size()*4.0),false,Color(0.65,0.45,1,0.13*alpha))
