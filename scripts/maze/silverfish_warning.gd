extends Node2D
## 正式鱼的锁向预警；绘制位置只读最后成功提交的战斗状态。
const Fish=preload("res://scripts/maze/silverfish_combat.gd")
const Rush=preload("res://scripts/maze/fenshui_borrow_lightning.gd")
var flow: Node

func _process(_delta: float) -> void:
 queue_redraw()

func _draw() -> void:
 var run: Dictionary=flow.display_run()
 if run.is_empty() or not run.get("active",false): return
 var c: Dictionary=run.combat
 for id in c.actors:
  if not Fish.enabled(c,id) or run.monsters[id].status!="alive": continue
  var a: Dictionary=c.actors[id]
  if a.hp<=0 or a.get("fish_phase","")!="warning": continue
  var origin:=Fish.vec(a.position)
  var aim:=Fish.vec(a.fish_aim)
  var finish:=origin
  for i in ceili(Rush.RUSH_LENGTH/2.0):
   var next:=Fish.move(run,id,finish,aim*2.0)
   if next==finish: break
   finish=next
   if Fish.dry(finish): break
  var side:=aim.orthogonal()*10
  draw_colored_polygon(PackedVector2Array([origin+side,finish+side,finish-side,origin-side]),Color(0.73,0.94,0.96,0.18))
  draw_line(origin,finish,Color(0.9,0.99,0.96,0.9),2,true)
  draw_line(finish,finish-aim*13+side,Color(0.9,0.99,0.96,0.9),2,true)
  draw_line(finish,finish-aim*13-side,Color(0.9,0.99,0.96,0.9),2,true)

