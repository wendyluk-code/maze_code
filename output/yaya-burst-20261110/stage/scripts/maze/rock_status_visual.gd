extends Node2D
## 只读已提交状态，使用战斗elapsed绘制；不拥有伤害、控制或独立计时。
var player_stunned:=false
var beast_stunned:=false
var exhausted:=false
var slow_count:=0
var clock:=0.0
var hero:=Vector2.ZERO
var beast:=Vector2.ZERO
var hero_head:=Vector2.ZERO
var beast_head:=Vector2.ZERO
var fade:=1.0
var trails: Array=[]
var previous:=Vector2.INF
var last_trace:=-1.0
var bounds: Dictionary={}
var airborne:=false
var slow_left:=0.0
var slow_factor:=1.0
var slow_started:=-100.0
var slow_ended:=-100.0
var slow_release:=0.0
var slow_badge:=""
var slow_height:=50.0
func visible_rect(sprite: Sprite2D) -> Rect2:
 var key:=sprite.texture.get_instance_id()
 if not bounds.has(key): bounds[key]=Rect2(sprite.texture.get_image().get_used_rect())
 var used: Rect2=bounds[key]
 return sprite.get_global_transform()*Rect2(sprite.get_rect().position+used.position,used.size)

func sync(flow: Node, run: Dictionary) -> void:
 var c: Dictionary=run.get("combat",{})
 player_stunned=false
 beast_stunned=false
 exhausted=false
 slow_count=0
 airborne=float(c.get("rock_launch_left",0.0))>0.0
 if c.get("region","")!="salt_pool" or float(c.get("hp",0))<=0:
  trails.clear()
  previous=Vector2.INF
  slow_left=0.0
  slow_release=0.0
  slow_badge=""
  slow_started=-100.0
  slow_ended=-100.0
  hide()
  return
 show()
 var old_clock:=clock
 clock=float(c.get("elapsed",0))
 hero=to_local(flow.maze.player.global_position)
 var pose: Sprite2D=flow.player_hurt_visual.pose if is_instance_valid(flow.player_hurt_visual) and flow.player_hurt_visual.pose.is_visible_in_tree() else flow.maze.player.body
 var hero_rect: Rect2=visible_rect(pose)
 hero_head=to_local(Vector2(hero_rect.get_center().x,hero_rect.position.y+10.0))
 slow_height=clampf(hero.y-hero_head.y+8.0,35.0,65.0)
 player_stunned=float(c.get("rock_stun_left",0))>0
 var remaining:=float(c.get("rock_slow_left",0))
 # 只用真实战斗时钟派生演出，暂停不播放，重置/瞬移不留下上次碎片。
 if clock<old_clock or (previous.is_finite() and hero.distance_to(previous)>160.0):
  slow_left=0.0
  slow_started=-100.0
  slow_ended=-100.0
  trails.clear()
 if remaining>0:
  var factor:=float(c.get("rock_slow_factor",1))
  if slow_left<=0.0 or remaining>slow_left+0.1: slow_started=clock
  slow_factor=factor
  slow_count=16 if factor<=0.05 else (10 if factor<=0.15 else 6)
  fade=minf(1.0,remaining/0.3)
  if previous.is_finite() and hero.distance_to(previous)>0.15 and clock-last_trace>0.09:
   trails.append({"point":hero,"born":clock,"angle":previous.angle_to_point(hero)})
   last_trace=clock
 else:
  if slow_left>0.0: slow_ended=clock
  trails.clear()
 slow_left=remaining
 slow_release=clampf(1.0-(clock-slow_ended)/0.4,0.0,1.0) if remaining<=0.0 else 0.0
 slow_badge=""
 previous=hero
 trails=trails.filter(func(t): return clock>=float(t.born) and clock-float(t.born)<0.7)
 var id: String=preload("res://data/maze/salt_boss.gd").ID
 if flow.monsters.has(id) and c.get("actors",{}).has(id):
  var node: Node2D=flow.monsters[id]
  var actor: Dictionary=c.actors[id]
  beast=to_local(node.global_position)
  var rect: Rect2=node._rock_visible_rect(node.body)
  beast_head=to_local(Vector2(rect.get_center().x,rect.position.y-9.0))
  beast_head=_above_label(beast_head,24.0,node.label)
  if is_instance_valid(node.combat_label_avoid):
   hero_head=_below_label(hero_head,16.0,node.combat_label_avoid)
  beast_stunned=float(actor.hp)>0 and actor.rock_phase=="stunned"
  exhausted=float(actor.hp)>0 and actor.rock_phase=="rest"
 queue_redraw()

func _below_label(origin: Vector2, radius: float, label: Control) -> Vector2:
 if not label.is_visible_in_tree(): return origin
 var box: Rect2=get_global_transform().affine_inverse()*label.get_global_rect()
 if origin.x+radius+5.0>box.position.x and origin.x-radius-5.0<box.end.x:
  origin.y=maxf(origin.y,box.end.y+radius*0.24+7.0)
 return origin

