extends Node2D
## 已认可玩家受击原图的纯显示；恢复门禁由战斗事务负责，不修改朝向或物理位置。
const Appearance=preload("res://scripts/characters/hero_animation.gd")
const Hurt=preload("res://scripts/maze/player_hurt_event.gd")
const SilverfishEditor=preload("res://scripts/maze/silverfish_editor.gd")
const Tuning=preload("res://scripts/maze/combat_tuning.gd")
func effect_value(key: String, fallback: float) -> float:
 return SilverfishEditor.value(key) if kind=="fish" else Tuning.effect(kind,key,fallback)
const EFFECT_TIMES=[0.030,0.035,0.045,0.045,0.040,0.035]
const POSE_TIMES=[0.050,0.070,0.070,0.410]
const SLAM_POSE_TIMES=[0.050,0.070,0.070,0.710]
const WIDTHS={"fish":110.0,"electric":142.0,"water":106.0,"slam":128.0}
var flow: Node
var pose: Sprite2D
var effect: Sprite2D
var sheets: Dictionary={}
var kind:=""
var age:=1.0
var direction:=Vector2.DOWN
var received:=0
var pose_frame:=-1
var effect_frame:=-1
var _fresh:=false
var rock_lift:=0.0
var _owns_pose:=false
# 正常五图由角色共用模块开启已认可持续痛态；旧工具入口可继续显式启用。
var refined_pose:=false
var _pose_bounds: Array[Rect2]=[]
var _normal_bounds:=Rect2()
var _direction_bounds: Dictionary={}
var _direction_normal: Dictionary={}

func enable_refined_pose() -> void:
 refined_pose=true
 if not _pose_bounds.is_empty(): return
 for frame in sheets.hero: _pose_bounds.append(_opaque_bounds(frame))
 _normal_bounds=_opaque_bounds(Appearance.ANIMATIONS.get_frame_texture(&"front_idle",0))
 for side in ["left","right","back"]:
  var bounds: Array[Rect2]=[]
  for frame in sheets[side]: bounds.append(_opaque_bounds(frame))
  _direction_bounds[side]=bounds
  _direction_normal[side]=_opaque_bounds(Appearance.ANIMATIONS.get_frame_texture(StringName(side+"_idle"),0))

func _opaque_bounds(texture: Texture2D) -> Rect2:
 var image:=texture.get_image()
 var low:=Vector2i(image.get_width(),image.get_height())
 var high:=Vector2i(-1,-1)
 for y in image.get_height():
  for x in image.get_width():
   if image.get_pixel(x,y).a<0.5: continue
   low.x=mini(low.x,x)
   low.y=mini(low.y,y)
   high.x=maxi(high.x,x)
   high.y=maxi(high.y,y)
 return Rect2(low,high-low+Vector2i.ONE)

func _ready() -> void:
 process_priority=100
 for key in ["hero","fish","electric","water","slam"]:
  var texture: Texture2D=load("res://assets/effects/fenshui/player_hurt/"+key+".png")
  var frames: Array[Texture2D]=[]
  for index in 6:
   var frame:=AtlasTexture.new()
   frame.atlas=texture
   frame.region=Rect2((index%3)*512,(index/3)*512,512,512)
   frames.append(frame)
  sheets[key]=frames
 var directions: Texture2D=load("res://assets/effects/fenshui/player_hurt/three_directions_v1.png")
 for row in 3:
  var frames: Array[Texture2D]=[]
  for column in 4:
   var frame:=AtlasTexture.new()
   frame.atlas=directions
   frame.region=Rect2(column*362,row*362,362,362)
   frames.append(frame)
  sheets[["left","right","back"][row]]=frames
 pose=Sprite2D.new()
 pose.name="ApprovedFrontHurtPose"
 pose.centered=false
 pose.offset=Vector2(-256,-512*0.84)
 pose.z_index=2
 pose.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 pose.material=ShaderMaterial.new()
 pose.material.shader=preload("res://scripts/maze/hit_flash.gdshader")
 pose.hide()
 add_child(pose)
 effect=Sprite2D.new()
 effect.name="ApprovedHurtContact"
 effect.centered=false
 effect.offset=Vector2(-512*0.48,-512*0.52)
 effect.z_index=3
 effect.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 effect.hide()
 add_child(effect)
 visibility_changed.connect(func():
  if not is_visible_in_tree(): clear())

