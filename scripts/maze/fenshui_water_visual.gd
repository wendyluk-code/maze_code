extends Node2D
## 仅显示：正式共享地形裁切，人物脚底/战斗位置不变。
const FS=preload("res://data/maze/fenshui_roads.gd")
const BodyShader=preload("res://scripts/maze/fenshui_water_body.gdshader")
var enabled:=true
var clock:=0.0
var depth:=0.0
var reflection: Sprite2D
var body_material: ShaderMaterial
var surface_material: ShaderMaterial
var mask: Image
var mask_texture: Texture2D
var maze: Node2D
var player: Node2D
var ripples: Array=[]
var last_point:=Vector2.ZERO
var step_clock:=0.0
var prior_material: Material
var display_active:=false

func _ready() -> void:
 process_priority=150
 z_index=1
 maze=get_parent()
 player=maze.player
 last_point=player.position
 mask_texture=load("res://assets/maps/fenshui_v4/water-mask.png")
 if mask_texture==null:
  set_process(false)
  return
 mask=mask_texture.get_image()
 surface_material=ShaderMaterial.new()
 surface_material.shader=preload("res://scripts/maze/fenshui_water_background.gdshader")
 surface_material.set_shader_parameter("water_mask",mask_texture)
 maze.get_child(0).material=surface_material
 body_material=ShaderMaterial.new()
 body_material.shader=BodyShader
 body_material.set_shader_parameter("water_mask",mask_texture)
 prior_material=player.body.material
 reflection=Sprite2D.new()
 reflection.name="FenshuiPlayerReflection"
 reflection.centered=false
 var material:=ShaderMaterial.new()
 material.shader=BodyShader
 material.set_shader_parameter("reflection_mode",true)
 material.set_shader_parameter("water_mask",mask_texture)
 reflection.material=material
 maze.add_child.call_deferred(reflection)
 _place_reflection.call_deferred()
 if is_instance_valid(player.water_ripples):
  player.water_ripples.hide()
  player.water_ripples.set_process(false)

func _place_reflection() -> void:
 if is_instance_valid(reflection) and reflection.get_parent()==maze:
  maze.move_child(reflection,1)

func wet_at(point: Vector2) -> float:
 if not point.is_finite() or point.x<0 or point.y<0 or point.x>=FS.SIZE.x or point.y>=FS.SIZE.y: return 0.0
 var pixel:=Vector2i(point*Vector2(mask.get_size())/FS.SIZE)
 return mask.get_pixelv(pixel).r

func _process(dt: float) -> void:
 if not is_instance_valid(player) or not is_instance_valid(maze.capture_flow): return
 var flow: Node=maze.capture_flow
 var current: Vector2=player.position
 var moved:=current.distance_to(last_point)
 last_point=current
 var run: Dictionary=flow.display_run()
 var valid: bool=run.get("active",false) and run.combat.get("region","")=="fenshui" and not run.combat.get("fs01_trial",false)
 var visible_effect: bool=enabled and valid and run.combat.hp>0 and player.is_visible_in_tree()
 display_active=visible_effect
 if moved>60.0: ripples.clear()
 if visible_effect and not flow.combat_paused():
  clock+=dt
  var raw:=0.0
  for y in [-8.0,-4.0,0.0,4.0,8.0]:
   for x in [-8.0,-4.0,0.0,4.0,8.0]: raw+=wet_at(current+Vector2(x,y))/25.0
  depth=lerpf(depth,raw,1.0-exp(-dt*6.0))
  for ripple in ripples: ripple.age+=dt
  ripples=ripples.filter(func(ripple: Dictionary): return ripple.age<1.5)
  if player._walking and moved>0.01 and wet_at(current)>0.5:
   step_clock+=dt
   if step_clock>=0.22:
    ripples.append({"point":current,"age":0.0})
    if ripples.size()>12: ripples.pop_front()
    step_clock=0.0
  else: step_clock=0.0
 elif not visible_effect:
  ripples.clear()
 var zoom: float=maze.camera.zoom.y
 var immersion: float=depth if visible_effect else 0.0
 var sink: float=immersion*23.0/zoom
 surface_material.set_shader_parameter("clock",clock)
 surface_material.set_shader_parameter("enabled",enabled and valid)
 body_material.set_shader_parameter("immersion",immersion)
 body_material.set_shader_parameter("foot_y",current.y)
 body_material.set_shader_parameter("fade_height",25.0/zoom)
 body_material.set_shader_parameter("flash",false)
 player.body.position=Vector2(0,sink)
 player.body.material=body_material if visible_effect else prior_material
 var hurt: Node=flow.player_hurt_visual
 if is_instance_valid(hurt):
  hurt.position=Vector2(0,sink)
  hurt.pose.material=body_material if visible_effect else null
 var cast: Sprite2D=flow.skill_visual.hero
 if cast.visible:
  cast.position=current+Vector2(0,sink)
  cast.material=body_material if visible_effect else prior_material
  if flow.skill_visual.sweep.visible: flow.skill_visual.sweep.position.y+=sink
 player._appearance.ground_shadow.modulate.a=1.0-immersion
 if is_instance_valid(reflection):
  reflection.visible=visible_effect and depth>0.1
  var source: Sprite2D=player.body
  if is_instance_valid(hurt) and hurt.pose.visible: source=hurt.pose
  elif cast.visible: source=cast
  reflection.texture=source.texture
  reflection.centered=source.centered
  reflection.offset=source.offset
  reflection.flip_h=source.flip_h
  reflection.scale=source.scale*Vector2(1,-0.32)
  reflection.position=current+Vector2(0,2)
  reflection.modulate=Color(0.7,0.9,0.95,immersion*0.13)
 queue_redraw()

func _draw() -> void:
 if not enabled or not display_active or depth<=0.01: return
 var zoom: float=maze.camera.zoom.y
 for ripple in ripples:
  var progress: float=ripple.age/1.5
  var segment:=PackedVector2Array()
  for i in 65:
   var angle:=TAU*i/64.0
   var point: Vector2=ripple.point+Vector2(cos(angle)*(10+progress*52),sin(angle)*(3+progress*18))/zoom
   if wet_at(point)>0.5: segment.append(point)
   else:
    if segment.size()>1: draw_polyline(segment,Color(0.91,1,0.97,(1-progress)*0.65),1.4/zoom,true)
    segment=PackedVector2Array()
  if segment.size()>1: draw_polyline(segment,Color(0.91,1,0.97,(1-progress)*0.65),1.4/zoom,true)
 if depth>0.15:
  var arc:=PackedVector2Array()
  for i in 25:
   var angle:=PI*i/24.0
   var point: Vector2=player.position+Vector2(cos(angle)*(19+depth*4),sin(angle)*4)/zoom
   if wet_at(point)>0.5: arc.append(point)
  if arc.size()>1: draw_polyline(arc,Color(0.88,1,0.97,depth*0.65),1.6/zoom,true)

func _exit_tree() -> void:
 if is_instance_valid(reflection): reflection.queue_free()
