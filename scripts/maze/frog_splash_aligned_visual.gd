extends "res://scripts/maze/frog_splash_visual.gd"
## L范围候选：原水花像素不改，地面范围及前后水花共用实际伤害水域。
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
var ground: Node2D
var masks: Array[Polygon2D]=[]
var area_shape:=PackedVector2Array()
var area_center:=Vector2.ZERO
var area_phase:=""
var area_alpha:=0.0

func _ready() -> void:
 super._ready()
 for sprite in [back,front]:
  var mask:=Polygon2D.new()
  mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY
  add_child(mask)
  sprite.reparent(mask)
  masks.append(mask)
 ground=Node2D.new()
 ground.name="FrogSlamWaterAreaCandidate"
 ground.draw.connect(_draw_area)
 flow.maze.add_child(ground)
 flow.maze.move_child(ground,1)
 get_parent().set_meta("slam_area_preview",true)

func _exit_tree() -> void:
 if is_instance_valid(ground): ground.queue_free()
 if is_instance_valid(get_parent()): get_parent().remove_meta("slam_area_preview")

func clear() -> void:
 super.clear()
 area_shape=PackedVector2Array()
 area_phase=""
 area_alpha=0.0
 if is_instance_valid(ground): ground.queue_redraw()

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
 ground.draw_colored_polygon(area_shape,Color(0.74,0.96,1.0,area_alpha*0.20))
 var outline:=area_shape.duplicate()
 outline.append(outline[0])
 ground.draw_polyline(outline,Color(0.74,0.96,1.0,area_alpha),1.4,true)

func _render() -> void:
 super._render()
 if masks.is_empty(): return
 var shape:=PackedVector2Array()
 if kind=="landing" and frame>=0:
  for point in Area.polygon(anchor,Boss.ID+"_slam"): shape.append(point-anchor)
 for mask in masks:
  mask.polygon=shape
  mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY if not shape.is_empty() else CanvasItem.CLIP_CHILDREN_DISABLED

func area_snapshot() -> Dictionary:
 return {"visible":is_instance_valid(ground) and ground.is_visible_in_tree() and area_alpha>0.0 and area_shape.size()>2,"shape":area_shape.duplicate(),"center":area_center,"phase":area_phase,"alpha":area_alpha}
