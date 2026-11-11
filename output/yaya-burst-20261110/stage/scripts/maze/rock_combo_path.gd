extends RefCounted
## 四侧进攻只选择当前侧扇区内的可达站位；路径不穿过玩家或其他身体。
const Ground=preload("res://data/maze/salt_boss.gd")
const Bodies=preload("res://scripts/maze/rock_bodies.gd")
const CELL=12.0
static func clear(run: Dictionary,a: Vector2,b: Vector2) -> bool:
 if Ground.move(a,b-a).distance_to(b)>0.01: return false
 return Bodies.step(run,Ground.ID,a,b)
static func plan(run: Dictionary,origin: Vector2,hero: Vector2,angle: float) -> Array:
 var grid:=AStarGrid2D.new()
 var low:=Vector2i(((origin.min(hero)-Vector2(180,180))/CELL).floor())
 var high:=Vector2i(((origin.max(hero)+Vector2(180,180))/CELL).ceil())
 grid.region=Rect2i(low,high-low+Vector2i.ONE)
 grid.cell_size=Vector2.ONE*CELL
 grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 grid.update()
 for y in range(low.y,high.y+1):
  for x in range(low.x,high.x+1):
   var p:=Vector2(x,y)*CELL
   grid.set_point_solid(Vector2i(x,y),not Ground.allowed(p) or not Bodies.step(run,Ground.ID,p,p))
 var start:=Vector2i(-9999,-9999)
 var nearest:=INF
 var cell:=Vector2i((origin/CELL).round())
 for y in range(cell.y-6,cell.y+7):
  for x in range(cell.x-6,cell.x+7):
   var id:=Vector2i(x,y)
   if not grid.region.has_point(id) or grid.is_point_solid(id): continue
   var p:=Vector2(id)*CELL
   if origin.distance_squared_to(p)<nearest and clear(run,origin,p):
    start=id
    nearest=origin.distance_squared_to(p)
 if start.x==-9999: return []
 var best: Array=[]
 var best_length:=INF
 for radius in [90.0,108.0,78.0,126.0]:
  for offset in [0.0,-0.22,0.22,-0.4,0.4]:
   var target: Vector2=hero+Vector2.RIGHT.rotated(angle+float(offset))*float(radius)
   var end:=Vector2i((target/CELL).round())
   if not grid.region.has_point(end) or grid.is_point_solid(end): continue
   var point:=Vector2(end)*CELL
   if absf(wrapf(hero.angle_to_point(point)-angle,-PI,PI))>0.45: continue
   if point.distance_to(hero)<65.0 or Ground.move(point,point.direction_to(hero)*160.0).distance_to(point)<40.0: continue
   var raw:=grid.get_point_path(start,end)
   if raw.is_empty(): continue
   var path: Array=[]
   var previous:=origin
   var length:=0.0
   var valid:=true
   for p in raw:
    if not clear(run,previous,p):
     valid=false
     break
    length+=previous.distance_to(p)
    path.append([p.x,p.y])
    previous=p
   if valid and length<best_length:
    best=path
    best_length=length
 return best
