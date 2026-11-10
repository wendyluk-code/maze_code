extends Node2D
## 只消费真实咆哮阶段；地面预警和释放共用伤害轮廓。
const Area=preload("res://scripts/maze/rockmane_roar_area.gd")
const WAVE_SOURCE=preload("res://assets/effects/rockmane/rockmane_roar_source.png")
const TRAIL_LENGTH:=90.0
const WAVE_DURATION:=1.0
var monster: Node2D
var shape:=PackedVector2Array()
var phase:=""
var left:=0.0
var aim:=Vector2.DOWN
var clock:=0.0
var charge_duration:=1.2
var combo:=false
var finale:=false
var recover_duration:=2.0
var wave: Polygon2D
var wave_material: ShaderMaterial
var trail_points: Array[Vector2]=[]
var trail_span:=0.0
var previous_phase:=""
var previous_clock:=-1.0
var wave_started:=-100.0
var wave_age:=100.0
var wave_origin:=Vector2.ZERO
var wave_aim:=Vector2.DOWN

func _ready() -> void:
 get_parent().move_child(self,1)
 wave=Polygon2D.new()
 wave.texture=WAVE_SOURCE
 wave.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 wave.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
 wave_material=ShaderMaterial.new()
 wave_material.shader=preload("res://scripts/maze/rockmane_roar_source.gdshader")
 wave.material=wave_material
 wave.hide()
 add_child(wave)

func clear() -> void:
 shape=PackedVector2Array()
 phase=""
 left=0.0
 trail_points.clear()
 trail_span=0.0
 previous_phase=""
 wave_started=-100.0
 wave_age=100.0
 if is_instance_valid(wave): wave.hide()
 queue_redraw()

func apply(actor: Dictionary, combat: Dictionary) -> void:
 if not is_instance_valid(monster) or not monster.is_visible_in_tree() or float(actor.get("hp",0.0))<=0.0 or float(combat.get("hp",1.0))<=0.0 or actor.get("mode","")=="return":
  clear()
  return
 global_position=Vector2(actor.position[0],actor.position[1])
 phase=str(actor.get("rock_phase",""))
 left=float(actor.get("rock_left",0.0))
 clock=float(combat.get("elapsed",0.0))
 charge_duration=preload("res://scripts/maze/rockmane_combat.gd").charge_duration(actor)
 recover_duration=preload("res://scripts/maze/rockmane_combat.gd").recover_duration(actor)
 combo=bool(actor.get("rock_combo",false))
 finale=combo and int(actor.get("rock_chain_left",0))==1
 aim=Vector2(actor.rock_aim[0],actor.rock_aim[1])
 shape=PackedVector2Array()
 if phase in ["charge","rush"]:
  for point in Area.polygon(global_position,aim): shape.append(point-global_position)
 _update_wave()
 _update_trail()
 previous_phase=phase
 previous_clock=clock
 queue_redraw()

func _update_wave() -> void:
 if not is_instance_valid(wave): return
 if clock<previous_clock or phase=="charge" or (phase in ["active","stunned","lunge"] and phase!=previous_phase): wave_started=-100.0
 if phase=="rush" and previous_phase!="rush" and shape.size()>2:
  var duration: float=preload("res://scripts/maze/combat_tuning.gd").number("rock.roar","release",0.45)
  wave_started=clock-clampf(duration-left,0.0,duration)
  wave_origin=global_position
  wave_aim=aim
  wave.polygon=shape
  var uv:=PackedVector2Array()
  for point in shape: uv.append(Vector2(158,674)+point.rotated(-wave_aim.angle())*(1000.0/Area.RADIUS))
  wave.uv=uv
 wave_age=maxf(0.0,clock-wave_started)
 wave.visible=wave_age<WAVE_DURATION and wave.polygon.size()>2
 if not wave.visible: return
 wave.global_position=wave_origin
 wave_material.set_shader_parameter("release_progress",clampf(wave_age/WAVE_DURATION,0.0,1.0))

func _update_trail() -> void:
 if phase!="lunge":
  trail_points.clear()
  trail_span=0.0
  return
 if previous_phase!="lunge" or clock<previous_clock or (not trail_points.is_empty() and global_position.distance_to(trail_points[-1])>180.0):
  trail_points.clear()
 if trail_points.is_empty(): trail_points.append(global_position)
 elif global_position.distance_to(trail_points[-1])>0.01: trail_points.append(global_position)
 trail_span=0.0
 for i in range(1,trail_points.size()): trail_span+=trail_points[i-1].distance_to(trail_points[i])
 while trail_span>TRAIL_LENGTH and trail_points.size()>1:
  var segment:=trail_points[0].distance_to(trail_points[1])
  var excess:=trail_span-TRAIL_LENGTH
  if excess>=segment:
   trail_points.remove_at(0)
   trail_span-=segment
  else:
   trail_points[0]=trail_points[0].lerp(trail_points[1],excess/segment)
   trail_span=TRAIL_LENGTH

func _trail_point(back: float) -> Vector2:
 for i in range(trail_points.size()-1,0,-1):
  var length:=trail_points[i].distance_to(trail_points[i-1])
  if back<=length: return trail_points[i].lerp(trail_points[i-1],back/maxf(length,0.001))-global_position
  back-=length
 return trail_points[0]-global_position

