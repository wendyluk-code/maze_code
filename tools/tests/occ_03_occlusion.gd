extends Node

## OCC-03 吧台/收银台/仓库遮挡返修验收。
## expected 值是独立人工夹具，不从生产 occlusion_polygon 推导。

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const BODY_VIS_H := 130.0
const TEX_FRONT := preload("res://assets/characters/hero/hero_front.png")
const TEX_BACK := preload("res://assets/characters/hero/hero_back.png")
const TEX_SIDE := preload("res://assets/characters/hero/hero_side.png")
const TARGETS := {
	"BarCounter": {
		"samples": [
			{"id": "behind", "offset": Vector2(250, 8), "expected": true},
			{"id": "front_below", "offset": Vector2(0, 90), "expected": false},
			{"id": "left_below", "offset": Vector2(-205, 95), "expected": false},
			{"id": "right_below", "offset": Vector2(150, 90), "expected": false},
			{"id": "boundary_cross", "offset": Vector2(0, 60), "expected": false},
			{"id": "legacy_false", "offset": Vector2(350, 100), "expected": false},
		],
		"path": [Vector2(250, 8), Vector2(0, 90)],
	},
	"Register": {
		"samples": [
			{"id": "behind", "offset": Vector2(-50, 110), "expected": true},
			{"id": "front_below", "offset": Vector2(0, 100), "expected": false},
			{"id": "left_below", "offset": Vector2(-205, 140), "expected": false},
			{"id": "right_below", "offset": Vector2(125, 30), "expected": false},
			{"id": "boundary_cross", "offset": Vector2(30, 55), "expected": false},
			{"id": "legacy_false", "offset": Vector2(-50, 135), "expected": false},
		],
		"path": [Vector2(-50, 110), Vector2(0, 100)],
	},
	"Store": {
		"samples": [
			{"id": "behind", "offset": Vector2(-80, 40), "expected": true},
			{"id": "front_below", "offset": Vector2(100, 320), "expected": false},
			{"id": "left_below", "offset": Vector2(-100, 95), "expected": false},
			{"id": "right_below", "offset": Vector2(140, 120), "expected": false},
			{"id": "boundary_cross", "offset": Vector2(100, 120), "expected": false},
			{"id": "legacy_false", "offset": Vector2(-75, 130), "expected": false},
		],
		"path": [Vector2(-80, 40), Vector2(150, 90)],
	},
}

var output_dir := ""
var report := {"ticket": "OCC-03", "project_id": "be00658b-6081-4191-8060-f498f2bd6819", "samples": [], "paths": [], "failures": 0}

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	output_dir = argument("--output-dir=")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://occ03")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var restaurant := SCENE.instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	var player := restaurant.get_node("Player") as CharacterBody2D
	player.spawn_ready = true
	var camera := restaurant.get_node("Camera") as Camera2D
	camera.set_process(false)
	camera.set_physics_process(false)
	restaurant.get_node("UIOverlay").visible = false
	var foreground := restaurant.get_node("PropForeground")
	var zone := restaurant.get_node("WalkZone") as Node2D
	await get_tree().process_frame
	await get_tree().process_frame
	for target_name in TARGETS.keys():
		var target := restaurant.get_node("InteractPoints").get_node(target_name) as Node2D
		for fixture in TARGETS[target_name]["samples"]:
			await capture_sample(target, fixture, player, camera, foreground, zone)
		await capture_path(target, TARGETS[target_name]["path"], player, camera, foreground, zone)
	report["failures"] = count_failures()
	var report_file := FileAccess.open(output_dir.path_join("OCC-03-occlusion.json"), FileAccess.WRITE)
	if report_file:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	get_tree().quit(0 if int(report["failures"]) == 0 else 1)

