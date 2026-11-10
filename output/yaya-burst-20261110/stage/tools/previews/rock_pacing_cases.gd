extends RefCounted
const Salt=preload("res://data/maze/salt_pool_roads.gd")
const Boss=preload("res://data/maze/salt_boss.gd")
static func find(kind: String) -> Dictionary:
 for y in range(160,800,10):
  for x in range(160,1400,10):
   var hero:=Vector2(x,y)
   var beast:=hero-Vector2(80,0)
   if not Boss.line(beast,hero+Vector2(10,0),8.0): continue
   var end:=hero+Vector2(40,0)
   if kind=="open":
    if not Boss.line(hero,end+Vector2(8,0),8.0): continue
   elif kind=="edge":
    if Geometry2D.is_point_in_polygon(end,Salt.OUTLINE): continue
   else:
    if not Geometry2D.is_point_in_polygon(end,Salt.OUTLINE) or preload("res://scripts/maze/rock_charge_terrain.gd").allowed(end): continue
   return {"hero":hero,"beast":beast}
 return {}
