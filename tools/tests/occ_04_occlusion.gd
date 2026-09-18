extends Node

## OCC-04 收银台/吧台截图回归遮挡验收。
## expected_occluding 是人工标注；baseline_inside 使用 OCC-03 前的旧多边形，
## 只用于证明截图回归点修复前为红、修复后为绿，不参与生产判定。

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const TARGETS := {
	"Register": {
		"samples": [
			{"id": "screenshot_regression", "local": Vector2(-40, 113), "expected": false, "facing": Vector2.DOWN, "prompt": true},
			{"id": "behind", "local": Vector2(-50, 110), "expected": true, "facing": Vector2.UP, "prompt": true},
			{"id": "front", "local": Vector2(0, 100), "expected": false, "facing": Vector2.DOWN, "prompt": true},
			{"id": "left_boundary", "local": Vector2(-205, 140), "expected": false, "facing": Vector2.RIGHT, "prompt": true},
			{"id": "right_boundary", "local": Vector2(125, 30), "expected": false, "facing": Vector2.LEFT, "prompt": true},
		],
		"path": [Vector2(-50, 118), Vector2(-40, 113)],
	},
	"BarCounter": {
		"samples": [
			{"id": "screenshot_regression", "local": Vector2(270, 30), "expected": false, "facing": Vector2.LEFT, "prompt": true},
			{"id": "behind", "local": Vector2(266, 32), "expected": true, "facing": Vector2.UP, "prompt": true},
			{"id": "front", "local": Vector2(0, 90), "expected": false, "facing": Vector2.DOWN, "prompt": true},
			{"id": "left_boundary", "local": Vector2(-205, 95), "expected": false, "facing": Vector2.RIGHT, "prompt": true},
			{"id": "right_boundary", "local": Vector2(150, 90), "expected": false, "facing": Vector2.LEFT, "prompt": true},
		],
		"path": [Vector2(266, 32), Vector2(270, 30)],
	},
}

var output_dir := ""
var report := {
	"ticket": "OCC-04",
	"project_id": "be00658b-6081-4191-8060-f498f2bd6819",
	"samples": [],
	"paths": [],
	"failures": 0,
	"baseline_red_count": 0,
}

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	output_dir = argument("--output-dir=")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://occ04")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var restaurant := SCENE.instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	var player := restaurant.get_node("Player") as CharacterBody2D
	player.spawn_ready = true
	var camera := restaurant.get_node("Camera") as Camera2D
	camera.set_process(false)
	camera.set_physics_process(false)
	var ui := restaurant.get_node("UIOverlay") as CanvasLayer
	ui.visible = true
	var guide := restaurant.get_node("UIOverlay/TutorialGuide")
	guide.visible = false
	var foreground := restaurant.get_node("PropForeground")
	var zone := restaurant.get_node("WalkZone") as Node2D
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	for target_name in TARGETS.keys():
		var target := restaurant.get_node("InteractPoints").get_node(target_name) as Node2D
		for fixture in TARGETS[target_name]["samples"]:
			await capture_sample(target, fixture, player, camera, foreground, zone)
		await capture_path(target, TARGETS[target_name]["path"], player, camera, foreground, zone)
	report["baseline_red_count"] = count_baseline_red()
	report["failures"] = count_failures()
	var report_file := FileAccess.open(output_dir.path_join("OCC-04-occlusion.json"), FileAccess.WRITE)
	if report_file:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	get_tree().quit(0 if int(report["failures"]) == 0 else 1)

func capture_sample(target: Node2D, fixture: Dictionary, player: CharacterBody2D,
		camera: Camera2D, foreground: Node, zone: Node2D) -> void:
	var point := legal_point(target, fixture["local"], player.collision_radius_world(), zone)
	var expected: bool = fixture["expected"]
	var actual := false
	var baseline_actual := false
	var rendered := false
	var image_path := ""
	var e_prompt_visible := false
	var nearest_name := ""
	if not point.is_empty():
		apply_player_state(player, camera, point["world"], fixture["facing"])
		await get_tree().process_frame
		await get_tree().process_frame
		actual = bool(foreground.is_target_occluding(target))
		baseline_actual = bool(point["baseline_inside"])
		var nearest: Node2D = player.nearest_interactable()
		nearest_name = "" if nearest == null else nearest.name
		e_prompt_visible = prompt_visible(target, ui_layer())
		if fixture["id"] == "screenshot_regression":
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
				image_path = output_dir.path_join("OCC-04-%s-%s.png" % [target.name, fixture["id"]])
				rendered = image.save_png(image_path) == OK
			overlay.queue_free()
	var passed := not point.is_empty() and actual == expected
	if fixture["id"] == "screenshot_regression":
		passed = passed and baseline_actual != expected and e_prompt_visible and nearest_name == target.name
	report["samples"].append({
		"target": target.display_name,
		"node": target.name,
		"sample": fixture["id"],
		"requested_local_foot": [fixture["local"].x, fixture["local"].y],
		"local_foot": [] if point.is_empty() else [point["local"].x, point["local"].y],
		"world_foot": [] if point.is_empty() else [point["world"].x, point["world"].y],
		"facing": facing_name(fixture["facing"]),
		"e_prompt_expected": fixture["prompt"],
		"e_prompt_visible": e_prompt_visible,
		"nearest_interactable": nearest_name,
		"expected_occluding": expected,
		"actual_occluding": actual,
		"baseline_actual_occluding": baseline_actual,
		"inside_occlusion_polygon": false if point.is_empty() else point["inside"],
		"baseline_inside_occlusion_polygon": false if point.is_empty() else point["baseline_inside"],
		"front_distance": -1.0 if point.is_empty() else point["front_distance"],
		"walkable": false if point.is_empty() else point["walkable"],
		"rendered": rendered,
		"screenshot": image_path,
		"passed": passed,
	})
	if not passed:
		report["failures"] += 1

