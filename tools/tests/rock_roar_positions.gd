extends SceneTree
const Rock=preload("res://scripts/maze/rockmane_combat.gd")
const Boss=preload("res://data/maze/salt_boss.gd")
func find_case(center: Vector2) -> Dictionary:
 for origin_distance in [80.0,110.0,140.0,180.0]:
  for oi in 32:
   var origin: Vector2=center+Vector2.RIGHT.rotated(TAU*oi/32.0)*origin_distance
   if not Boss.allowed(origin): continue
   for target_distance in [30.0,45.0,65.0,85.0]:
    for ti in 32:
     var target: Vector2=center+Vector2.RIGHT.rotated(TAU*ti/32.0)*target_distance
     if not Boss.Roads.is_walkable(target) or origin.distance_to(target)>250 or Rock.roar_clear(origin,target): continue
     for move_distance in [30.0,45.0,60.0]:
      for mi in 32:
       var start: Vector2=target+Vector2.RIGHT.rotated(TAU*mi/32.0)*move_distance
       if not Boss.Roads.is_walkable(start) or not Boss.line(start,target,4.0) or origin.distance_to(start)>250 or origin.distance_to(start)<60 or not Rock.roar_clear(origin,start): continue
       if origin.direction_to(start).dot(origin.direction_to(target))<cos(deg_to_rad(30)): continue
       return {"origin":[origin.x,origin.y],"start":[start.x,start.y],"target":[target.x,target.y],"distance":move_distance}
 return {}
func _initialize() -> void:
 var result:={"rock":find_case(Vector2(1086,479)),"crystal":find_case(Vector2(1160,330))}
 print(JSON.stringify(result))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="): FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit()
