extends Node2D
## 水面范围与伤害共用多边形；身体电花独立叠加，不持有或修改战斗状态。
const Run=preload("res://scripts/maze/capture_run.gd")
const Eel=preload("res://scripts/maze/thunder_eel_combat.gd")
const Area=preload("res://scripts/maze/fenshui_electric_area.gd")
var snapshot: Dictionary={}
var discharge: Texture2D

func _ready() -> void:
 discharge=ImageTexture.create_from_image(Image.load_from_file("res://assets/monsters/thunder_eel/discharge.png"))

func _process(_delta: float) -> void:
 snapshot=Run.snapshot(get_node("/root/SaveManager"))
 queue_redraw()

func _draw() -> void:
 if snapshot.is_empty() or not snapshot.get("active",false): return
 var c: Dictionary=snapshot.combat
 if c.get("region","")!="fenshui" or c.get("fs01_trial",false): return
 for id in c.actors:
  var a: Dictionary=c.actors[id]
  if id.begins_with("fenshui_silverfish_") and a.hp>0 and snapshot.monsters[id].status=="alive" and float(a.get("electric_left",0.0))>3.7:
   var alpha:=clampf((float(a.electric_left)-3.7)/0.3,0.0,1.0)
   draw_texture_rect_region(discharge,Rect2(Eel.vec(a.position)-Vector2(36,46),Vector2(72,72)),Rect2(0,256,256,256),Color(1,1,1,alpha))
  elif Eel.enabled(c,id) and a.hp>0 and a.get("eel_phase","") in ["charging","discharge"]:
   var charging: bool=a.eel_phase=="charging"
   var strength:=1.0-float(a.eel_left)/Eel.CHARGE_TIME if charging else 1.0
   var frame:=Vector2(0,0) if charging else Vector2(256,0)
   var center:=Eel.vec(a.position)
   var shape:=Area.polygon(center,id)
   if shape.size()>2:
    draw_colored_polygon(shape,Color(1.0,0.83,0.39,0.055 if charging else 0.1))
    var outline:=shape.duplicate()
    outline.append(shape[0])
    draw_polyline(outline,Color(1.0,0.83,0.39,0.25+strength*0.35),1.0,true)
    if not charging:
     var progress:=clampf(1.0-float(a.eel_left)/Eel.DISCHARGE_TIME,0.02,1.0)
     # 多边形以中心向各方向直线截断，向内缩放的每段仍在同一有效区域内。
     draw_set_transform(center)
     for i in shape.size():
      var first:=shape[i]-center
      var last:=shape[(i+1)%shape.size()]-center
      var inner:=maxf(0.0,progress-0.055)
      var band:=PackedVector2Array([center+first*inner,center+first*progress,center+last*progress])
      if inner>0.0: band.append(center+last*inner)
      var local_band:=PackedVector2Array()
      for point in band: local_band.append(point-center)
      draw_colored_polygon(local_band,Color(1.0,0.9,0.55,0.65*(1.0-progress*0.5)))
     draw_set_transform(Vector2.ZERO)
   draw_texture_rect_region(discharge,Rect2(Eel.vec(a.position)-Vector2(48,58),Vector2(96,96)),Rect2(frame,Vector2(256,256)),Color(1,1,1,0.3+strength*0.7))
