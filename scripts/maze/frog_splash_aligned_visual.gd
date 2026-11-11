extends "res://scripts/maze/frog_splash_visual.gd"
## 旧起跳与新版六帧落地；主体等比，地面波纹覆盖实际伤害水域。
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
const LandingSheet=preload("res://assets/effects/fenshui/frog_splash/landing_v2.png")
var ground: Node2D
var masks: Array[Polygon2D]=[]
var area_shape:=PackedVector2Array()
var area_center:=Vector2.ZERO
var area_phase:=""
var area_alpha:=0.0
var edge_material: ShaderMaterial
var edge_shape:=PackedVector2Array()
var ripple: Sprite2D
var ripple_mask: Polygon2D
var landing_whole: Array[AtlasTexture]=[]

func _ready() -> void:
 super._ready()
 _load_landing_frames()
 for sprite in [back,front]:
  var mask:=Polygon2D.new()
  mask.z_index=sprite.z_index
  sprite.z_index=0
  mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
  add_child(mask)
  sprite.reparent(mask)
  masks.append(mask)
 edge_material=ShaderMaterial.new()
 edge_material.shader=preload("res://scripts/maze/frog_splash_edge.gdshader")
 back.material=edge_material
 front.material=edge_material
 ground=Node2D.new()
 ground.name="FrogSlamWaterAreaCandidate"
 ground.draw.connect(_draw_area)
 flow.maze.add_child(ground)
 flow.maze.move_child(ground,1)
 ripple_mask=Polygon2D.new()
 ripple_mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
 ground.add_child(ripple_mask)
 ripple=Sprite2D.new()
 ripple.centered=false
 ripple.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 ripple.material=edge_material
 ripple.hide()
 ripple_mask.add_child(ripple)
 get_parent().set_meta("slam_area_preview",true)

func _load_landing_frames() -> void:
 # 原生成图不改像素：按六个512格取图，统一落点(256,300)，不逐格裁边对齐。
 _peaks.landing=0.0
 var image: Image=LandingSheet.get_image()
 for i in 6:
  var origin:=Vector2i(i%3,i/3)*512
  var upper:=AtlasTexture.new()
  upper.atlas=LandingSheet
  upper.region=Rect2(origin,Vector2i(512,300))
  upper.filter_clip=true
  var lower:=AtlasTexture.new()
  lower.atlas=LandingSheet
  lower.region=Rect2(origin+Vector2i(0,300),Vector2i(512,212))
  lower.filter_clip=true
  frames[i+3]={"back":upper,"front":lower,"x":256.0,"split":300}
  var whole:=AtlasTexture.new()
  whole.atlas=LandingSheet
  whole.region=Rect2(origin,Vector2i(512,512))
  whole.filter_clip=true
  landing_whole.append(whole)
  var left:=512
  var right:=-1
  for y in 512:
   for x in 512:
    if image.get_pixel(origin.x+x,origin.y+y).a>=0.12:
     left=mini(left,x)
     right=maxi(right,x)
  _peaks.landing=maxf(_peaks.landing,float(right-left+1))

func _exit_tree() -> void:
 if is_instance_valid(ground): ground.queue_free()
 if is_instance_valid(get_parent()): get_parent().remove_meta("slam_area_preview")

func clear() -> void:
 super.clear()
 area_shape=PackedVector2Array()
 area_phase=""
 area_alpha=0.0
 if is_instance_valid(ground): ground.queue_redraw()
 if is_instance_valid(ripple): ripple.hide()

func _process(dt: float) -> void:
 super._process(dt)
 if not is_instance_valid(ground): return
 area_shape=PackedVector2Array()
 area_phase=""
 area_alpha=0.0
 if is_instance_valid(flow) and is_visible_in_tree() and flow.target_lock_enabled():
  var run: Dictionary=flow.display_run()
  var actor: Dictionary=run.get("combat",{}).get("actors",{}).get(Boss.ID,{})
  var phase: String=actor.get("frog_phase","")
  if not actor.is_empty() and float(actor.get("hp",0.0))>0.0 and actor.get("mode","")!="return" and phase in ["warning","airborne","landing"]:
   if phase!="landing" or (kind=="landing" and frame>=0):
    area_center=Vector2(actor.frog_target[0],actor.frog_target[1])
    area_shape=Area.polygon(area_center,Boss.ID+"_slam")
    area_phase=phase
    area_alpha=0.5 if phase!="landing" else maxf(0.0,0.65*(1.0-age/float(DURATIONS.landing)))
 ground.queue_redraw()

