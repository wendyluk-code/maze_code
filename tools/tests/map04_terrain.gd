extends SceneTree
func _initialize() -> void:
	var roads=load("res://data/maze/salt_pool_roads.gd")
	print("candidate ",roads.is_walkable(Vector2(1010,225),22.0))
	var best: Array=[]
	for y in range(180,351,5):
		for x in range(970,1131,5):
			var p:=Vector2(x,y)
			if not roads.is_walkable(p,22.0): continue
			var longest:=0.0
			for d in 32:
				var length:=0.0
				for step in range(1,91):
					if not roads.is_walkable(p+Vector2.RIGHT.rotated(d*TAU/32)*step*2,22.0): break
					length=step*2
				longest=maxf(longest,length)
			best.append([longest,p.x,p.y,p.distance_to(Vector2(1010,225))])
	best.sort_custom(func(a,b): return a[0]>b[0] if a[0]!=b[0] else a[3]<b[3])
	print(best.slice(0,12))
	quit()
