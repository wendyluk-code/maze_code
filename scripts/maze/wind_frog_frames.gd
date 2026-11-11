extends RefCounted
## 原右前18姿态保留；其他三向按各自交付矩形加载完整链。
const SOURCES=["res://assets/monsters/wind_frog/counter_candidate/frog-v3.png","res://assets/monsters/wind_frog/counter_candidate/transition-v2.png"]
# 按原图实际独立主体定位，不按四等分裁掉跨格手脚；原第13格不采用。
const BOUNDS=[Rect2i(46,121,245,180),Rect2i(350,137,247,164),Rect2i(627,110,303,191),Rect2i(938,90,305,195),Rect2i(39,386,280,241),Rect2i(356,386,269,243),Rect2i(659,400,285,232),Rect2i(965,403,281,215),Rect2i(28,718,297,207),Rect2i(347,715,280,199),Rect2i(661,714,278,201),Rect2i(973,722,250,195),Rect2i(78,142,580,455),Rect2i(774,180,619,389),Rect2i(1469,169,666,449),Rect2i(336,1012,298,187),Rect2i(668,1014,244,186),Rect2i(974,1011,247,186)]
const NAMES=["蹲姿","压低蓄力","后腿蹬出","空中伸展","受击后仰","四肢失衡","侧翻下落","背部着地","露腹缓冲","露腹呼气","露腹吸气","蜷趾","仰躺收腿","侧卧触地","侧卧撑起","双掌撑地","后腿收回","恢复蹲姿"]
const SEQUENCE=[0,1,2,3,4,5,6,7,8,9,10,11,8,9,10,11,8,9,10,11,12,13,14,15,16,17]
const KEY_FRAMES=[0,3,8,15]
const DIRECTION_SOURCES={1:"res://assets/monsters/wind_frog/counter_candidate/directions/front-left-padded-v2.png",2:"res://assets/monsters/wind_frog/counter_candidate/directions/back-right-padded.png",3:"res://assets/monsters/wind_frog/counter_candidate/directions/back-left-padded.png"}
const LEFT_ROOT="res://assets/monsters/wind_frog/counter_candidate/directions/left-chain/"
const LEFT_PARTS={"charge":[1,2],"fall":[4,5,6,7],"breath":[9,10,11],"rise":[12,13,14,16,17]}
var textures: Array[Texture2D]=[]
var regions: Array[Rect2i]=[]
var reference_width:=80.0
var direction_keys: Dictionary={}
var left_chain: Array=[]
var direction_chains: Dictionary={}
var sheet_bounds: Dictionary={}
var sheet_center:=Vector2.ZERO
var using_sheet:=false

func load_frames(width: float=80.0) -> void:
 reference_width=width
 direction_keys.clear()
 left_chain.clear()
 direction_chains.clear()
 textures.clear()
 regions.clear()
 var sheets: Array[Texture2D]=[]
 for path in SOURCES: sheets.append(load(path) as Texture2D)
 for i in BOUNDS.size():
  var source: Texture2D=sheets[1 if i in [12,13,14] else 0]
  var region: Rect2i=BOUNDS[i].grow(2).intersection(Rect2i(Vector2i.ZERO,Vector2i(source.get_width(),source.get_height())))
  var atlas:=AtlasTexture.new()
  atlas.atlas=source
  atlas.region=Rect2(region)
  atlas.filter_clip=true
  textures.append(atlas)
  regions.append(region)

func draw_direction_key(body: Sprite2D, index: int, direction: int) -> bool:
 # 显式关键姿态接口，不参与未齐帧的正式连续方向切换。
 if index not in KEY_FRAMES or direction<0 or direction>3: return false
 if direction==0:
  if textures.size()!=18: return false
  draw_pose(body,index)
  return true
 if not _load_direction_keys(direction): return false
 var entry: Dictionary=direction_keys[direction][KEY_FRAMES.find(index)]
 _draw_entry(body,entry,reference_width/float(direction_keys[direction][0].bounds.size.x),index)
 return true

