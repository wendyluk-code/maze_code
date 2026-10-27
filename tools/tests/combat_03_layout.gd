extends Node
const Catalog = preload("res://data/maze/capture_catalog.gd")
const Roads = preload("res://data/maze/entry_roads.gd")
func _ready() -> void:
	var results: Array = []
	var failures := 0
	var combos := {}
	for seed_value in range(1,301):
		var layout := Catalog.random_layout(seed_value)
		var counts := {"slime":0,"snail":0,"beetle":0,"lizard":0}
		var legal := true
		var safe := true
		var separated := true
		for i in layout.size():
			var item: Dictionary = layout[i]
			counts[item.kind] += 1
			var p := Vector2(item.position[0],item.position[1])
			legal = legal and Roads.is_walkable(p)
			safe = safe and p.distance_to(Roads.SPAWN)>=260.0
			for j in i:
				var q := Vector2(layout[j].position[0],layout[j].position[1])
				separated = separated and p.distance_to(q)>=80.0
		var key := "%d,%d,%d,%d" % [counts.slime,counts.snail,counts.beetle,counts.lizard]
		combos[key] = int(combos.get(key,0))+1
		var deterministic := layout == Catalog.random_layout(seed_value)
		var valid: bool = layout.size()==10 and key in ["2,3,4,1","2,4,3,1","3,3,3,1"] and layout[9].position==[270.0,720.0] and legal and safe and separated and deterministic
		results.append({"seed":seed_value,"counts":counts,"legal":legal,"safe":safe,"separated":separated,"deterministic":deterministic,"valid":valid})
		if not valid: failures += 1
	if combos.size()!=3: failures+=1
	var report := {"checks":301,"failures":failures,"combos":combos,"results":results}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"\t"))
	print("COMBAT_03_LAYOUT ",JSON.stringify({"failures":failures,"combos":combos}))
	get_tree().quit(1 if failures else 0)