func _above_label(origin: Vector2, radius: float, label: Control) -> Vector2:
 if not label.is_visible_in_tree(): return origin
 var box: Rect2=get_global_transform().affine_inverse()*label.get_global_rect()
 if origin.x+radius+5.0>box.position.x and origin.x-radius-5.0<box.end.x:
  origin.y=minf(origin.y,box.position.y-radius*0.24-9.0)
 return origin

func _draw() -> void:
 if airborne:
  var shadow:=PackedVector2Array()
  for i in 24: shadow.append(hero+Vector2(cos(TAU*i/24.0)*10.0,sin(TAU*i/24.0)*3.3))
  draw_colored_polygon(shadow,Color(0.24,0.22,0.20,0.25))
 if slow_count>0:
  _slow_binding()
  for trail in trails:
   var alpha: float=(1.0-(clock-float(trail.born))/0.7)*0.45
   var p: Vector2=trail.point
   var d:=Vector2.RIGHT.rotated(float(trail.angle))
   draw_line(p-d*7.0,p+d*2.0,Color(0.64,0.55,0.40,alpha),3.0,true)
   draw_line(p-d*5.0+Vector2(0,3),p+Vector2(0,3),Color(0.91,0.86,0.72,alpha),1.2,true)
 if slow_release>0.0:
  var age:=1.0-slow_release
  for i in 8:
   var angle:=TAU*float(i)/8.0
   var point:=hero+Vector2(cos(angle)*(14.0+age*12.0),-slow_height*float(i%4)/4.0+age*12.0)
   draw_line(point,point+Vector2(sin(angle)*2.0,4.0),Color(0.77,0.66,0.39,slow_release*0.65),1.4,true)
 if player_stunned: _stars(hero_head,16.0)
 if beast_stunned or exhausted: _stars(beast_head,24.0)
 if exhausted:
  for i in 3:
   var t:=fmod(clock*1.5+float(i)/3.0,1.0)
   var point:=beast+Vector2(18.0+t*16.0,-35.0-t*15.0)
   draw_arc(point,3.0+t*4.0,-PI*0.7,PI*0.3,12,Color(0.92,0.85,0.66,(1.0-t)*0.7),1.3,true)

func _slow_binding() -> void:
 var entry:=clampf((clock-slow_started)/0.28,0.0,1.0)
 var count:=8 if slow_factor<=0.05 else (6 if slow_factor<=0.15 else 4)
 # 参考虚弱的下坠压制感；仅显示减速，不添加减伤或修改人物素材。
 for i in count:
  var t:=fmod(clock*0.72+float(i)/float(count),1.0)
  var alpha:=sin(t*PI)*fade*(0.7+0.3*entry)
  var side: float=-1.0 if i%2==0 else 1.0
  var center:=hero+Vector2(side*(13.0+sin(t*PI)*4.0),-slow_height+t*(slow_height+4.0))
  var stroke:=PackedVector2Array()
  for j in 7:
   var along:=float(j)/6.0
   stroke.append(center+Vector2(side*sin(along*PI)*3.0,-10.0+along*12.0))
  draw_polyline(stroke,Color(0.36,0.29,0.15,0.19*alpha),5.0,true)
  draw_polyline(stroke,Color(0.76,0.60,0.28,0.82*alpha),2.0,true)
  draw_polyline(stroke,Color(0.97,0.85,0.53,0.55*alpha),0.8,true)
 # 头顶双下箭与旋转眩晕星环区分，保留脸部和血条。
 var icon:=hero+Vector2(0,-slow_height-5.0)
 for row in 2:
  var chevron:=PackedVector2Array([icon+Vector2(-4,-3.0+float(row)*4.0),icon+Vector2(0,float(row)*4.0),icon+Vector2(4,-3.0+float(row)*4.0)])
  draw_polyline(chevron,Color(0.39,0.30,0.15,0.75*fade),3.2,true)
  draw_polyline(chevron,Color(0.94,0.79,0.40,0.95*fade),1.6,true)

func _stars(origin: Vector2, radius: float) -> void:
 var ellipse:=PackedVector2Array()
 for i in 33:
  var a:=TAU*i/32.0
  ellipse.append(origin+Vector2(cos(a)*radius,sin(a)*radius*0.24))
 draw_polyline(ellipse,Color(0.74,0.56,0.28,0.55),1.1,true)
 for i in 3:
  var a:=clock*3.2+TAU*i/3.0
  var center:=origin+Vector2(cos(a)*radius,sin(a)*radius*0.24)
  var points:=PackedVector2Array()
  for k in 10:
   var r:=4.1 if k%2==0 else 1.8
   points.append(center+Vector2.RIGHT.rotated(-PI/2.0+TAU*k/10.0)*r)
  draw_colored_polygon(points,Color("f1cc70"))
  points.append(points[0])
  draw_polyline(points,Color("80603b"),0.8,true)
