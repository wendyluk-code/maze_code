extends "res://tools/tests/maze_capture.gd"
const S = preload("res://data/maze/salt_pool_encounters.gd")
func _run() -> void:
	var candidates := []
	for y in range(615,671,5):
		for x in range(950,1041,5):
			if S.ground(Vector2(x,y)): candidates.append([x,y])
	var f := FileAccess.open(_arg("--report="),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":1,"failures":0,"candidates":candidates}))
	get_tree().quit()
