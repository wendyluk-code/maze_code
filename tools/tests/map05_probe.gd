extends "res://tools/tests/combat_02_flow.gd"
const Resources=preload("res://data/maze/region_resources.gd")
func _combat_scene() -> void:
	await _new_scene()
	maze.capture_flow.set_process(false)
	for region in ["fenshui","salt_pool"]:
		var terrain=sm.maze_terrain(region)
		var origin: Vector2=terrain.SPAWN
		var queue: Array[Vector2]=[origin]
		var visited: Dictionary={Vector2i.ZERO:true}
		var cursor:=0
		while cursor<queue.size():
			var p: Vector2=queue[cursor]
			cursor+=1
			for delta in [Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:
				var next: Vector2=p+delta
				var cell:=Vector2i((next-origin)/8.0)
				if visited.has(cell) or not terrain.is_walkable(next): continue
				if terrain.move_on_road(p,delta).distance_to(next)>0.1: continue
				visited[cell]=true
				queue.append(next)
		for row in Resources.all(region):
			var best:=Vector2.INF
			for distance in range(0,51,2):
				for angle in 32:
					var p: Vector2=row.position+Vector2.RIGHT.rotated(angle*TAU/32)*distance
					if terrain.is_walkable(p): best=p; break
				if best!=Vector2.INF: break
			print("RESOURCE_PROBE ",row.id," center=",row.position," walkable=",terrain.is_walkable(row.position)," stand=",best)
			_check(best!=Vector2.INF,"资源具有合法交互站位："+row.id)
			_check(queue.any(func(p): return p.distance_to(row.position)<=50.0),"从出生点沿真实移动规则可达："+row.id)
	await _close_scene()
