extends Node2D
## 已认可接触反馈；只显示成功事务，不持有伤害或动作时钟。
const SHADER=preload("res://scripts/maze/fenshui_hit_feedback.gdshader")
const DURATION={"hero":0.2,"yaya":0.23,"tieshan":0.28}
const CORES={"hero":Vector2(0.57,0.59),"yaya":Vector2(0.60,0.57),"tieshan":Vector2(0.56,0.71)}
# 三格整体世界宽度独立于目标体型；亮核而非透明画布中心对齐实际接触点。
const WIDTHS={"hero":42.0,"yaya":42.0,"tieshan":54.0}
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
func effect_duration(kind: String) -> float:
 return Tuning.effect(kind,"fx_duration",DURATION[kind]*1000.0)/1000.0
var body: Sprite2D
var watercolor_sheet: Texture2D
var watercolor_frames: Dictionary={}
var effects: Array=[]
var reaction_kind:=""
var reaction_age:=0.0
var ratio:=1.0
var received:=0
var follow_body_height:=false

func install(sprite: Sprite2D, width: float, follow_height: bool=false) -> void:
 body=sprite
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 ratio=1.0
 watercolor_sheet=load("res://assets/effects/fenshui/player_hit/watercolor_sheet.png")
 for index in 3:
  var frame:=AtlasTexture.new()
  frame.atlas=watercolor_sheet
  frame.region=Rect2(index*724,0,724,724)
  watercolor_frames[["hero","yaya","tieshan"][index]]=frame
 follow_body_height=follow_height
 var material:=ShaderMaterial.new()
 material.shader=SHADER
 body.material=material
 z_index=3

func clear() -> void:
 effects.clear()
 reaction_kind=""
 reaction_age=0.0
 if is_instance_valid(body) and body.material!=null:
  body.material.set_shader_parameter("impact_scale",Vector2.ONE)
  body.material.set_shader_parameter("impact_angle",0.0)
 queue_redraw()

func receive(event: Dictionary) -> void:
 received+=1
 var contact:=to_local(Vector2(event.point[0],event.point[1])+Vector2(0,-30))
 var direction:=Vector2(event.direction[0],event.direction[1])
 effects.append({"kind":event.kind,"age":0.0,"point":contact,"angle":direction.angle()})
 if effects.size()>8: effects.pop_front()
 queue_redraw()
 # 有膜也保留已认可接触图形；保护只阻止身体形变，不吞掉命中反馈。
 if event.protected: return
 reaction_kind=event.kind
 reaction_age=0.0

func advance(delta: float) -> void:
 if not get_parent().is_visible_in_tree():
  clear()
  return
 for e in effects: e.age+=delta
 effects=effects.filter(func(e): return e.age<effect_duration(e.kind))
 if not reaction_kind.is_empty():
  reaction_age+=delta
  var pulse:=sin(PI*minf(1.0,reaction_age/0.15))
  var stretch:=Vector2.ONE
  var angle:=0.0
  match reaction_kind:
   "hero": stretch=Vector2(1.0-0.09*pulse,1.0+0.05*pulse)
   "yaya": stretch=Vector2(1.0-0.035*pulse,1.0+0.02*pulse)
   "tieshan":
    stretch=Vector2(1.0+0.05*pulse,1.0-0.10*pulse)
    angle=0.055*pulse
  body.material.set_shader_parameter("impact_scale",stretch)
  body.material.set_shader_parameter("impact_angle",angle)
  if reaction_age>=effect_duration(reaction_kind): reaction_kind=""
 queue_redraw()

func _draw() -> void:
 for e in effects:
  # 只借用巨蛙当前身体的垂直位移；不继承体型、挤压、旋转或纹理缩放。
  var point: Vector2=e.point+Vector2(0,body.position.y if follow_body_height and is_instance_valid(body) else 0.0)
  var age: float=e.age
  var p: float=age/effect_duration(e.kind)
  var alpha:=1.0 if p<0.3 else pow(1.0-(p-0.3)/0.7,1.2)
  var spread:=0.85+0.15*minf(1.0,p/0.2)
  alpha*=Tuning.effect(e.kind,"opacity",100.0)/100.0
  point+=Vector2(Tuning.effect(e.kind,"offset_x",0.0),Tuning.effect(e.kind,"offset_y",0.0))
  var size:=Vector2.ONE*float(WIDTHS[e.kind])*Tuning.effect(e.kind,"fx_scale",100.0)/100.0
  draw_set_transform(point,e.angle+deg_to_rad(Tuning.effect(e.kind,"angle",0.0)),Vector2.ONE*spread)
  draw_texture_rect(watercolor_frames[e.kind],Rect2(-size*CORES[e.kind],size),false,Color(1,1,1,alpha))
 draw_set_transform(Vector2.ZERO)
