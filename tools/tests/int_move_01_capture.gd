extends Node

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const SIDES := {
	"Cauldron": "top",
	"FoodCart": "right",
	"Fridge": "left",
	"BarCounter": "bottom",
	"Register": "right",
	"Store": "bottom",
}

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
	var failures := 0
	for child in restaurant.get_node("InteractPoints").get_children():
		var target := child as Node2D
		if target == null:
			continue
		var side: String = SIDES.get(target.name, "bottom")
		var point := find_legal_edge(target, side, player.collision_radius_world(), zone)
		if point == Vector2.ZERO:
			print("INT_MOVE_01 capture=", target.name, " no_legal_edge")
			failures += 1
			continue
		player.global_position = point
		player.last_valid = point
		player.facing = {"top": Vector2.UP, "bottom": Vector2.DOWN,
			"left": Vector2.LEFT, "right": Vector2.RIGHT}[side]
		player.call("_apply_facing")
		player.get_node("Body").position.y = 0.0
		camera.global_position = point
		var overlay := EdgeOverlay.new()
		overlay.zone = zone
		overlay.player = player
		overlay.target = target
		overlay.side = side
		restaurant.add_child(overlay)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := output_dir.path_join("INT-MOVE-01-" + target.name + "-edge.png")
		var err := image.save_png(path)
		print("INT_MOVE_01 capture=", path, " point=", point, " center_clearance=",
			target.interaction_distance_from(point), " circle_inside=",
			zone.is_circle_inside(point, player.collision_radius_world()), " error=", err)
		if err != OK:
			failures += 1
		overlay.queue_free()
	get_tree().quit(0 if failures == 0 else 1)

func find_legal_edge(target: Node2D, side: String, radius: float, zone: Node2D) -> Vector2:
	var bounds := polygon_bounds(target.world_interaction_polygon())
	var lo: Vector2 = bounds[0]
	var hi: Vector2 = bounds[1]
	var mid := (lo + hi) * 0.5
	for gap in range(12, 180, 4):
		for tangent in range(-160, 161, 8):
			var point := side_point(side, lo, hi, mid, tangent, gap)
			if zone.is_circle_inside(point, radius) and target.interaction_distance_from(point) <= 45.0:
				return point
	return Vector2.ZERO

func side_point(side: String, lo: Vector2, hi: Vector2, mid: Vector2,
		tangent: int, gap: int) -> Vector2:
	match side:
		"top": return Vector2(mid.x + tangent, lo.y - gap)
		"bottom": return Vector2(mid.x + tangent, hi.y + gap)
		"left": return Vector2(lo.x - gap, mid.y + tangent)
		_: return Vector2(hi.x + gap, mid.y + tangent)

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
		draw_rect(Rect2(18, 18, 660, 98), Color(0.04, 0.07, 0.09, 0.88), true)
		draw_string(font, Vector2(32, 48), "INT-MOVE-01  六道具真实边缘", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(font, Vector2(32, 78), "绿色=可走外轮廓  青色=障碍岛  橙色=道具交互轮廓", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d8e6e8"))
		draw_string(font, Vector2(32, 103), "黄色点=脚底中心  红圈=20px碰撞圆  最近距离=%.2fpx" % point.distance_to(closest), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d8e6e8"))
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