func capture_path(target: Node2D, path: Array, player: CharacterBody2D,
		camera: Camera2D, foreground: Node, zone: Node2D) -> void:
	var start := legal_point(target, path[0], player.collision_radius_world(), zone)
	var finish := legal_point(target, path[1], player.collision_radius_world(), zone)
	var states: Array = []
	if start.is_empty() or finish.is_empty():
		report["paths"].append({"target": target.display_name, "node": target.name, "passed": false, "reason": "no legal endpoint"})
		report["failures"] += 1
		return
	for frame in range(25):
		var t := float(frame) / 24.0
		var world: Vector2 = start["world"].lerp(finish["world"], t)
		apply_player_state(player, camera, world, Vector2.DOWN)
		await get_tree().process_frame
		states.append(bool(foreground.is_target_occluding(target)))
	var switches := 0
	for i in range(1, states.size()):
		if states[i] != states[i - 1]:
			switches += 1
	var passed := bool(states[0]) and not bool(states[states.size() - 1]) and switches <= 1
	report["paths"].append({
		"target": target.display_name,
		"node": target.name,
		"start_foot": [start["world"].x, start["world"].y],
		"end_foot": [finish["world"].x, finish["world"].y],
		"frames": states.size(),
		"states": states,
		"switch_count": switches,
		"expected_start": true,
		"expected_end": false,
		"passed": passed,
	})
	if not passed:
		report["failures"] += 1

func apply_player_state(player: CharacterBody2D, camera: Camera2D, world: Vector2, facing: Vector2) -> void:
	player.global_position = world
	player.last_valid = world
	player.facing = facing
	if player.has_method("_apply_facing"):
		player._apply_facing()
	camera.global_position = world

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
			var baseline_poly := baseline_polygon(target.name)
			best_score = score
			best = {
				"local": local,
				"world": world,
				"inside": Geometry2D.is_point_in_polygon(world, poly),
				"baseline_inside": Geometry2D.is_point_in_polygon(local, baseline_poly),
				"front_distance": distance_to_polygon(world, poly),
				"walkable": true,
			}
	return best

func baseline_polygon(target_name: String) -> PackedVector2Array:
	if target_name == "BarCounter":
		return PackedVector2Array([Vector2(-232, -92), Vector2(305, -104), Vector2(352, -60), Vector2(352, -10), Vector2(300, 50), Vector2(-180, 96), Vector2(-230, 60)])
	return PackedVector2Array([Vector2(-188, -88), Vector2(80, -72), Vector2(98, -28), Vector2(94, 42), Vector2(70, 105), Vector2(-165, 128), Vector2(-190, 72)])

func distance_to_polygon(point: Vector2, poly: PackedVector2Array) -> float:
	if poly.size() < 2:
		return INF
	var best := INF
	for i in poly.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, point.distance_to(closest))
	return best

func prompt_visible(target: Node2D, layer: CanvasLayer) -> bool:
	for child in layer.get_children():
		if child is Control and child.has_meta("target") and child.get_meta("target") == target:
			return child.visible
	return false

func ui_layer() -> CanvasLayer:
	return get_tree().current_scene.get_node("UIOverlay") as CanvasLayer

func restaurant_add_overlay(overlay: Node2D) -> void:
	get_tree().current_scene.add_child(overlay)

func viewport_image():
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		return null
	var texture := get_viewport().get_texture()
	return texture.get_image() if texture != null and texture.get_rid().is_valid() else null

func count_baseline_red() -> int:
	var count := 0
	for sample in report["samples"]:
		if sample["sample"] == "screenshot_regression" and sample["baseline_actual_occluding"] != sample["expected_occluding"]:
			count += 1
	return count

func count_failures() -> int:
	var failures := 0
	for sample in report["samples"]:
		if not sample["passed"]:
			failures += 1
	for path in report["paths"]:
		if not path["passed"]:
			failures += 1
	if count_baseline_red() != 2:
		failures += 1
	return failures

func facing_name(facing: Vector2) -> String:
	if facing == Vector2.UP:
		return "up"
	if facing == Vector2.LEFT:
		return "left"
	if facing == Vector2.RIGHT:
		return "right"
	return "down"

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
		draw_string(font, Vector2(32, 48), "OCC-04 %s/%s" % [target.display_name, sample_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		draw_string(font, Vector2(32, 76), "脚底=(%.1f, %.1f) 期望=%s 实际=%s" % [player.global_position.x, player.global_position.y, "遮挡" if expected else "不遮挡", "遮挡" if actual else "不遮挡"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe56d"))
