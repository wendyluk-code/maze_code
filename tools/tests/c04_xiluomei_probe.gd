extends SceneTree
const Tide=preload("res://scripts/maze/xiluomei_net.gd")
func _initialize() -> void:
	for origin in [Vector2(720,370),Vector2(933,269)]:
		var direction:=Vector2(0.884,-0.467).normalized()
		for distance in [230.0,240.0,250.0,260.0,270.0]:
			var p: Vector2=origin+direction*distance
			print("PROBE ",p," road=",Tide.Roads.is_walkable(p)," props=",Tide.Catalog.clear_of_props(p))
	for road in Tide.Roads.roads():
		for i in range(road.points.size()-1):
			var start: Vector2=road.points[i]
			var finish: Vector2=road.points[i+1]
			if start.distance_to(finish)<55: continue
			var clear:=true
			for step in 101:
				var p:=start.lerp(finish,float(step)/100)
				if not Tide.Roads.is_walkable(p) or not Tide.Catalog.clear_of_props(p): clear=false; break
			if clear: print("CLEAR ",start," -> ",finish)
	quit()

