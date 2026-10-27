extends "res://tools/tests/day1_customers.gd"
func run() -> void:
	sm = get_node("/root/SaveManager")
	seed_completed()
	var roads = preload("res://data/maze/entry_roads.gd")
	check(roads.is_walkable(roads.SPAWN), "spawn walkable")
	var scene = load("res://scenes/maze_entry.tscn").instantiate()
	get_tree().root.add_child(scene)
	await get_tree().create_timer(1.0).timeout
	check(scene.player.position.distance_to(roads.SPAWN) < 1.0, "actual spawn")
	check(roads.move_on_road(roads.SPAWN, Vector2(-10, 5)) != roads.SPAWN, "can leave spawn")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://output/order_card_compare/maze_spawn.png")
	print("RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(failures)