func _draw_area() -> void:
 if area_shape.size()<3 or area_alpha<=0.0: return
 # 落地冲击面覆盖完整伤害水域，浪柱和飞沫不承担逐像素命中边界。
 ground.draw_colored_polygon(area_shape,Color(0.74,0.96,1.0,area_alpha*(0.42 if area_phase=="landing" else 0.20)))
 var outline:=area_shape.duplicate()
 outline.append(outline[0])
 ground.draw_polyline(outline,Color(0.74,0.96,1.0,area_alpha),1.4,true)

func _render() -> void:
 super._render()
 if kind=="landing" and frame>=0:
  var radius: float=Area.radius(Boss.ID+"_slam")
  var factor: float=radius*2.0/float(_peaks.landing)
  # 主体前后层共用等比缩放，不能把低浪前沿再次拉成高墙。
  back.scale=Vector2.ONE*factor
  front.scale=back.scale
  # 保留实际覆盖，仅降低厚重浪墙的不透明度；末段淡出而非最后一格突然消失。
  var opacity: float=0.72*(1.0-smoothstep(0.43,float(DURATIONS.landing),age))
  back.modulate.a=opacity
  front.modulate.a=opacity
  if is_instance_valid(ripple):
   # 薄波纹使用第五帧的连续贴水残纹；末帧已碎开，不承担地面覆盖。
   ripple.texture=landing_whole[4]
   ripple.offset=Vector2(-256.0,-300.0)
   ripple.scale=Vector2(radius*2.0/443.0,radius/67.0)
   ripple.modulate.a=0.55*(1.0-smoothstep(0.30,float(DURATIONS.landing),age))
   ripple_mask.position=anchor
   ripple.show()
 else:
  back.modulate.a=1.0
  front.modulate.a=1.0
  if is_instance_valid(ripple): ripple.hide()
 if masks.is_empty(): return
 var shape:=PackedVector2Array()
 if kind=="landing" and frame>=0:
  for point in Area.polygon(anchor,Boss.ID+"_slam"): shape.append(point-anchor)
 for mask in masks:
  mask.polygon=shape
  mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY if not shape.is_empty() else CanvasItem.CLIP_CHILDREN_DISABLED
 if is_instance_valid(ripple_mask): ripple_mask.polygon=shape
 if edge_material!=null:
  edge_material.set_shader_parameter("edge_enabled",not shape.is_empty())
  if not shape.is_empty(): _update_edge(shape)

func _update_edge(shape: PackedVector2Array) -> void:
 var radius: float=Area.radius(Boss.ID+"_slam")
 var span: float=radius*2.0+24.0
 edge_material.set_shader_parameter("area_origin",anchor-Vector2.ONE*span*0.5)
 edge_material.set_shader_parameter("area_span",span)
 if edge_shape==shape: return
 edge_shape=shape.duplicate()
 # 仅落点或范围变化时生成小遮罩；边界内侧渐隐，不把水花扩展到伤害区外。
 var size:=64
 var mask_image:=Image.create(size,size,false,Image.FORMAT_R8)
 for y in size:
  for x in size:
   var point: Vector2=(Vector2(x,y)+Vector2.ONE*0.5)/float(size)*span-Vector2.ONE*span*0.5
   if not Geometry2D.is_point_in_polygon(point,shape): continue
   var distance:=12.0
   for i in shape.size():
    distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,shape[i],shape[(i+1)%shape.size()])))
   var alpha: float=smoothstep(0.0,12.0,distance)
   mask_image.set_pixel(x,y,Color(alpha,alpha,alpha,1.0))
 edge_material.set_shader_parameter("edge_mask",ImageTexture.create_from_image(mask_image))

func area_snapshot() -> Dictionary:
 return {"visible":is_instance_valid(ground) and ground.is_visible_in_tree() and area_alpha>0.0 and area_shape.size()>2,"shape":area_shape.duplicate(),"center":area_center,"phase":area_phase,"alpha":area_alpha}