func _dust_cloud(center: Vector2, radius: float, alpha: float, seed_value: float) -> void:
 var puff:=PackedVector2Array()
 for i in 25:
  var angle:=TAU*float(i)/24.0
  var wobble:=1.0+0.13*sin(angle*3.0+seed_value)+0.08*cos(angle*5.0-seed_value)
  puff.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*0.62)*wobble)
 draw_colored_polygon(puff,Color(0.48,0.40,0.29,alpha*0.22))
 for layer in 3:
  for i in puff.size(): puff[i]=center+(puff[i]-center)*0.84+Vector2(0,-0.7)
  draw_colored_polygon(puff,Color(0.78,0.69,0.53,alpha*(0.32+float(layer)*0.07)))

func _draw_trail() -> void:
 if trail_points.size()<2: return
 var side:=aim.orthogonal()
 for i in range(15,-1,-1):
  var back:=float(i)*6.0
  if back>trail_span+0.01: continue
  var age:=back/TRAIL_LENGTH
  var center:=_trail_point(back)+Vector2(0,-7.0-age*10.0)+side*sin(float(i)*1.7)*3.0
  var radius:=10.0+age*9.0
  var opacity:=0.46*(1.0-age*0.65)
  _dust_cloud(center,radius*1.2,opacity*0.8,float(i)*1.3)
  for flank in [-1.0,1.0]:
   var p: Vector2=center+side*flank*(9.0+age*8.0)+Vector2(0,-sin(float(i)*2.3)*3.0)
   _dust_cloud(p,radius,opacity,float(i)*1.9+flank)
   if i%3==0:
    var chip: Vector2=p+side*flank*(radius+2.0)
    var fragment:=PackedVector2Array([chip+Vector2(-1.5,0),chip+Vector2(0,-2.3),chip+Vector2(2.0,0.6)])
    draw_colored_polygon(fragment,Color(0.52,0.43,0.30,opacity*1.25))

func _draw() -> void:
 if phase=="lunge":
  _draw_trail()
  return
 if phase=="lunge_recover": return
 if phase=="lunge_charge":
  var build:=clampf(1.0-left/charge_duration,0.0,1.0)
  var side:=aim.orthogonal()
  for foot in [-1.0,1.0]:
   var anchor: Vector2=-aim*19.0+side*foot*15.0
   var scrape:=fmod(clock*5.0+foot*0.25,1.0)
   draw_line(anchor+aim*(4.0-scrape*10.0),anchor-aim*(8.0+scrape*8.0),Color(0.48,0.37,0.24,0.3+build*0.2),1.4,true)
   for i in 5:
    var t:=fmod(clock*2.8+float(i)*0.2+foot*0.11,1.0)
    var p:=anchor-aim*(6.0+t*27.0)+side*sin(float(i)*2.1)*5.0+Vector2(0,-t*6.0)
    draw_circle(p,2.5+t*6.0,Color(0.68,0.55,0.36,(1.0-t)*(0.15+build*0.17)))
    draw_circle(p+Vector2(-1,-1),1.3+t*3.0,Color(0.91,0.82,0.61,(1.0-t)*0.2))
  return
 if phase=="rest":
  return
 if shape.size()<3: return
 var progress:=clampf(1.0-left/(preload("res://scripts/maze/combat_tuning.gd").number("rock.roar","charge",1.1) if phase=="charge" else preload("res://scripts/maze/combat_tuning.gd").number("rock.roar","release",0.45)),0,1)
 var color:=Color(0.83,0.58,0.34,0.035+progress*0.045) if phase=="charge" else Color(1.0,0.78,0.47,0.07*(1.0-progress))
 draw_colored_polygon(shape,color)
 var edge:=shape.duplicate()
 edge.append(shape[0])
 draw_polyline(edge,Color(0.69,0.47,0.29,0.32 if phase=="charge" else 0.22*(1.0-progress)),1.0,true)
 if phase=="charge":
  var tip:=aim*minf(32.0,Area.reach(global_position,aim,32.0))
  draw_line(Vector2.ZERO,tip,Color(0.85,0.69,0.44,0.30),1.0,true)
  draw_line(tip,tip-aim.rotated(0.5)*5.0,Color(0.85,0.69,0.44,0.30),1.0,true)
  draw_line(tip,tip-aim.rotated(-0.5)*5.0,Color(0.85,0.69,0.44,0.30),1.0,true)
  return
 # 释放由子节点显示原气流图；多边形与实际扇形/遮挡完全共用。

func snapshot() -> Dictionary:
 return {"phase":phase,"left":left,"origin":global_position,"shape":shape.duplicate(),"aim":aim,"danger_visible":phase in ["charge","rush"] and shape.size()>2,"rest_visible":false,"wave_source":WAVE_SOURCE.resource_path,"wave_visible":is_instance_valid(wave) and wave.visible,"wave_age":wave_age,"wave_duration":WAVE_DURATION,"wave_origin":[wave_origin.x,wave_origin.y],"trail_span":trail_span,"trail_points":trail_points.duplicate()}
