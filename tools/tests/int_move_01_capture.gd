extends Node

## OCC-02 遮挡验收：期望标签是独立人工夹具，不从生产深度区域反推。
## 每个道具覆盖 behind/front/left/right/diagonal，并保留 OCC-01 六个旧误判点
## 作为 expected=false 回归样本。

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const BODY_VIS_H := 130.0
const MIN_OVERLAP_AREA := 250.0
const MIN_FOREGROUND_AREA := 20.0
const SEARCH_STEP := 8
const SEARCH_RADIUS := 64
const TEX_FRONT := preload("res://assets/characters/hero/hero_front.png")
const TEX_BACK := preload("res://assets/characters/hero/hero_back.png")
const TEX_SIDE := preload("res://assets/characters/hero/hero_side.png")

## offset 仅指定人工样本附近的位置；搜索只检查合法性与视觉交叠，
## 不读取 occlusion_polygon 来决定 expected。
const SAMPLE_FIXTURES := {
	"Cauldron": [
		{"id": "behind", "offset": Vector2(-110, 150), "expected": true},
		{"id": "front", "offset": Vector2(0, 190), "expected": false},
		{"id": "left", "offset": Vector2(-180, 190), "expected": false},
		{"id": "right", "offset": Vector2(185, 70), "expected": false},
		{"id": "diagonal", "offset": Vector2(-140, 180), "expected": false},
		{"id": "legacy_false", "offset": Vector2(-104, 168), "expected": false},
	],
	"FoodCart": [
		{"id": "behind", "offset": Vector2(-80, 30), "expected": true},
		{"id": "front", "offset": Vector2(0, 175), "expected": false},
		{"id": "left", "offset": Vector2(-145, 75), "expected": false},
		{"id": "right", "offset": Vector2(145, 65), "expected": false},
		{"id": "diagonal", "offset": Vector2(80, -35), "expected": false},
		{"id": "legacy_false", "offset": Vector2(-85, 75), "expected": false},
	],
	"Fridge": [
		{"id": "behind", "offset": Vector2(-75, 120), "expected": true},
		{"id": "front", "offset": Vector2(0, 220), "expected": false},
		{"id": "left", "offset": Vector2(-150, 75), "expected": false},
		{"id": "right", "offset": Vector2(150, 75), "expected": false},
		{"id": "diagonal", "offset": Vector2(-90, 130), "expected": false},
		{"id": "legacy_false", "offset": Vector2(-75, 140), "expected": false},
	],
	"BarCounter": [
		{"id": "behind", "offset": Vector2(250, 8), "expected": true},
		{"id": "front", "offset": Vector2(0, 160), "expected": false},
		{"id": "left", "offset": Vector2(-205, 95), "expected": false},
		{"id": "right", "offset": Vector2(360, 25), "expected": false},
		{"id": "diagonal", "offset": Vector2(320, 90), "expected": false},
		{"id": "legacy_false", "offset": Vector2(350, 100), "expected": false},
	],
	"Register": [
		{"id": "behind", "offset": Vector2(-50, 110), "expected": true},
		{"id": "front", "offset": Vector2(0, 145), "expected": false},
		{"id": "left", "offset": Vector2(-205, 140), "expected": false},
		{"id": "right", "offset": Vector2(125, 30), "expected": false},
		{"id": "diagonal", "offset": Vector2(-160, 100), "expected": false},
		{"id": "legacy_false", "offset": Vector2(-50, 135), "expected": false},
	],
	"Store": [
		{"id": "behind", "offset": Vector2(-45, 0), "expected": true},
		{"id": "front", "offset": Vector2(100, 320), "expected": false},
		{"id": "left", "offset": Vector2(-100, 95), "expected": false},
		{"id": "right", "offset": Vector2(100, 180), "expected": false},
		{"id": "diagonal", "offset": Vector2(-45, 120), "expected": false},
		{"id": "legacy_false", "offset": Vector2(-75, 130), "expected": false},
	],
}

