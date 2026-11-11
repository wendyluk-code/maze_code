extends RefCounted
## 用户认可的双前向候选；不表示背向图已齐。原图无损，所有姿态统一尺度。
const PATH="res://assets/monsters/wind_frog/counter_candidate/front24.png"
const CELL=181
var entries: Array=[]
var reference_width:=107.9166667
var current_pose:=0
var current_direction:=0

func load_frames(width: float) -> bool:
 reference_width=width
 var texture: Texture2D=load(PATH)
 if texture==null or texture.get_size()!=Vector2(1448,1086): return false
 var image: Image=texture.get_image()
 for n in 48:
  var region:=Rect2i(Vector2i(n%8,n/8)*CELL,Vector2i(CELL,CELL))
  var bounds:=Rect2i(CELL,CELL,0,0)
  var right:=-1
  var bottom:=-1
  for y in CELL:
   for x in CELL:
    if image.get_pixel(region.position.x+x,region.position.y+y).a<0.5: continue
    bounds.position.x=mini(bounds.position.x,x)
    bounds.position.y=mini(bounds.position.y,y)
    right=maxi(right,x)
    bottom=maxi(bottom,y)
  if right<0: return false
  bounds.size=Vector2i(right,bottom)-bounds.position+Vector2i.ONE
  var frame:=AtlasTexture.new()
  frame.atlas=texture
  frame.region=Rect2(region)
  frame.filter_clip=true
  entries.append({"texture":frame,"bounds":bounds})
 return true

static func pose(actor: Dictionary, elapsed: float, defeated: bool=false, belly: bool=false) -> int:
 if defeated: return (22 if belly else 20)+(1 if elapsed>=0.24 else 0)
 var left:=float(actor.get("frog_left",0.0))
 if float(actor.get("frog_spit_left",0.0))>0 and actor.get("frog_phase","") not in ["toppling","exposed","recovering"]:
  var remaining:=float(actor.frog_spit_left)*280.0/maxf(1.0,preload("res://scripts/maze/combat_tuning.gd").effect("water","recover",280.0))
  return 9 if remaining>0.18 else (10 if remaining>0.08 else 0)
 match str(actor.get("frog_phase","active")):
  "warning":
   var normalized:=left*1000.0/maxf(1.0,preload("res://scripts/maze/combat_tuning.gd").effect("slam","windup",1000.0))
   return 0 if normalized>0.4 else (2 if normalized>0.14 else 3)
  "airborne": return 4 if left>0.24 else 5
  "landing":
   var normalized:=left*1200.0/maxf(1.0,preload("res://scripts/maze/combat_tuning.gd").effect("slam","recover",1200.0))
   return 6 if normalized>0.94 else (7 if normalized>0.78 else 0)
  "toppling": return 11 if left>0.48 else (12 if left>0.28 else 13)
  "exposed": return 14+int(maxf(0.0,3.0-left)/0.25)%2
  "recovering":
   if left>0.74: return 16
   if left>0.56: return 17
   if left>0.20: return 18
   return 19 if left>0.08 else 0
 if actor.get("mode","")=="windup": return 8
 return 0 if fmod(elapsed,1.2)<0.7 else 1

func draw_pose(body: Sprite2D, index: int, direction: int) -> void:
 current_pose=index
 current_direction=direction%2
 var entry: Dictionary=entries[current_direction*24+index]
 var bounds: Rect2i=entry.bounds
 body.texture=entry.texture
 body.region_enabled=false
 body.centered=false
 body.flip_h=false
 body.flip_v=false
 body.rotation=0.0
 body.scale=Vector2.ONE*reference_width/float(entries[current_direction*24].bounds.size.x)
 body.offset=Vector2(-float(bounds.position.x+bounds.end.x)*0.5,-float(bounds.end.y))
 body.position=Vector2.ZERO
 if index==11: body.position.y=-28.0
 elif index==12: body.position.y=-16.0

func body_center(body: Sprite2D) -> Vector2:
 var bounds: Rect2i=entries[current_direction*24+current_pose].bounds
 return body.position+(body.offset+Vector2(bounds.get_center()))*body.scale

func mouth_offset(direction: int) -> Vector2:
 var d:=direction%2
 var bounds: Rect2i=entries[d*24+9].bounds
 var mouth: Vector2=[Vector2(145,96),Vector2(44,82)][d]
 var anchor:=Vector2(float(bounds.position.x+bounds.end.x)*0.5,bounds.end.y)
 return (mouth-anchor)*reference_width/float(entries[d*24].bounds.size.x)

func capture_frames(direction: int, defeated: bool=false, belly: bool=false) -> Array[Texture2D]:
 var result: Array[Texture2D]=[]
 for i in [23 if belly else 21] if defeated else [0,1,0,1]:
  var entry: Dictionary=entries[(direction%2)*24+i]
  var atlas:=AtlasTexture.new()
  atlas.atlas=entry.texture.atlas
  atlas.region=Rect2(entry.texture.region.position+Vector2(entry.bounds.position),Vector2(entry.bounds.size))
  result.append(atlas)
 return result
