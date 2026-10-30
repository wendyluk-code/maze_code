extends Node2D
## 世界预警复用既有水纹色系；不锁输入，时间仅取已提交战斗快照。
const Rules = preload("res://scripts/maze/fenshui_borrow_lightning.gd")
var maze: Node
var snapshot: Dictionary = {}
var _center := Vector2.INF
var _tiles: Array[PackedVector2Array] = []
var _rings: Array[PackedVector2Array] = []

func _process(_delta: float) -> void:
 snapshot = preload("res://scripts/maze/capture_run.gd").snapshot(get_node("/root/SaveManager"))
 queue_redraw()

func _water_shape(center: Vector2) -> void:
 if center==_center: return
 _center=center
 _tiles.clear()
 _rings.clear()
 # 每条射线只扫描一次，各同心圈复用首个岸线前的水域长度。
 # 2像素采样保持伤害判断的空间精度，避免每个顶点重扫整条路径。
 var reach: Array[float]=[]
 for i in 64:
  var direction:=Vector2.RIGHT.rotated(TAU*i/64.0)
  var distance:=0.0
  if Rules.wet(center):
   for step in range(1,64):
    var radius:=minf(step*2.0,Rules.ELECTRIC_RADIUS)
    if not Rules.wet(center+direction*radius): break
    distance=radius
  reach.append(distance)
 for ring in range(1,11):
  var radius := Rules.ELECTRIC_RADIUS*ring/10.0
  var previous := radius-Rules.ELECTRIC_RADIUS/10.0
  for i in 64:
   var d1 := Vector2.RIGHT.rotated(TAU*i/64.0)
   var d2 := Vector2.RIGHT.rotated(TAU*(i+1)/64.0)
   var points := PackedVector2Array([center+d1*previous,center+d1*radius,center+d2*radius,center+d2*previous])
   var allowed:=radius<=minf(reach[i],reach[(i+1)%64])
   if allowed:
    _tiles.append(points)
    if ring in [3,6,10]: _rings.append(PackedVector2Array([points[1],points[2]]))

func _draw() -> void:
 if snapshot.is_empty() or not snapshot.get("active",false): return
 var c: Dictionary=snapshot.combat
 if not c.get("fs01_trial",false) or c.region!="fenshui": return
 for id in Rules.IDS:
  var actor: Dictionary=c.actors[id]
  if actor.hp<=0 or snapshot.monsters[id].status!="alive": continue
  var phase: String=actor.get("fs_phase","")
  var pos := Rules.vec(actor.position)
  if id.contains("silverfish") and phase=="warning":
   var aim := Rules.vec(actor.fs_aim)
   var finish := Rules.rush_end(pos,aim)
   var side := aim.orthogonal()*10.0
   draw_colored_polygon(PackedVector2Array([pos+side,finish+side,finish-side,pos-side]),Color(0.73,0.94,0.96,0.16))
   draw_line(pos,finish,Color(0.90,0.99,0.96,0.85),2.0,true)
   draw_line(finish,finish-aim*13+side,Color(0.90,0.99,0.96,0.9),2.0,true)
   draw_line(finish,finish-aim*13-side,Color(0.90,0.99,0.96,0.9),2.0,true)
  if id.contains("thunder_eel") and phase in ["warning","discharge"]:
   _water_shape(pos)
   var progress := 1.0-float(actor.fs_left)/Rules.WARNING_EEL if phase=="warning" else 1.0
   var color := Color(1.0,0.83,0.39,0.11+progress*0.13) if phase=="warning" else Color(0.89,0.95,0.65,0.45)
   for tile in _tiles: draw_colored_polygon(tile,color)
   for line in _rings: draw_polyline(line,Color(1.0,0.91,0.56,0.40+progress*0.5),1.5,true)
   if phase=="discharge":
    for i in 10:
     var direction := Vector2.RIGHT.rotated(i*TAU/10.0)
     var points := PackedVector2Array([pos])
     for j in range(1,7):
      var p := pos+direction*j*18+direction.orthogonal()*sin(j*2.5+i)*5
      if not Rules.conducts(pos,p): break
      points.append(p)
     if points.size()>1: draw_polyline(points,Color(1,0.98,0.76,0.95),2.0,true)