var output_dir := ""

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	output_dir = argument("--output-dir=")
	if output_dir.is_empty():
		# Godot's Windows launcher may consume user arguments when a scene is
		# started by an external runner; keep a deterministic absolute fallback.
		output_dir = ProjectSettings.globalize_path("user://occ02")
	DirAccess.make_dir_recursive_absolute(output_dir)
	get_tree().root.get_node("SaveManager").data["tutorial_done"] = true
	var restaurant := SCENE.instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	var player := restaurant.get_node("Player") as CharacterBody2D
	player.spawn_ready = true
	var camera := restaurant.get_node("Camera") as Camera2D
	restaurant.get_node("UIOverlay").visible = false
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.zoom = Vector2(0.72, 0.72)
	var zone := restaurant.get_node("WalkZone") as Node2D
	var foreground := restaurant.get_node("PropForeground")
	var failures := 0
	var report := {"ticket": "OCC-02", "shots": [], "failures": 0}
	await get_tree().process_frame
	await get_tree().process_frame
	for child in restaurant.get_node("InteractPoints").get_children():
		var target := child as Node2D
		if target == null:
			continue
		var interaction_poly: PackedVector2Array = target.world_interaction_polygon()
		var foreground_poly: PackedVector2Array = target.world_foreground_polygon()
		for fixture in SAMPLE_FIXTURES.get(target.name, []):
			var pose := find_sample(target, fixture, player.collision_radius_world(), zone,
				interaction_poly, foreground_poly)
			if pose.is_empty():
				failures += 1
				report["shots"].append({"target": target.display_name, "node": target.name,
					"sample": fixture["id"], "expected_occluding": fixture["expected"],
					"passed": false, "reason": "no_legal_sample"})
				print("OCC-02 sample=", target.name, "/", fixture["id"], " no_legal_sample")
				continue
			var point: Vector2 = pose["point"]
			var side: String = pose["side"]
			player.global_position = point
			player.last_valid = point
			player.facing = {"top": Vector2.UP, "bottom": Vector2.DOWN,
				"left": Vector2.LEFT, "right": Vector2.RIGHT}[side]
			player.call("_apply_facing")
			player.get_node("Body").position.y = 0.0
			camera.global_position = point
			await get_tree().process_frame
			await get_tree().process_frame
			var expected: bool = fixture["expected"]
			var actual := bool(foreground.is_target_occluding(target))
			var image = viewport_image()
			var covered_body_pixels := 0
			var rendered := image != null
			if rendered:
				foreground.set_process(false)
				foreground.set_target_visible(target, false)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var unoccluded_image = viewport_image()
				if unoccluded_image != null:
					covered_body_pixels = count_pixel_differences(image, unoccluded_image,
						pose["body_rect"], foreground_poly)
				foreground.set_target_visible(target, actual)
				foreground.set_process(true)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				image = viewport_image()
			var overlay := EdgeOverlay.new()
			overlay.zone = zone
			overlay.player = player
			overlay.target = target
			overlay.sample_id = fixture["id"]
			overlay.expected = expected
			overlay.actual = actual
			overlay.covered_body_pixels = covered_body_pixels
			restaurant.add_child(overlay)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			image = viewport_image()
			var path := output_dir.path_join("OCC-02-" + target.name + "-" + fixture["id"] + ".png")
			var err := ERR_UNAVAILABLE
			var image_size := [0, 0]
			if image != null:
				err = image.save_png(path)
				image_size = [image.get_width(), image.get_height()]
			var covered_passed := true if not rendered else (covered_body_pixels > 0 if expected else covered_body_pixels == 0)
			var passed := actual == expected and bool(pose["circle_inside"]) \
				and float(pose["overlap_area"]) >= MIN_OVERLAP_AREA \
				and float(pose["foreground_overlap_area"]) >= MIN_FOREGROUND_AREA \
				and covered_passed and (not rendered or err == OK)
			if not passed:
				failures += 1
			report["shots"].append({"target": target.display_name, "node": target.name,
				"sample": fixture["id"], "point": [point.x, point.y], "side": side,
				"expected_occluding": expected, "actual_occluding": actual,
				"circle_inside": pose["circle_inside"], "interaction_overlap_area": pose["overlap_area"],
				"foreground_overlap_area": pose["foreground_overlap_area"],
				"covered_body_pixels": covered_body_pixels, "covered_body_pixels_passed": covered_passed,
				"rendered": rendered, "path": path, "size": image_size, "error": err, "passed": passed})
			print("OCC-02 capture=", path, " point=", point, " expected=", expected,
				" actual=", actual, " overlap=", pose["overlap_area"],
				" foreground_overlap=", pose["foreground_overlap_area"],
				" covered_body_pixels=", covered_body_pixels, " passed=", passed)
			overlay.queue_free()
	report["failures"] = failures
	var report_file := FileAccess.open(output_dir.path_join("OCC-02-occlusion.json"), FileAccess.WRITE)
	if report_file:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	get_tree().quit(0 if failures == 0 else 1)

func find_sample(target: Node2D, fixture: Dictionary, radius: float, zone: Node2D,
		interaction_poly: PackedVector2Array, foreground_poly: PackedVector2Array) -> Dictionary:
	if interaction_poly.size() < 3 or foreground_poly.size() < 3:
		return {}
	var anchor: Vector2 = target.to_global(fixture["offset"])
	var bounds := polygon_bounds(interaction_poly)
	var best: Dictionary = {}
	var best_score := INF
	for gy in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1, SEARCH_STEP):
		for gx in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1, SEARCH_STEP):
			var point := anchor + Vector2(gx, gy)
			if not zone.is_circle_inside(point, radius):
				continue
			var dx := maxf(maxf(bounds[0].x - point.x, 0.0), point.x - bounds[1].x)
			var dy := maxf(maxf(bounds[0].y - point.y, 0.0), point.y - bounds[1].y)
			var distance := Vector2(dx, dy).length()
			var side := facing_side(point, target.global_position)
			var rect := body_display_rect(point, side)
			var interaction_area := polygon_rect_area(interaction_poly, rect)
			var foreground_area := polygon_rect_area(foreground_poly, rect)
			if interaction_area < MIN_OVERLAP_AREA or foreground_area < MIN_FOREGROUND_AREA:
				continue
			var score := Vector2(gx, gy).length() + distance
			if score < best_score:
				best_score = score
				best = {"point": point, "side": side, "body_rect": rect,
					"overlap_area": interaction_area, "foreground_overlap_area": foreground_area,
					"circle_inside": true}
	return best

