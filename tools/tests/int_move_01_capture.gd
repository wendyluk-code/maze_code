extends Node

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const BODY_VIS_H := 130.0
const MIN_OVERLAP_AREA := 250.0
const TARGET_OVERLAP_AREA := 3200.0
const SEARCH_STEP := 16
const TEX_FRONT := preload("res://assets/characters/hero/hero_front.png")
const TEX_BACK := preload("res://assets/characters/hero/hero_back.png")
const TEX_SIDE := preload("res://assets/characters/hero/hero_side.png")

var output_dir := ""

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	output_dir = argument("--output-dir=")
	if output_dir.is_empty():
		push_error("--output-dir is required")
		get_tree().quit(1)
		return
	get_tree().root.get_node("SaveManager").data["tutorial_done"] = true
	var restaurant := SCENE.instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	var player := restaurant.get_node("Player") as CharacterBody2D
	player.spawn_ready = true
	var camera := restaurant.get_node("Camera") as Camera2D
	var ui := restaurant.get_node("UIOverlay")
	ui.visible = false
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.zoom = Vector2(0.72, 0.72)
	var zone := restaurant.get_node("WalkZone") as Node2D
	var foreground := restaurant.get_node("PropForeground")
	var failures := 0
	var report := {"shots": [], "failures": 0}
	for child in restaurant.get_node("InteractPoints").get_children():
		var target := child as Node2D
		if target == null:
			continue
		for kind in ["behind", "front"]:
			var pose := find_overlap_edge(target, kind, player.collision_radius_world(), zone)
			var point: Vector2 = pose.get("point", Vector2.ZERO)
			if point == Vector2.ZERO:
				print("INT_MOVE_01 capture=", target.name, " kind=", kind, " no_legal_edge")
				failures += 1
				continue
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
			var overlay := EdgeOverlay.new()
			overlay.zone = zone
			overlay.player = player
			overlay.target = target
			overlay.side = side
			overlay.kind = kind
			overlay.occluding = foreground.is_target_occluding(target)
			overlay.overlap_area = float(pose["overlap_area"])
			overlay.overlap_screen_pixels = projected_overlap_pixels(
				pose["body_rect"], target.world_interaction_polygon())
			restaurant.add_child(overlay)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var covered_body_pixels := 0
			if kind == "behind":
				foreground.set_process(false)
				foreground.set_target_visible(target, false)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var unoccluded_image := get_viewport().get_texture().get_image()
				covered_body_pixels = count_pixel_differences(image, unoccluded_image,
					pose["body_rect"], target.world_interaction_polygon())
				foreground.set_target_visible(target, true)
				foreground.set_process(true)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
			overlay.covered_body_pixels = covered_body_pixels
			overlay.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			image = get_viewport().get_texture().get_image()
			var path := output_dir.path_join("INT-MOVE-01-" + target.name + "-" + kind + ".png")
			var err := image.save_png(path)
			var expected_occluding: bool = kind == "behind"
			var overlap := float(pose["overlap_area"]) >= MIN_OVERLAP_AREA
			var occlusion_active: bool = bool(foreground.is_target_occluding(target))
			var covered_passed := covered_body_pixels > 0 if kind == "behind" else covered_body_pixels == 0
			var passed: bool = err == OK and bool(pose["circle_inside"]) and overlap \
				and occlusion_active == expected_occluding and covered_passed
			report["shots"].append({"target": target.display_name, "kind": kind, "side": side,
				"point": [point.x, point.y], "center_clearance": target.interaction_distance_from(point),
				"circle_inside": pose["circle_inside"], "overlap": overlap,
				"overlap_area": pose["overlap_area"], "overlap_screen_pixels": overlay.overlap_screen_pixels,
				"occlusion_active": occlusion_active, "occluding": occlusion_active,
				"expected_occluding": expected_occluding, "covered_body_pixels": covered_body_pixels,
				"covered_body_pixels_passed": covered_passed,
				"path": path, "size": [image.get_width(), image.get_height()], "error": err, "passed": passed})
			print("INT_MOVE_01 capture=", path, " point=", point, " center_clearance=",
				target.interaction_distance_from(point), " circle_inside=", pose["circle_inside"],
				" overlap=", overlap, " area=", pose["overlap_area"],
				" occlusion_active=", occlusion_active, " covered_body_pixels=", covered_body_pixels,
				" expected=", expected_occluding, " error=", err)
			if not passed:
				failures += 1
			overlay.queue_free()
	report["failures"] = failures
	var report_file := FileAccess.open(output_dir.path_join("INT-MOVE-01-R1-occlusion.json"), FileAccess.WRITE)
	if report_file:
		report_file.store_string(JSON.stringify(report, "\t"))
		report_file.close()
	get_tree().quit(0 if failures == 0 else 1)

