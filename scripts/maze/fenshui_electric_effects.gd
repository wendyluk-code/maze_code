extends Node2D
## 只读战斗状态；水面纹理与命中共用多边形。
const Run=preload("res://scripts/maze/capture_run.gd")
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
const PAD_SCALE=787.0/627.0
var snapshot: Dictionary={}
var sheets: Dictionary={}
var ground: Node2D

func _ready() -> void:
 for key in ["01-charge","02-water-area","03-hit-break"]:
  var frames: Array[Texture2D]=[]
  for i in 4:
   frames.append(ImageTexture.create_from_image(Image.load_from_file("res://assets/effects/fenshui/%s-%d.png" % [key,i])))
  sheets[key]=frames
 call_deferred("_install_ground")

func _install_ground() -> void:
 ground=Node2D.new()
 ground.name="FenshuiVfxWater"
 ground.draw.connect(_draw_ground)
 get_parent().add_child(ground)
 get_parent().move_child(ground,1)

func _exit_tree() -> void:
 if is_instance_valid(ground): ground.queue_free()

func _process(_delta: float) -> void:
 snapshot=Run.snapshot(get_node("/root/SaveManager"))
 queue_redraw()
 if is_instance_valid(ground): ground.queue_redraw()

func _active() -> bool:
 return not snapshot.is_empty() and snapshot.get("active",false) and snapshot.combat.get("region","")=="fenshui" and not snapshot.combat.get("fs01_trial",false)

func _draw_ground() -> void:
 if not _active(): return
 var c: Dictionary=snapshot.combat
 for id in c.actors:
  var a: Dictionary=c.actors[id]
  if not Eel.enabled(c,id) or a.hp<=0 or snapshot.monsters[id].status!="alive": continue
  var phase: String=a.get("eel_phase","")
  if phase not in ["charging","discharge"] or float(a.eel_left)<=0: continue
  var charging:=phase=="charging"
  var elapsed: float=Eel.CHARGE_TIME-float(a.eel_left) if charging else Eel.DISCHARGE_TIME-float(a.eel_left)
  var frame:=0 if charging else (1 if elapsed<0.1 else (2 if elapsed<0.2 else 3))
  # 实现初值2Hz，最低35%亮度；随阶段剩时变化，暂停不继续闪烁。
  var alpha:=0.35+0.65*(0.5+0.5*cos(TAU*2.0*elapsed)) if charging else 1.0
  var center:=Eel.vec(a.position)
  var shape:=Area.polygon(center,id)
  var uv:=PackedVector2Array()
  for point in shape: uv.append((point-center)/(312.5*PAD_SCALE)+Vector2(0.5,0.5))
  if shape.size()>2: ground.draw_polygon(shape,PackedColorArray([Color(1,1,1,alpha)]),uv,sheets["02-water-area"][frame])

func _draw() -> void:
 if not _active(): return
 var c: Dictionary=snapshot.combat
 for id in c.actors:
  var a: Dictionary=c.actors[id]
  if a.hp<=0 or snapshot.monsters[id].status!="alive": continue
  if id.begins_with("fenshui_silverfish_"):
   var elapsed:=4.0-float(a.get("electric_left",0.0))
   if elapsed>=0.0 and elapsed<0.3:
    var frame:=0 if elapsed<0.1 else (1 if elapsed<0.17 else (2 if elapsed<0.24 else 3))
    var size:=Vector2.ONE*72.0*PAD_SCALE
    draw_texture_rect(sheets["03-hit-break"][frame],Rect2(Eel.vec(a.position)-Vector2(0,10)-size*0.5,size),false)
  elif Eel.enabled(c,id) and a.get("eel_phase","") in ["charging","discharge"] and float(a.eel_left)>0.0:
   var charging: bool=a.eel_phase=="charging"
   var elapsed: float=Eel.CHARGE_TIME-float(a.eel_left) if charging else Eel.DISCHARGE_TIME-float(a.eel_left)
   var frame:= (0 if elapsed<0.6 else 1) if charging else (2 if elapsed<0.1 else 3)
   var size:=Vector2.ONE*96.0*PAD_SCALE
   draw_texture_rect(sheets["01-charge"][frame],Rect2(Eel.vec(a.position)-Vector2(0,10)-size*0.5,size),false)
