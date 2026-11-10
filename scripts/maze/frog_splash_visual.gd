extends Node2D
## 候选水花：只读真实状态，不结算伤害；仅隔离试玩主动安装。
const Boss=preload("res://data/maze/fenshui_boss.gd")
const Sheet=preload("res://assets/effects/fenshui/frog_splash/candidate_v1.png")
const DURATIONS={"takeoff":0.340,"landing":0.650}
# 视觉交付同页：参考蛙体132，起跳105、落地330。以相对体型换算，
# 不把预览画布像素当成世界单位，也不让伤害半径替代素材尺寸。
const WIDTH_PER_BODY={"takeoff":105.0/132.0,"landing":330.0/132.0}
var flow: Node
var back: Sprite2D
var front: Sprite2D
var frames: Array[Dictionary]=[]
var kind:=""
var age:=1.0
var frame:=-1
var takeoffs:=0
var landings:=0
var anchor:=Vector2.ZERO
var _phase:=""
var _clock:=-1.0
var _peaks:={"takeoff":0.0,"landing":0.0}

func _ready() -> void:
 process_priority=110
 # 与地图同层，按树序放在身体前；负全局层级会被整张地图盖住。
 get_parent().move_child(self,0)
 for z in [0,1]:
  var sprite:=Sprite2D.new()
  sprite.centered=false
  sprite.z_index=z
  sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  sprite.hide()
  add_child(sprite)
  if z==0: back=sprite
  else: front=sprite
 var image:=Sheet.get_image()
 var cell:=Vector2i(image.get_width()/3,image.get_height()/3)
 for i in 9:
  var origin:=Vector2i((i%3)*cell.x,(i/3)*cell.y)
  var part:=image.get_region(Rect2i(origin,cell))
  var bounds:=part.get_used_rect()
  var split:=clampi(int(bounds.position.y+bounds.size.y*0.64),1,cell.y-1)
  var upper:=AtlasTexture.new()
  upper.atlas=Sheet
  upper.region=Rect2(origin,Vector2i(cell.x,split))
  var lower:=AtlasTexture.new()
  lower.atlas=Sheet
  lower.region=Rect2(origin+Vector2i(0,split),Vector2i(cell.x,cell.y-split))
  frames.append({"back":upper,"front":lower,"x":bounds.get_center().x,"split":split})
  var key: String="takeoff" if i<3 else "landing"
  _peaks[key]=maxf(_peaks[key],bounds.size.x)

func clear() -> void:
 kind=""
 frame=-1
 age=1.0
 _phase=""
 _clock=-1.0
 if is_instance_valid(back): back.hide()
 if is_instance_valid(front): front.hide()

func _process(_dt: float) -> void:
 if not is_instance_valid(flow) or not is_visible_in_tree():
  clear()
  return
 var run: Dictionary=flow.display_run()
 var c: Dictionary=run.get("combat",{})
 var actor: Dictionary=c.get("actors",{}).get(Boss.ID,{})
 if not flow.target_lock_enabled() or actor.is_empty() or float(actor.get("hp",0.0))<=0.0:
  clear()
  return
 var clock: float=c.get("elapsed",0.0)
 if _clock>=0.0 and clock<_clock: clear()
 var step: float=maxf(0.0,clock-_clock) if _clock>=0.0 else 0.0
 _clock=clock
 if flow.combat_paused(): step=0.0
 if flow.axe_hitstop!=null and flow.axe_hitstop.paused(Boss.ID): step=0.0
 if not kind.is_empty(): age+=step
 var phase: String=actor.get("frog_phase","")
 if phase!=_phase:
  if _phase=="warning" and phase=="airborne":
   _begin("takeoff",Vector2(actor.frog_origin[0],actor.frog_origin[1]))
  elif _phase=="airborne" and phase=="landing":
   _begin("landing",Vector2(actor.position[0],actor.position[1]))
  _phase=phase
 _render()

func _begin(next_kind: String, point: Vector2) -> void:
 if not Boss.water(point): return
 kind=next_kind
 age=0.0
 anchor=point
 if kind=="takeoff": takeoffs+=1
 else: landings+=1

func _render() -> void:
 if kind.is_empty() or age>=float(DURATIONS[kind]):
  frame=-1
  back.hide()
  front.hide()
  return
 var start: int=0 if kind=="takeoff" else 3
 var count: int=3 if kind=="takeoff" else 6
 frame=start+mini(count-1,int(age/float(DURATIONS[kind])*count))
 var row: Dictionary=frames[frame]
 # 使用已含1.4倍率的正式参考蛙体，所有帧等比缩放且不重复乘1.4。
 var frog: Node=get_parent()
 var body_width: float=frog.frog_front24.reference_width if frog.frog_front24!=null else 148.0/192.0*float(frog.config.width)
 var width: float=body_width*float(WIDTH_PER_BODY[kind])
 var factor: float=width/float(_peaks[kind])
 global_position=anchor
 back.texture=row.back
 front.texture=row.front
 back.scale=Vector2.ONE*factor
 front.scale=back.scale
 back.offset=Vector2(-float(row.x),-float(row.split))
 front.offset=Vector2(-float(row.x),0.0)
 back.show()
 front.show()