func polygon_bounds(points: PackedVector2Array) -> Array[Vector2]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for point in points:
		lo = lo.min(point)
		hi = hi.max(point)
	return [lo, hi]

func facing_side(point: Vector2, center: Vector2) -> String:
	var delta := point - center
	if absf(delta.x) > absf(delta.y):
		return "right" if delta.x > 0.0 else "left"
	return "bottom" if delta.y > 0.0 else "top"

func body_display_rect(point: Vector2, side: String) -> Rect2:
	var texture: Texture2D = TEX_SIDE if side == "left" or side == "right" else (TEX_BACK if side == "top" else TEX_FRONT)
	var scale := BODY_VIS_H / float(texture.get_height())
	var size := Vector2(texture.get_width(), texture.get_height()) * scale
	return Rect2(point + Vector2(-size.x * 0.5, -BODY_VIS_H), size)

func polygon_rect_area(poly: PackedVector2Array, rect: Rect2) -> float:
	if poly.size() < 3:
		return 0.0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for point in poly:
		lo = lo.min(point)
		hi = hi.max(point)
	var overlap := Rect2(lo, hi - lo).intersection(rect)
	return maxf(0.0, overlap.size.x * overlap.size.y)

func count_pixel_differences(visible: Image, hidden: Image, body_rect: Rect2,
		target_poly: PackedVector2Array) -> int:
	var transform := get_viewport().get_canvas_transform()
	var screen_poly := PackedVector2Array()
	for p in target_poly:
		screen_poly.append(transform * p)
	var screen_rect := project_rect(body_rect, transform)
	var count := 0
	var min_x := maxi(0, int(floor(screen_rect.position.x)))
	var min_y := maxi(0, int(floor(screen_rect.position.y)))
	var max_x := mini(visible.get_width() - 1, int(ceil(screen_rect.end.x)))
	var max_y := mini(visible.get_height() - 1, int(ceil(screen_rect.end.y)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var sample := Vector2(x + 0.5, y + 0.5)
			if not screen_rect.has_point(sample) or not Geometry2D.is_point_in_polygon(sample, screen_poly):
				continue
			var a := visible.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) > 0.05:
				count += 1
	return count

func project_rect(rect: Rect2, transform: Transform2D) -> Rect2:
	var points := [transform * rect.position, transform * Vector2(rect.end.x, rect.position.y),
		transform * rect.end, transform * Vector2(rect.position.x, rect.end.y)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)

func viewport_image():
	if DisplayServer.get_name() == "headless" or OS.has_feature("headless"):
		return null
	var texture := get_viewport().get_texture()
	return texture.get_image() if texture != null and texture.get_rid().is_valid() else null

func argument(prefix: String) -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

class EdgeOverlay extends Node2D:
	var zone: Node2D
	var player: CharacterBody2D
	var target: Node2D
	var sample_id := ""
	var expected := false
	var actual := false
	var covered_body_pixels := 0

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for poly in zone.polygons:
			if poly.size() >= 2:
				var p := PackedVector2Array(poly)
				p.append(p[0])
				draw_polyline(p, Color("5ce58a"), 2.0)
		for poly in zone.obstacle_polys:
			if poly.size() >= 2:
				var p := PackedVector2Array(poly)
				p.append(p[0])
				draw_polyline(p, Color("24d8e8"), 3.0)
		for spec in [[target.world_interaction_polygon(), Color("ff9f43")],
			[target.world_foreground_polygon(), Color("f06cff")],
			[target.world_occlusion_polygon(), Color("ffe56d")]]:
			var poly: PackedVector2Array = spec[0]
			if poly.size() >= 2:
				var p := PackedVector2Array(poly)
				p.append(p[0])
				draw_polyline(p, spec[1], 4.0)
		draw_circle(player.global_position, 5.0, Color("ffe56d"))
		draw_rect(Rect2(18, 18, 820, 142), Color(0.04, 0.07, 0.09, 0.88), true)
		draw_string(font, Vector2(32, 48), "OCC-02 六道具独立遮挡校准", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(font, Vector2(32, 78), "%s/%s 脚底=(%.1f, %.1f)  期望=%s 实际=%s" % [target.display_name, sample_id, player.global_position.x, player.global_position.y, "遮挡" if expected else "不遮挡", "遮挡" if actual else "不遮挡"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe56d"))
		draw_string(font, Vector2(32, 108), "绿=可走  青=障碍  橙=交互  紫=前景  黄=脚底区域  覆盖身体=%dpx" % covered_body_pixels, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d8e6e8"))
		draw_string(font, target.global_position + Vector2(12, -12), target.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("24d8e8"))
