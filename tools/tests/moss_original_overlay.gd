extends SceneTree
## 原图道路可视核对产物；不修改生产底图。
func _initialize() -> void:
	var terrain=load("res://data/maze/moss_pool_roads.gd")
	var image=Image.load_from_file("res://assets/maps/moss_pool.png")
	for road in terrain.roads():
		for i in range(road.points.size()-1):
			var a: Vector2=road.points[i]
			var b: Vector2=road.points[i+1]
			for y in range(maxi(0,int(minf(a.y,b.y)-road.width)),mini(image.get_height(),int(maxf(a.y,b.y)+road.width)+1)):
				for x in range(maxi(0,int(minf(a.x,b.x)-road.width)),mini(image.get_width(),int(maxf(a.x,b.x)+road.width)+1)):
					var distance=Vector2(x,y).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(x,y),a,b))
					if distance<road.width:
						var tint=Color(1,0.2,0.15,0.5) if distance>road.width-2 else Color(0.1,1,0.35,0.18)
						image.set_pixel(x,y,image.get_pixel(x,y).blend(tint))
	image.save_png("res://output/moss-original-20261029/road-overlay.png")
	quit()
