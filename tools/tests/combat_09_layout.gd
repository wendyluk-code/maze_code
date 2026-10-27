extends Node
const Catalog = preload("res://data/maze/capture_catalog.gd")
const Roads = preload("res://data/maze/entry_roads.gd")
const Combat = preload("res://scripts/maze/combat_simulation.gd")

func _ready() -> void:
	var results: Array = []
	var failures := 0
	var layouts := {}
	var combos := {}
	var geometry_contract: bool = Roads.roads()[0].points.has(Vector2(860,295)) and Vector2(860,295).distance_to(Roads.SPAWN)>Combat.RANGE
	for stats in Combat.STATS.values():
		geometry_contract=geometry_contract and maxf(stats.trigger,Combat.RANGE)+Roads.roads()[0].width<=Catalog.FIRST_ENCOUNTER_CLEARANCE
	if not geometry_contract: failures+=1
	# 包括入口后退方向、道路全宽和拐角圆帽；独立从真实道路采样，不调用生成器筛选函数。
	var probes: Array[Vector2] = []
	for x in range(840,1142,4):
		for y in range(102,320,4):
			var p := Vector2(x,y)
			if Roads.is_walkable(p) and (p.distance_to(Geometry2D.get_closest_point_to_segment(p,Vector2(933,269),Vector2(860,295)))<=24.0 or x>=933):
				probes.append(p)
	for seed_value in range(1,301):
		var layout := Catalog.random_layout(seed_value)
		var counts := {"slime":0,"snail":0,"beetle":0,"lizard":0}
		var legal := true
		var separated := true
		var protected := true
		var run := {"monsters":{},"combat":Combat.create(3,36,Roads.SPAWN,Catalog.all(Catalog.BALANCE_VERSION,layout)),"catalog_version":Catalog.BALANCE_VERSION,"layout":layout}
		for row in Catalog.all(Catalog.BALANCE_VERSION,layout): run.monsters[row.id]={"status":"alive"}
		for i in layout.size():
			var item: Dictionary = layout[i]
			counts[item.kind]+=1
			var p := Combat.vec(item.position)
			legal = legal and Roads.is_walkable(p)
			for j in i: separated = separated and p.distance_to(Combat.vec(layout[j].position))>=80.0
			if i>0:
				for probe in probes:
					if p.distance_to(probe)<=maxf(Combat.STATS[item.kind].trigger,Combat.RANGE): protected=false
		# 真实模拟沿中心/左右边缘逐步推进，记录第一个激活集合与第一个选中目标。
		var paths: Array = []
		for offset in [-18.0,0.0,18.0]:
			var sample: Dictionary=run.duplicate(true)
			var first: Array=[]
			var target := ""
			var hero := Roads.SPAWN
			for goal in [Vector2(1061,188),Vector2(995,225),Vector2(933,269),Vector2(860,295)]:
				var origin := hero
				var normal: Vector2 = origin.direction_to(goal).orthogonal()*offset
				for step in range(1,61):
					hero=origin.lerp(goal,float(step)/60.0)+normal
					if not Roads.is_walkable(hero): hero=origin.lerp(goal,float(step)/60.0)
					if target.is_empty(): target=Combat.select_target(sample,hero)
					Combat.advance(sample,hero,0.01)
					if first.is_empty():
						for id in sample.combat.actors:
							if sample.combat.actors[id].mode!="idle": first.append(id)
					if not first.is_empty(): break
				if not first.is_empty(): break
			paths.append({"offset":offset,"first":first,"target":target,"hero":str(hero)})
			protected=protected and first==["slime_1"] and target=="slime_1"
		var combo := str(counts)
		combos[combo]=true
		layouts[JSON.stringify(layout)]=true
		var valid: bool=layout.size()==10 and counts.slime in [2,3] and counts.snail in [3,4] and counts.beetle in [3,4] and counts.lizard==1 and layout[9].position==[270.0,720.0] and layout[0].kind=="slime" and layout[0].position==[860.0,295.0] and legal and separated and protected and layout==Catalog.random_layout(seed_value)
		if not valid: failures+=1
		results.append({"seed":seed_value,"counts":counts,"legal":legal,"separated":separated,"protected":protected,"paths":paths,"valid":valid})
	if layouts.size()<290 or combos.size()!=3: failures+=1
	var file: FileAccess
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): file=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":302,"failures":failures,"geometry_contract":geometry_contract,"layouts":layouts.size(),"combos":combos,"results":results},"\t"))
	get_tree().quit(1 if failures else 0)