func active() -> bool:
 return not kind.is_empty() and age<maxf(Hurt.recovery_time(kind),effect_value("fx_duration",230.0)/1000.0)

func receive(event: Dictionary) -> void:
 if not WIDTHS.has(event.get("kind","")) and event.get("kind","")!="physical": return
 kind=event.kind
 direction=Vector2(event.direction[0],event.direction[1])
 age=0.0
 received+=1
 _fresh=true
 _render()

func clear() -> void:
 rock_lift=0.0
 kind=""
 age=1.0
 pose_frame=-1
 effect_frame=-1
 _fresh=false
 if is_instance_valid(pose): pose.hide()
 if is_instance_valid(effect): effect.hide()
 _restore_pose()

func _restore_pose() -> void:
 if not _owns_pose: return
 _owns_pose=false
 if not is_instance_valid(flow) or not is_instance_valid(flow.maze): return
 var action_live: bool=float(flow.display_run().get("combat",{}).get("action_left",0.0))>0.0
 flow.maze.player.body.visible=not action_live
 if is_instance_valid(flow.skill_visual): flow.skill_visual.hero.visible=action_live

func _process(delta: float) -> void:
 if not active(): return
 if not is_instance_valid(flow) or not is_instance_valid(flow.maze) or not is_visible_in_tree():
  clear()
  return
 var run: Dictionary=flow.display_run()
 if not run.get("active",false) or float(run.get("combat",{}).get("hp",0.0))<=0.0 or not flow.character_combat_enabled():
  clear()
  return
 if not flow.combat_paused():
  if refined_pose:
   # 显示消费真实恢复剩时；保存重试等短暂事务停顿不能让痛态先走完。
   var left: float=float(run.combat.get("hurt_recovery_left",0.0))
   age=clampf(Hurt.recovery_time(kind)-left,0.0,Hurt.recovery_time(kind)) if left>0.0 else maxf(age+delta,Hurt.recovery_time(kind))
   _fresh=false
  elif _fresh: _fresh=false
  else: age+=delta
 if not active(): clear()
 else: _render()

func preview_scale() -> float:
 # 固定沿正常人物的画布标定，不能从当前受击图反推，避免重复放大。
 var texture: Texture2D=Appearance.ANIMATIONS.get_frame_texture(&"front_idle",0)
 var camera: Camera2D=get_viewport().get_camera_2d()
 var zoom: float=camera.zoom.y if is_instance_valid(camera) else 1.0
 return texture.get_height()*Appearance.BODY_HEIGHT/Appearance.FRAME_BODY_HEIGHT*Appearance.REFERENCE_CAMERA_ZOOM/zoom/260.0

func _index(time: float, durations: Array) -> int:
 var end:=0.0
 for i in durations.size():
  end+=float(durations[i])
  if time<end: return i
 return -1

