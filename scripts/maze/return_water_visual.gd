extends Node2D
## 复现已确认网页的临时汗滴；由怪物显示时钟推进，不写战斗状态。
const Water=preload("res://data/maze/fenshui_encounters.gd")
const Boss=preload("res://data/maze/fenshui_boss.gd")
const PERIOD=0.55
const FADE_TIME=0.6
var returning:=false
var clock:=0.0
var fade_left:=0.0
var frog_crossing:=false
var size_ratio:=1.0
var outline:=PackedVector2Array()

func _init() -> void:
 hide()
 # 与获准预览的三段曲线相同，轮廓只建一次。
 var a:=Vector2(0,-1.65)
 var b:=Vector2(0.75,0.8)
 var c:=Vector2(-0.75,0.3)
 for i in 13: outline.append(a.bezier_interpolate(Vector2(0.2,-0.45),Vector2(1,0.15),b,float(i)/12.0))
 for i in range(1,13): outline.append(b.bezier_interpolate(Vector2(0.3,1.5),Vector2(-0.9,1.1),c,float(i)/12.0))
 for i in range(1,13):
  var t:=float(i)/12.0
  outline.append(c*(1-t)*(1-t)+Vector2(-0.45,-0.3)*2*(1-t)*t+a*t*t)

func clear() -> void:
 returning=false
 clock=0.0
 fade_left=0.0
 frog_crossing=false
 hide()

func sync(actor: Dictionary, combat: Dictionary, kind: String) -> void:
 if combat.get("region","")!="fenshui" or combat.get("fs01_trial",false) or actor.hp<=0 or float(combat.get("hp",0))<=0:
  clear()
  return
 var active:=false
 var tail:=false
 if kind in ["silverfish","thunder_eel"]:
  var phase: String=actor.get("fish_phase" if kind=="silverfish" else "eel_phase","")
  active=phase=="returning"
  tail=phase=="forming"
 elif kind=="wind_frog" and actor.get("mode","")=="return":
  var phase: String=actor.get("frog_phase","")
  if phase=="airborne":
   if not Boss.water(Vector2(actor.position[0],actor.position[1]),Boss.BODY): frog_crossing=true
   active=frog_crossing
  tail=phase=="landing" and frog_crossing
 if active:
  if not returning: clock=0.0
  returning=true
  fade_left=FADE_TIME
  show()
 elif tail and (returning or fade_left>0.0):
  returning=false
 else: clear()

func advance(delta: float, sprite: Sprite2D, width: float, kind: String, facing: int) -> void:
 if not get_parent().is_visible_in_tree():
  clear()
  return
 if not returning and fade_left<=0.0: return
 clock+=delta
 if not returning:
  fade_left=maxf(0.0,fade_left-delta)
  if fade_left<=0.0:
   clear()
   return
 size_ratio=width/float({"silverfish":92,"thunder_eel":106,"wind_frog":108}[kind])
 var rect:=sprite.get_rect()
 position=sprite.position+(rect.position+rect.size*Vector2(0.3 if facing in [1,3] else 0.7,0.24))*sprite.scale-Vector2(0,10)*size_ratio
 queue_redraw()

func _draw() -> void:
 var fade:=1.0 if returning else fade_left/FADE_TIME
 for j in 4:
  var age:=fposmod(clock+float(j)*PERIOD/4.0,PERIOD)/PERIOD
  if age>0.72: continue
  var progress:=age/0.72
  var alpha:=sin(progress*PI)*fade
  var point:=Vector2(sin(float(j)*2)*12+(1 if j%2 else -1)*progress*24,-progress*33)*size_ratio
  var radius:=5.7*size_ratio
  draw_set_transform(point,0,Vector2.ONE*radius)
  draw_colored_polygon(outline,Color(0.475,0.78,0.875,alpha))
  draw_polyline(outline,Color(0.224,0.49,0.6,alpha),1.1*size_ratio/radius,true)
  draw_line(Vector2(-0.22,-0.1),Vector2(-0.35,0.45),Color(0.906,0.984,1,alpha),1.3*size_ratio/radius,true)
 draw_set_transform(Vector2.ZERO)