func capture_sample(target: Node2D, fixture: Dictionary, player: CharacterBody2D,
		camera: Camera2D, foreground: Node, zone: Node2D) -> void:
	var point := legal_point(target, fixture["offset"], player.collision_radius_world(), zone)
	var expected: bool = fixture["expected"]
	var actual := false
	var rendered := false
	var image_path := ""
	if not point.is_empty():
		player.global_position = point["world"]
		player.last_valid = point["world"]
		camera.global_position = point["world"]
		await get_tree().process_frame
		await get_tree().process_frame
		actual = bool(foreground.is_target_occluding(target))
		var overlay := EvidenceOverlay.new()
		overlay.target = target
		overlay.player = player
		overlay.sample_id = fixture["id"]
		overlay.expected = expected
		overlay.actual = actual
		restaurant_add_overlay(overlay)
		await get_tree().process_frame
		var image = viewport_image()
		if image != null:
			image_path = output_dir.path_join("OCC-03-%s-%s.png" % [target.name, fixture["id"]])
			var err: Error = image.save_png(image_path)
			rendered = err == OK
		overlay.queue_free()
	var passed := not point.is_empty() and actual == expected
	report["samples"].append({
		"target": target.display_name, "node": target.name, "sample": fixture["id"],
		"offset": [fixture["offset"].x, fixture["offset"].y],
		"point": [] if point.is_empty() else [point["world"].x, point["world"].y],
		"local_foot": [] if point.is_empty() else [point["local"].x, point["local"].y],
		"expected_occluding": expected, "actual_occluding": actual,
		"inside_occlusion_polygon": false if point.is_empty() else point["inside_occlusion"],
		"front_distance": -1.0 if point.is_empty() else point["front_distance"],
		"rendered": rendered, "screenshot": image_path, "passed": passed,
	})
	if not passed:
		report["failures"] += 1

func capture_path(target: Node2D, path: Array, player: CharacterBody2D,
		camera: Camera2D, foreground: Node, zone: Node2D) -> void:
	var start: Vector2 = target.to_global(path[0])
	var finish: Vector2 = target.to_global(path[1])
	var states: Array = []
	for frame in range(25):
		var t := float(frame) / 24.0
		var world := start.lerp(finish, t)
		player.global_position = world
		player.last_valid = world
		camera.global_position = world
		await get_tree().process_frame
		states.append(bool(foreground.is_target_occluding(target)))
	var switches := 0
	for i in range(1, states.size()):
		if states[i] != states[i - 1]:
			switches += 1
	var passed := bool(states[0]) and not bool(states[states.size() - 1]) and switches <= 1
	report["paths"].append({
		"target": target.display_name, "node": target.name,
		"start_foot": [start.x, start.y], "end_foot": [finish.x, finish.y],
		"frames": states.size(), "states": states, "switch_count": switches,
		"expected_start": true, "expected_end": false, "passed": passed,
	})
	if not passed:
		report["failures"] += 1

func legal_point(target: Node2D, requested: Vector2, radius: float, zone: Node2D) -> Dictionary:
	var best := {}
	var best_score := INF
	for dx in range(-96, 97, 8):
		for dy in range(-96, 97, 8):
			var local := requested + Vector2(dx, dy)
			var world: Vector2 = target.to_global(local)
			if not zone.is_circle_inside(world, radius):
				continue
			var score := Vector2(dx, dy).length()
			if score >= best_score:
				continue
			var poly: PackedVector2Array = target.world_occlusion_polygon()
			var inside := Geometry2D.is_point_in_polygon(world, poly)
			var front_distance := distance_to_polygon(world, poly)
			best_score = score
			best = {"local": local, "world": world, "inside_occlusion": inside,
				"front_distance": front_distance}
	return best

func distance_to_polygon(point: Vector2, poly: PackedVector2Array) -> float:
	if poly.size() < 2:
		return INF
	var best := INF
	for i in poly.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, point.distance_to(closest))
	return best

func restaurant_add_overlay(overlay: Node2D) -> void:
	get_tree().current_scene.add_child(overlay)

func viewport_image():
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		return null
	var texture := get_viewport().get_texture()
	return texture.get_image() if texture != null and texture.get_rid().is_valid() else null

func count_failures() -> int:
	var failures := 0
	for sample in report["samples"]:
		if not sample["passed"]:
			failures += 1
	for path in report["paths"]:
		if not path["passed"]:
			failures += 1
	return failures

func argument(prefix: String) -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

class EvidenceOverlay extends Node2D:
	var target: Node2D
	var player: CharacterBody2D
	var sample_id := ""
	var expected := false
	var actual := false

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_circle(player.global_position, 6.0, Color("ffe56d"))
		var poly: PackedVector2Array = target.world_occlusion_polygon()
		if poly.size() >= 2:
			var closed := PackedVector2Array(poly)
			closed.append(poly[0])
			draw_polyline(closed, Color("ffe56d"), 3.0)
		draw_rect(Rect2(18, 18, 820, 76), Color(0.04, 0.07, 0.09, 0.88), true)
		draw_string(font, Vector2(32, 48), "OCC-03 %s/%s" % [target.display_name, sample_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		draw_string(font, Vector2(32, 76), "脚底=(%.1f, %.1f) 期望=%s 实际=%s" % [player.global_position.x, player.global_position.y, "遮挡" if expected else "不遮挡", "遮挡" if actual else "不遮挡"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe56d"))