func find_overlap_edge(target: Node2D, kind: String, radius: float, zone: Node2D) -> Dictionary:
	var poly: PackedVector2Array = target.world_interaction_polygon()
	if poly.size() < 3:
		return {}
	var bounds := polygon_bounds(poly)
	var search_poly := decimate_polygon(poly, 8)
	var front_y := -INF
	for p in poly:
		front_y = maxf(front_y, p.y)
	var best: Dictionary = {}
	var best_score := -INF
	var stride := maxi(1, int(poly.size() / 160))
	for i in range(0, poly.size(), stride):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var edge := b - a
		if edge.length_squared() < 1.0:
			continue
		var normal := Vector2(-edge.y, edge.x).normalized()
		var midpoint := (a + b) * 0.5
		for gap in range(22, 51, 4):
			for direction in [-1.0, 1.0]:
				var point: Vector2 = midpoint + normal * gap * float(direction)
				if Geometry2D.is_point_in_polygon(point, poly):
					continue
				if not zone.is_circle_inside(point, radius):
					continue
				var is_behind: bool = point.y <= front_y + 0.5
				if (kind == "behind") != is_behind:
					continue
				var side := facing_side(point, target.global_position)
				var rect := body_display_rect(point, side)
				var overlap_area := polygon_rect_area(search_poly, rect)
				if overlap_area < MIN_OVERLAP_AREA:
					continue
				var exact_distance: float = target.interaction_distance_from(point)
				if exact_distance > 45.0:
					continue
				var score: float = -absf(overlap_area - TARGET_OVERLAP_AREA) - exact_distance
				if score > best_score:
					best_score = score
					best = {"point": point, "side": side, "body_rect": rect,
						"overlap_area": overlap_area,
						"circle_inside": zone.is_circle_inside(point, radius)}
	if best.is_empty():
		# A small fallback around the authored center handles very short or noisy edges.
		var center := target.global_position
		for y in range(int(bounds[0].y - 60.0), int(bounds[1].y + 61.0), SEARCH_STEP):
			for x in range(int(bounds[0].x - 60.0), int(bounds[1].x + 61.0), SEARCH_STEP):
				var point: Vector2 = Vector2(x, y)
				if Geometry2D.is_point_in_polygon(point, poly) or not zone.is_circle_inside(point, radius):
					continue
				if target.interaction_distance_from(point) > 45.0:
					continue
				var is_behind: bool = point.y <= front_y + 0.5
				if (kind == "behind") != is_behind:
					continue
				var side := facing_side(point, center)
				var rect := body_display_rect(point, side)
				var overlap_area := polygon_rect_area(search_poly, rect)
				if overlap_area >= MIN_OVERLAP_AREA:
					if target.interaction_distance_from(point) > 45.0:
						continue
					return {"point": point, "side": side, "body_rect": rect,
						"overlap_area": overlap_area, "circle_inside": true}
	return best

func decimate_polygon(poly: PackedVector2Array, stride: int) -> PackedVector2Array:
	if poly.size() <= 220:
		return poly
	var result := PackedVector2Array()
	for i in range(0, poly.size(), stride):
		result.append(poly[i])
	return result

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
	var rect_poly := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size, rect.position + Vector2(0, rect.size.y)])
	var intersections := Geometry2D.intersect_polygons(rect_poly, poly)
	var area := 0.0
	for intersection in intersections:
		area += absf(polygon_area(intersection))
	return area

func polygon_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])
	return sum * 0.5

func projected_overlap_pixels(body_rect: Rect2, target_poly: PackedVector2Array) -> int:
	var transform := get_viewport().get_canvas_transform()
	var screen_poly := PackedVector2Array()
	for p in decimate_polygon(target_poly, 8):
		screen_poly.append(transform * p)
	var screen_rect := project_rect(body_rect, transform)
	return count_overlap_pixels(screen_rect, screen_poly)