func _render() -> void:
 if not is_instance_valid(flow) or not is_instance_valid(pose) or not active(): return
 var player: Node2D=flow.maze.player
 pose.modulate.a=1.0
 pose.self_modulate.a=1.0
 pose.material.set_shader_parameter("flash",false)
 var scale_from_preview:=preview_scale()
 var forward: bool=absf(player.facing.x)<=0.1 and player.facing.y>=0.0
 var pose_times: Array=(SLAM_POSE_TIMES if kind=="slam" else POSE_TIMES).duplicate()
 if kind=="fish": pose_times[3]=maxf(0.0,Hurt.recovery_time(kind)-0.19)
 pose_frame=_index(age,pose_times)+1
 if refined_pose: pose_frame=(2 if age>=0.050 and age<0.120 else 1) if age<Hurt.recovery_time(kind) else 0
 if refined_pose and pose_frame>0:
  _render_refined_pose(player,forward)
 elif forward and pose_frame>0:
  pose.texture=sheets.hero[pose_frame]
  pose.scale=Vector2.ONE*260.0*scale_from_preview/512.0
  pose.show()
  _owns_pose=true
  player.body.hide()
  if is_instance_valid(flow.skill_visual): flow.skill_visual.hero.hide()
 else:
  pose.hide()
  _restore_pose()
 rock_lift=0.0
 var combat: Dictionary=flow.display_run().get("combat",{})
 var launch_left:=float(combat.get("rock_launch_left",0.0))
 if kind=="physical" and launch_left>0.0 and pose.visible:
  var flight:=clampf(1.0-launch_left/0.3,0.0,1.0)
  rock_lift=22.0*sin(PI*flight)
  pose.position.y-=rock_lift
  pose.rotation=sin(PI*flight)*0.16*(-1.0 if direction.x<0 else 1.0)
  if flight>0.8: pose.scale*=Vector2(1.0+0.06*sin((flight-0.8)*PI/0.2),1.0-0.06*sin((flight-0.8)*PI/0.2))
 effect_frame=_index(age*230.0/effect_value("fx_duration",230.0),EFFECT_TIMES) if sheets.has(kind) else -1
 effect.visible=effect_frame>=0
 effect.modulate.a=effect_value("opacity",100.0)/100.0
 effect.rotation=deg_to_rad(effect_value("angle",0.0))
 if effect.visible:
  effect.texture=sheets[kind][effect_frame]
  var offsets: Array=[Vector2.ZERO,Vector2(-1,4),Vector2(6,-5),Vector2(2,-1),Vector2.ZERO,Vector2.ZERO]
  effect.position=(Vector2(-4,-79)+(offsets[pose_frame] if forward and pose_frame>0 else Vector2.ZERO))*scale_from_preview
  effect.position+=Vector2(effect_value("offset_x",0.0),effect_value("offset_y",0.0))
  var side: float=-1.0 if direction.x<0 and kind!="slam" else 1.0
  effect.scale=Vector2(side,1.0)*float(WIDTHS[kind])*scale_from_preview/512.0
  effect.scale*=effect_value("fx_scale",100.0)/100.0

func _render_refined_pose(player: Node2D, forward: bool) -> void:
 if _pose_bounds.is_empty(): enable_refined_pose()
 pose.rotation=0.0
 if forward:
  var normal_scale: float=player.body.scale.y
  var scale_factor: float=_normal_bounds.size.y*normal_scale/_pose_bounds[0].size.y
  var rect: Rect2=_pose_bounds[pose_frame]
  pose.texture=sheets.hero[pose_frame]
  pose.scale=Vector2.ONE*scale_factor
  pose.offset=Vector2(-rect.get_center().x,-rect.end.y)
  pose.position=Vector2((_normal_bounds.get_center().x-Appearance.FRAME_FOOT.x)*normal_scale,(_normal_bounds.end.y-Appearance.FRAME_FOOT.y)*normal_scale)
 else:
  var side: String="right" if player.facing.x>0.1 else ("left" if player.facing.x< -0.1 else "back")
  # 接触、峰值、持痛、恢复；持续痛态由真实600/900毫秒剩时驱动。
  var recovery: float=Hurt.recovery_time(kind)
  pose_frame=0 if age<0.05 else (1 if age<0.12 else (2 if age<recovery-0.10 else 3))
  var normal: Rect2=_direction_normal[side]
  var rect: Rect2=_direction_bounds[side][pose_frame]
  var normal_scale: float=player.body.scale.y
  var scale_factor: float=normal.size.y*normal_scale/_direction_bounds[side][0].size.y
  pose.texture=sheets[side][pose_frame]
  pose.scale=Vector2.ONE*scale_factor
  pose.offset=Vector2(-rect.get_center().x,-rect.end.y)
  pose.position=Vector2((normal.get_center().x-Appearance.FRAME_FOOT.x)*normal_scale,(normal.end.y-Appearance.FRAME_FOOT.y)*normal_scale)
 pose.show()
 _owns_pose=true
 player.body.hide()
 if is_instance_valid(flow.skill_visual): flow.skill_visual.hero.hide()
