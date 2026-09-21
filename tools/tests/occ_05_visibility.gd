extends Node

## OCC-05：用真实方向输入连续接近前台/吧台，并检查遮挡状态、E 提示和可见主体。

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const PATHS := {
	"Register": {
		"start": Vector2(-50, 118),
		"end": Vector2(-40, 113),
		"actions": ["ui_right", "ui_up"],
		"frames": 8,
	},
	"BarCounter": {
		"start": Vector2(266, 32),
		"end": Vector2(290, 30),
		"actions": ["ui_right"],
		"frames": 6,
	},
}

var output_dir := ""
var report := {
	"ticket": "OCC-05",
	"project_id": "be00658b-6081-4191-8060-f498f2bd6819",
	"input_mode": "real_direction_actions",
	"paths": [],
	"failures": 0,
}

func _ready() -> void:
	call_deferred("capture")

func capture() -> void:
	output_dir = argument("--output-dir=")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://occ05")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for target_name in PATHS.keys():
		await capture_path(target_name, PATHS[target_name])
	var file := FileAccess.open(output_dir.path_join("OCC-05-visibility.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	get_tree().quit(0 if int(report["failures"]) == 0 else 1)

func capture_path(target_name: String, spec: Dictionary) -> void:
	var restaurant := SCENE.instantiate()
	get_tree().root.add_child(restaurant)
	get_tree().current_scene = restaurant
	var player := restaurant.get_node("Player") as CharacterBody2D
	var camera := restaurant.get_node("Camera") as Camera2D
	var foreground := restaurant.get_node("PropForeground")
	var target := restaurant.get_node("InteractPoints").get_node(target_name) as Node2D
	var zone := restaurant.get_node("WalkZone") as Node2D
	var ui := restaurant.get_node("UIOverlay") as CanvasLayer
	ui.visible = true
	var guide := restaurant.get_node_or_null("UIOverlay/TutorialGuide")
	if guide:
		guide.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var start_world := target.to_global(spec["start"])
	var end_world := target.to_global(spec["end"])
	player.spawn_ready = true
	player.global_position = start_world
	player.last_valid = start_world
	player.facing = Vector2.UP
	camera.set_process(false)
	camera.set_physics_process(false)
	var states: Array[bool] = []
	var trail := PackedVector2Array()
	var prompt_end := false
	var nearest_end := ""
	for action in spec["actions"]:
		Input.action_press(action)
	for frame in range(int(spec["frames"])):
		await get_tree().physics_frame
		await get_tree().process_frame
		camera.global_position = player.global_position
		states.append(bool(foreground.is_target_occluding(target)))
		trail.append(player.global_position)
	var end_nearest: Node2D = player.nearest_interactable()
	nearest_end = "" if end_nearest == null else end_nearest.name
	prompt_end = nearest_end == target_name
	for action in spec["actions"]:
		Input.action_release(action)
	var switches := count_state_switches(states)
	var end_local := target.to_local(player.global_position)
	var body_visible_ratio := estimate_body_visible_ratio(player, target, foreground)
	var passed := bool(states[0]) and not bool(states[states.size() - 1]) \
		and switches <= 1 and prompt_end and body_visible_ratio >= 0.35
	var image_path := ""
	var overlay := EvidenceOverlay.new()
	overlay.target = target
	overlay.player = player
	overlay.trail = trail
	overlay.target_name = target_name
	overlay.states = states
	get_tree().current_scene.add_child(overlay)
	await get_tree().process_frame
	var image = viewport_image()
	if image != null:
		image_path = output_dir.path_join("OCC-05-%s-continuous.png" % target_name)
		image.save_png(image_path)
	overlay.queue_free()
	report["paths"].append({
		"target": target_name,
		"input_actions": spec["actions"],
		"requested_start_local": [spec["start"].x, spec["start"].y],
		"requested_end_local": [spec["end"].x, spec["end"].y],
		"actual_end_local": [end_local.x, end_local.y],
		"frames": states.size(),
		"states": states,
		"switch_count": switches,
		"nearest_end": nearest_end,
		"e_prompt_end": prompt_end,
		"body_visible_ratio": body_visible_ratio,
		"screenshot": image_path,
		"passed": passed,
	})
	if not passed:
		report["failures"] += 1
	restaurant.queue_free()
	await get_tree().process_frame

func estimate_body_visible_ratio(player: CharacterBody2D, target: Node2D, foreground: Node) -> float:
	var body := PackedVector2Array([
		player.global_position + Vector2(-32.0, -130.0),
		player.global_position + Vector2(32.0, -130.0),
		player.global_position + Vector2(32.0, 0.0),
		player.global_position + Vector2(-32.0, 0.0),
	])
	var body_area := absf(polygon_area(body))
	var layer := foreground.get_node_or_null(target.name + "Foreground") as Polygon2D
	if body_area <= 0.0 or layer == null or not layer.visible:
		return 1.0
	var overlap := 0.0
	for clipped in Geometry2D.intersect_polygons(body, layer.polygon):
		overlap += absf(polygon_area(clipped))
	return clampf(1.0 - overlap / body_area, 0.0, 1.0)

func polygon_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	return area * 0.5

func count_state_switches(states: Array) -> int:
	var switches := 0
	for i in range(1, states.size()):
		if states[i] != states[i - 1]:
			switches += 1
	return switches

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

class EvidenceOverlay extends Node2D:
	var target: Node2D
	var player: CharacterBody2D
	var trail := PackedVector2Array()
	var target_name := ""
	var states: Array[bool] = []

	func _ready() -> void:
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		if trail.size() >= 2:
			draw_polyline(trail, Color("8de8ff"), 3.0)
		var poly: PackedVector2Array = target.world_occlusion_polygon()
		if poly.size() >= 2:
			var closed := PackedVector2Array(poly)
			closed.append(poly[0])
			draw_polyline(closed, Color("ffe56d"), 3.0)
		draw_circle(player.global_position, 6.0, Color("ffef79"))
		draw_rect(Rect2(18, 18, 820, 82), Color(0.04, 0.07, 0.09, 0.88), true)
		draw_string(font, Vector2(32, 48), "OCC-05 %s / 连续方向输入" % target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		draw_string(font, Vector2(32, 76), "蓝线=脚底轨迹  黄线=遮挡前缘  状态切换=%d" % _state_switches(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe56d"))

	func _state_switches() -> int:
		var switches := 0
		for i in range(1, states.size()):
			if states[i] != states[i - 1]:
				switches += 1
		return switches