func _load_direction_keys(direction: int) -> bool:
 if not direction_keys.has(direction):
  var source: Texture2D=load(DIRECTION_SOURCES[direction])
  if source==null: return false
  var image: Image=source.get_image()
  var entries: Array=[]
  for key in 4:
   var cell:=Rect2i(Vector2i(key%2,key/2)*1024,Vector2i(1024,1024))
   var local: Rect2i=image.get_region(cell).get_used_rect()
   if local.size.x<=0 or local.size.y<=0: return false
   var bounds:=Rect2i(cell.position+local.position,local.size)
   var region: Rect2i=bounds.grow(2).intersection(cell)
   var atlas:=AtlasTexture.new()
   atlas.atlas=source
   atlas.region=Rect2(region)
   atlas.filter_clip=true
   entries.append({"texture":atlas,"bounds":bounds,"region":region})
  direction_keys[direction]=entries
 return true

func _draw_entry(body: Sprite2D, entry: Dictionary, scale: float, index: int) -> void:
 using_sheet=false
 var bounds: Rect2i=entry.bounds
 var region: Rect2i=entry.region
 var anchor: Rect2i=entry.get("visible_bounds",bounds)
 body.texture=entry.texture
 body.region_enabled=false
 body.centered=false
 body.flip_h=false
 body.flip_v=false
 body.rotation=0.0
 body.scale=Vector2.ONE*scale
 body.offset=-Vector2(Vector2(bounds.position-region.position)+Vector2(bounds.size)*Vector2(0.5,1.0))
 if entry.has("visible_bounds"):
  body.offset.y=-float(anchor.end.y-region.position.y)
 body.position=Vector2(0,[-0.0,0.0,-8.0,-36.0,-28.0,-16.0,-8.0,0.0][index] if index<8 else 0.0)

func _load_chain(direction: int) -> bool:
 if direction_chains.has(direction): return true
 if not _load_direction_keys(direction): return false
 var root: String=LEFT_ROOT if direction==1 else "res://assets/monsters/wind_frog/counter_candidate/directions/"+("back-right-chain/" if direction==2 else "back-left-chain/")
 var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(root+"prepared.json"))
 if not manifest is Dictionary: return false
 var entries: Array=[]
 entries.resize(18)
 var base_image: Image=direction_keys[direction][0].texture.atlas.get_image()
 for key in 4:
  entries[KEY_FRAMES[key]]=direction_keys[direction][key].duplicate()
  entries[KEY_FRAMES[key]].norm=627.0
  entries[KEY_FRAMES[key]].visible_bounds=_visible_bounds(base_image,entries[KEY_FRAMES[key]].bounds)
 for part in LEFT_PARTS:
  if not manifest.has(part): return false
  var spec: Dictionary=manifest[part]
  var source: Texture2D=load(root+str(spec.file))
  if source==null: return false
  var image: Image=source.get_image()
  for cell in LEFT_PARTS[part].size():
   var frame: Dictionary=spec.frames[cell]
   # 只消费无损交付中的真实矩形，不能按原生成图等分再裁手脚。
   var origin:=Vector2i(frame.target[0]+frame.offset[0],frame.target[1]+frame.offset[1])
   var cell_rect:=Rect2i(origin,Vector2i(frame.rect[2],frame.rect[3]))
   var local: Rect2i=image.get_region(cell_rect).get_used_rect()
   if local.size.x<=0 or local.size.y<=0: return false
   var bounds:=Rect2i(cell_rect.position+local.position,local.size)
   var region: Rect2i=bounds.grow(2).intersection(cell_rect)
   var atlas:=AtlasTexture.new()
   atlas.atlas=source
   atlas.region=Rect2(region)
   atlas.filter_clip=true
   entries[LEFT_PARTS[part][cell]]={"texture":atlas,"bounds":bounds,"region":region,"norm":float(spec.norm),"visible_bounds":_visible_bounds(image,bounds)}
 direction_chains[direction]=entries
 if direction==1: left_chain=entries
 return true

func _visible_bounds(image: Image, rect: Rect2i) -> Rect2i:
 # 沿用怪物原脚底定位的Alpha>=0.5；只用于锚点，不删除任何淡边像素。
 var left:=rect.end.x
 var top:=rect.end.y
 var right:=rect.position.x-1
 var bottom:=rect.position.y-1
 for y in range(rect.position.y,rect.end.y):
  for x in range(rect.position.x,rect.end.x):
   if image.get_pixel(x,y).a<0.5: continue
   left=mini(left,x)
   top=mini(top,y)
   right=maxi(right,x)
   bottom=maxi(bottom,y)
 return Rect2i(left,top,right-left+1,bottom-top+1)