func count_pixel_differences(visible: Image, hidden: Image, body_rect: Rect2,
		target_poly: PackedVector2Array) -> int:
	var transform := get_viewport().get_canvas_transform()
	var screen_poly := PackedVector2Array()
	for p in decimate_polygon(target_poly, 8):
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
			var visible_pixel := visible.get_pixel(x, y)
			var hidden_pixel := hidden.get_pixel(x, y)
			if absf(visible_pixel.r - hidden_pixel.r) + absf(visible_pixel.g - hidden_pixel.g) \
				+ absf(visible_pixel.b - hidden_pixel.b) + absf(visible_pixel.a - hidden_pixel.a) > 0.05:
				count += 1
	return count

func count_overlap_pixels(screen_rect: Rect2, screen_poly: PackedVector2Array) -> int:
	var count := 0
	var min_x := int(floor(screen_rect.position.x))
	var min_y := int(floor(screen_rect.position.y))
	var max_x := int(ceil(screen_rect.end.x))
	var max_y := int(ceil(screen_rect.end.y))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var sample := Vector2(x + 0.5, y + 0.5)
			if screen_rect.has_point(sample) and Geometry2D.is_point_in_polygon(sample, screen_poly):
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

func polygon_bounds(points: PackedVector2Array) -> Array[Vector2]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for point in points:
		lo = lo.min(point)
		hi = hi.max(point)
	return [lo, hi]

func argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

class EdgeOverlay extends Node2D:
	var zone: Node2D
	var player: CharacterBody2D
	var target: Node2D
	var side := "bottom"
	var kind := "edge"
	var occluding := false
	var overlap_area := 0.0
	var overlap_screen_pixels := 0
	var covered_body_pixels := 0

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var green := Color("5ce58a")
		var cyan := Color("24d8e8")
		var red := Color("f14d5b")
		var yellow := Color("ffe56d")
		var orange := Color("ff9f43")
		for poly in zone.polygons:
			if poly.size() >= 2:
				var outer := PackedVector2Array(poly)
				outer.append(outer[0])
				draw_polyline(outer, green, 3.0)
		for poly in zone.obstacle_polys:
			if poly.size() >= 2:
				var obstacle := PackedVector2Array(poly)
				obstacle.append(obstacle[0])
				draw_polyline(obstacle, cyan, 4.0)
		var target_poly: PackedVector2Array = target.world_interaction_polygon()
		if target_poly.size() >= 2:
			var outline := PackedVector2Array(target_poly)
			outline.append(outline[0])
			draw_polyline(outline, orange, 5.0)
		var point := player.global_position
		draw_circle(point, player.collision_radius_world(), Color(0.95, 0.2, 0.3, 0.16))
		draw_arc(point, player.collision_radius_world(), 0.0, TAU, 64, red, 4.0)
		draw_circle(point, 5.0, yellow)
		var closest := nearest_on_polygon(point, target_poly)
		draw_line(point, closest, yellow, 3.0)
		draw_rect(Rect2(18, 18, 760, 150), Color(0.04, 0.07, 0.09, 0.88), true)
		draw_string(font, Vector2(32, 48), "INT-MOVE-01  六道具真实边缘", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(font, Vector2(32, 78), "绿色=可走外轮廓  青色=障碍岛  橙色=道具交互轮廓", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d8e6e8"))
		draw_string(font, Vector2(32, 103), "黄色点=脚底中心  红圈=20px碰撞圆  最近距离=%.2fpx" % point.distance_to(closest), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d8e6e8"))
		draw_string(font, Vector2(32, 128), "状态=%s  前景遮挡=%s（前侧应关闭，后侧应开启）" % [kind, "开启" if occluding else "关闭"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe56d"))
		draw_string(font, Vector2(32, 153), "overlap=%s  交叠面积=%.1fpx²  屏幕交叠=%dpx  覆盖身体=%dpx" % [overlap_area >= MIN_OVERLAP_AREA, overlap_area, overlap_screen_pixels, covered_body_pixels], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe56d"))
		draw_string(font, target.global_position + Vector2(12, -12), target.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cyan)

	func nearest_on_polygon(point: Vector2, poly: PackedVector2Array) -> Vector2:
		var best := Vector2.ZERO
		var distance := INF
		for i in poly.size():
			var candidate := Geometry2D.get_closest_point_to_segment(point, poly[i], poly[(i + 1) % poly.size()])
			if point.distance_to(candidate) < distance:
				distance = point.distance_to(candidate)
				best = candidate
		return best