func draw_direction_pose(body: Sprite2D, index: int, direction: int) -> bool:
 if index<0 or index>=18: return false
 if direction==0:
  if textures.size()!=18: return false
  draw_pose(body,index)
  return true
 if direction not in [1,2,3] or not _load_chain(direction): return false
 var entry: Dictionary=direction_chains[direction][index]
 # 参考原画宽627，而非加透明留白后的1024／1280；同段不逐帧拉伸。
 var scale:=reference_width/float(direction_keys[direction][0].bounds.size.x)*627.0/float(entry.norm)
 _draw_entry(body,entry,scale,index)
 return true

func body_center(body: Sprite2D, index: int, direction: int) -> Vector2:
 if using_sheet: return body.position+sheet_center
 if not direction_chains.has(direction):
  return body.position+body.get_rect().get_center()*body.scale
 var entry: Dictionary=direction_chains[direction][index]
 var visible: Rect2i=entry.visible_bounds
 return body.position+(body.offset+Vector2(visible.position-entry.region.position)+Vector2(visible.size)*0.5)*body.scale

func duration(index: int) -> float:
 return 0.8 if index==3 else (0.25 if index in [8,9,10,11] else 0.14)

func draw_pose(body: Sprite2D, index: int) -> void:
 using_sheet=false
 var bounds: Rect2i=BOUNDS[index]
 var region: Rect2i=regions[index]
 var normalized_scale:=313.5/724.0 if index in [12,13,14] else 1.0
 body.texture=textures[index]
 body.region_enabled=false
 body.centered=false
 body.flip_h=false
 body.flip_v=false
 body.rotation=0.0
 body.scale=Vector2.ONE*reference_width/245.0*normalized_scale
 body.offset=-Vector2(Vector2(bounds.position)+Vector2(bounds.size)*Vector2(0.5,1.0)-Vector2(region.position))
 # 复用原巨蛙36像素跃起高度；不旋转图像或延长静帧伪造动作。
 body.position=Vector2(0,[-0.0,0.0,-8.0,-36.0,-28.0,-16.0,-8.0,0.0][index] if index<8 else 0.0)

func prepare_directions(sheets: Dictionary) -> void:
 # 在场景准备期取完可见边界，战斗切向不再逐像素扫描。
 for direction in [1,2,3]: _load_chain(direction)
 for key in ["idle","attack","defeated"]:
  var texture: Texture2D=sheets[key]
  var image: Image=texture.get_image()
  var cell:=Vector2i(image.get_width()/4,image.get_height()/4)
  var entries: Array=[]
  for index in 16: entries.append(_visible_bounds(image,Rect2i(Vector2i(index%4,index/4)*cell,cell)))
  sheet_bounds[texture]=entries

func draw_sheet(body: Sprite2D, texture: Texture2D, index: int, direction: int, width: float) -> void:
 var cell:=Vector2(texture.get_width()/4.0,texture.get_height()/4.0)
 var bounds: Rect2i=sheet_bounds[texture][direction*4+index]
 var local:=Rect2i(bounds.position-Vector2i(Vector2(index,direction)*cell),bounds.size)
 body.texture=texture
 body.region_enabled=true
 body.region_rect=Rect2(Vector2(index,direction)*cell,cell)
 body.centered=false
 body.flip_h=false
 body.flip_v=false
 body.rotation=0.0
 body.scale=Vector2.ONE*width/cell.x
 body.offset=Vector2(-cell.x*0.5,-float(local.end.y))
 body.position=Vector2.ZERO
 sheet_center=(body.offset+Vector2(local.position)+Vector2(local.size)*0.5)*body.scale
 using_sheet=true

static func pose(actor: Dictionary) -> int:
 var left:=float(actor.frog_left)
 match str(actor.frog_phase):
  "warning": return 0 if left>0.28 else (1 if left>0.14 else 2)
  "airborne": return 3
  "toppling": return clampi(4+int((0.56-left)/0.14),4,7)
  "exposed": return 8+int(maxf(0.0,3.0-left)/0.25)%4
  "recovering": return clampi(12+int((0.84-left)/0.14),12,17)
  "landing": return clampi(15+int((1.2-left)/0.14),15,17) if left>0.78 else 0
 return 0

