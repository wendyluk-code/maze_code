extends Node

const SCENE := preload("res://scenes/restaurant_map_2d.tscn")
const SIDES := {
	"Cauldron": ["top", "bottom", "left", "right"],
	"FoodCart": ["top", "bottom", "left", "right"],
	"Fridge": ["top", "bottom", "left", "right"],
	"BarCounter": ["bottom", "right"],
	"Register": ["bottom", "left", "right"],
	"Store": ["left", "bottom"],
}

var report := {"checks": [], "routes": [], "samples": [], "polygons": []}
var failures := 0
var events: Array[String] = []
var scene: Node2D
var player: CharacterBody2D
var zone: Node2D
var ui: CanvasLayer
var targets: Array[Node2D] = []

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var save_manager := get_tree().root.get_node("SaveManager")
	var save_path := ProjectSettings.globalize_path("user://save.json")
	var save_before := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else "absent"
	save_manager.data["tutorial_done"] = true
	scene = SCENE.instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	player = scene.get_node("Player")
	player.spawn_ready = true
	player.interacted.connect(on_interacted)
	zone = scene.get_node("WalkZone")
	ui = scene.get_node("UIOverlay")
	await get_tree().process_frame
	await get_tree().process_frame
	for child in scene.get_node("InteractPoints").get_children():
		var target := child as Node2D
		targets.append(target)
		var polygon: PackedVector2Array = target.world_interaction_polygon()
		report["polygons"].append({"name": target.display_name, "node": target.name,
			"point": xy(target.global_position),
			"source": "manual" if target.interaction_polygon.size() >= 3 else "auto",
			"vertices": vertices(polygon)})
		check(polygon.size() >= 3, "polygon_" + target.name, {"vertices": polygon.size()})
	check(is_equal_approx(player.collision_radius_world(), 20.0), "collision_radius_20")
	check(is_equal_approx(ui.interaction_distance, player.INTERACT_RANGE), "ui_e_threshold_95")
	var store := scene.get_node("InteractPoints/Store")
	for point in [Vector2(1400, 615), Vector2(1400, 620), Vector2(1400, 630), Vector2(1300, 560)]:
		report["samples"].append(await sample(store, point, "regression"))
	check(report["samples"][2]["walk"] and report["samples"][2]["visible"]
		and report["samples"][2]["interacted"] == "仓库", "store_regression")
	var fridge := scene.get_node("InteractPoints/Fridge")
	var left_scan := []
	for y in range(540, 1021, 40):
		for x in range(120, 281, 20):
			var p := Vector2(x, y)
			if zone.is_point_inside(p):
				left_scan.append({"point": xy(p),
					"effective": maxf(0.0, fridge.interaction_distance_from(p) - player.collision_radius_world())})
	report["fridge_left_scan"] = left_scan
	for target in targets:
		for side in SIDES[target.name]:
			var route := find_route(target, side)
			if route.is_empty():
				report["routes"].append({"node": target.name, "side": side, "status": "no straight walkable crossing"})
				check(false, "route_" + target.name + "_" + side)
				continue
			var result: Dictionary = await walk_route(target, side, route)
			report["routes"].append(result)
			check(result["moved"] and not result["far_visible"] and result["near_visible"]
				and result["returned"] and not result["return_visible"],
				"route_" + target.name + "_" + side, result)
	await test_threshold(store)
	await test_multi_target()
	await test_tutorial()
	var save_after := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else "absent"
	report["save_sha256_before"] = save_before
	report["save_sha256_after"] = save_after
	check(save_before == save_after, "real_save_unchanged")
	report["failures"] = failures
	var output := argument("--output=")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(report, "\t"))
		else:
			push_error("Cannot write report: " + output)
			failures += 1
	print("INT_UI_02 checks=", report["checks"].size(), " routes=", report["routes"].size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func sample(target: Node2D, point: Vector2, label: String) -> Dictionary:
	player.global_position = point
	player.last_valid = point
	await get_tree().process_frame
	await get_tree().process_frame
	events.clear()
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	player._unhandled_input(event)
	var button: Control = ui._buttons.get(target)
	var nearest: Node2D = player.nearest_interactable()
	return {"label": label, "point": xy(point), "walk": zone.is_point_inside(point),
		"center_edge": target.interaction_distance_from(point),
		"effective": player.interaction_distance_to(target),
		"visible": button.visible if button else false,
		"nearest": nearest.display_name if nearest else "none",
		"interacted": events.back() if not events.is_empty() else "none"}

func find_route(target: Node2D, side: String) -> Dictionary:
	var bounds := polygon_bounds(target.world_interaction_polygon())
	var lo: Vector2 = bounds[0]
	var hi: Vector2 = bounds[1]
	var mid := (lo + hi) * 0.5
	var fallback := {}
	for tangent in range(-200, 201, 12):
		for far_gap in [150, 175, 130, 210, 118, 100]:
			for near_gap in [45, 25, 65, 10]:
				var far := side_point(side, lo, hi, mid, tangent, far_gap)
				var near := side_point(side, lo, hi, mid, tangent, near_gap)
				if not line_walkable(far, near):
					continue
				var far_d: float = maxf(0.0, target.interaction_distance_from(far) - player.collision_radius_world())
				var near_d: float = maxf(0.0, target.interaction_distance_from(near) - player.collision_radius_world())
				if far_d > 97.0 and near_d < 88.0:
					var route := {"far": far, "near": near, "far_distance": far_d, "near_distance": near_d}
					if nearest_target_at(near) == target:
						return route
					if fallback.is_empty():
						fallback = route
	return fallback

func nearest_target_at(point: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := 95.0
	for target in targets:
		var distance: float = maxf(0.0, target.interaction_distance_from(point) - player.collision_radius_world())
		if distance <= best_distance and (best == null or distance < best_distance
				or str(target.get_path()) < str(best.get_path())):
			best = target
			best_distance = distance
	return best

func walk_route(target: Node2D, side: String, route: Dictionary) -> Dictionary:
	var far: Vector2 = route["far"]
	var near: Vector2 = route["near"]
	var before: Dictionary = await sample(target, far, "route_far")
	var action: String = {"top": "ui_down", "bottom": "ui_up", "left": "ui_right", "right": "ui_left"}[side]
	Input.action_press(action)
	var steps := 0
	while player.global_position.distance_to(near) > 5.0 and steps < 100:
		await get_tree().physics_frame
		steps += 1
	Input.action_release(action)
	await get_tree().process_frame
	var after: Dictionary = await sample(target, player.global_position, "route_near")
	var return_action: String = {"ui_up": "ui_down", "ui_down": "ui_up",
		"ui_left": "ui_right", "ui_right": "ui_left"}[action]
	Input.action_press(return_action)
	var return_steps := 0
	var reached_far := false
	while return_steps < 100:
		await get_tree().physics_frame
		return_steps += 1
		reached_far = reached_far or player.global_position.distance_to(far) < 7.0
		if reached_far and player.interaction_distance_to(target) > 97.0:
			break
	Input.action_release(return_action)
	await get_tree().process_frame
	var returned: Dictionary = await sample(target, player.global_position, "route_return")
	return {"node": target.name, "side": side, "status": "moved", "far": before,
		"near": after, "return": returned, "steps": steps, "return_steps": return_steps,
		"moved": steps < 100 and Vector2(after["point"][0], after["point"][1]).distance_to(near) < 7.0,
		"returned": reached_far and return_steps < 100,
		"far_visible": before["visible"], "near_visible": after["visible"],
		"return_visible": returned["visible"],
		"target_e_at_near": after["interacted"] == target.display_name}

func test_threshold(store: Node2D) -> void:
	for delta in [-0.25, 0.0, 0.25]:
		var point := Vector2(1400, 735 + delta)
		var result: Dictionary = await sample(store, point, "threshold")
		report["samples"].append(result)
		check(result["walk"] and absf(result["effective"] - (95.0 + delta)) < 0.01
			and result["visible"] == (delta <= 0.0), "threshold_" + str(delta), result)
	var raw: float = store.interaction_distance_from(Vector2(1400, 735))
	player.scale = Vector2(1.5, 1.5)
	check(is_equal_approx(player.collision_radius_world(), 30.0)
		and is_equal_approx(maxf(0.0, raw - player.collision_radius_world()), 85.0),
		"world_scaled_collision_radius")
	player.scale = Vector2.ONE

func test_multi_target() -> void:
	var pair := {}
	for y in range(420, 780, 8):
		for x in range(900, 1320, 8):
			var point := Vector2(x, y)
			if not zone.is_point_inside(point):
				continue
			var eligible: Array[String] = []
			for target in targets:
				if maxf(0.0, target.interaction_distance_from(point) - player.collision_radius_world()) <= 95.0:
					eligible.append(target.display_name)
			if eligible.size() >= 2:
				pair = {"point": point, "eligible": eligible}
				break
		if not pair.is_empty():
			break
	if pair.is_empty():
		check(false, "multi_target_overlap")
		return
	var point: Vector2 = pair["point"]
	var result: Dictionary = await sample(targets[0], point, "multi_target")
	var visible: Array[String] = []
	for target in targets:
		var button: Control = ui._buttons.get(target)
		if button.visible:
			visible.append(target.display_name)
	var nearest: Node2D = player.nearest_interactable()
	report["multi_target"] = {"point": xy(point), "eligible": pair["eligible"],
		"visible": visible, "nearest": nearest.display_name if nearest else "none",
		"interacted": result["interacted"]}
	check(visible.size() >= 2 and result["interacted"] == nearest.display_name,
		"multi_target_nearest", report["multi_target"])
	var separating := {}
	var first: Node2D = null
	var second: Node2D = null
	for target in targets:
		if target.display_name == pair["eligible"][0]:
			first = target
		if target.display_name == pair["eligible"][1]:
			second = target
	for option in [{"step": Vector2.DOWN, "action": "ui_down"},
			{"step": Vector2.RIGHT, "action": "ui_right"},
			{"step": Vector2.LEFT, "action": "ui_left"},
			{"step": Vector2.UP, "action": "ui_up"}]:
		for distance in range(16, 241, 8):
			var destination: Vector2 = point + option["step"] * distance
			if not line_walkable(point, destination):
				break
			var a: bool = maxf(0.0, first.interaction_distance_from(destination)
				- player.collision_radius_world()) <= 95.0
			var b: bool = maxf(0.0, second.interaction_distance_from(destination)
				- player.collision_radius_world()) <= 95.0
			if a != b:
				separating = {"point": destination, "action": option["action"], "first": a, "second": b}
				break
		if not separating.is_empty():
			break
	if not separating.is_empty():
		player.global_position = point
		player.last_valid = point
		Input.action_press(separating["action"])
		var steps := 0
		while player.global_position.distance_to(separating["point"]) > 5.0 and steps < 120:
			await get_tree().physics_frame
			steps += 1
		Input.action_release(separating["action"])
		await get_tree().process_frame
		var first_button: Control = ui._buttons.get(first)
		var second_button: Control = ui._buttons.get(second)
		report["multi_target"]["leave"] = {"point": xy(player.global_position),
			"first_visible": first_button.visible, "second_visible": second_button.visible,
			"first": first.display_name, "second": second.display_name, "steps": steps}
		check(steps < 120 and first_button.visible != second_button.visible
			and first_button.visible == separating["first"], "leave_hides_only_one",
			report["multi_target"]["leave"])
	else:
		check(false, "multi_target_separating_route")
	# An equal-distance pair checks explicit path-order tie breaking, independently of the map props.
	var empty := Vector2(800, 980)
	if zone.is_point_inside(empty):
		player.global_position = empty
		player.last_valid = empty
		var tie_a := Node2D.new()
		var tie_b := Node2D.new()
		tie_a.name = "TieA"
		tie_b.name = "TieB"
		scene.add_child(tie_b)
		scene.add_child(tie_a)
		tie_a.global_position = empty
		tie_b.global_position = empty
		tie_a.add_to_group("interactable")
		tie_b.add_to_group("interactable")
		check(player.nearest_interactable() == tie_a and player.nearest_interactable() == tie_a,
			"equal_distance_tie_path")
		tie_a.queue_free()
		tie_b.queue_free()
		await get_tree().process_frame
	else:
		check(false, "tie_setup_walkable")

func test_tutorial() -> void:
	var tm := get_tree().root.get_node("TutorialManager")
	var lines: Array[String] = []
	for i in 5:
		var step: Dictionary = tm.restaurant_lesson()[i]
		lines.append(str(step["speaker"]) + ":" + str(step["lines"][0]))
	check(lines == ["芽芽:……你终于醒了。", "芽芽:你还记得我吗？", "你:……？",
		"芽芽:……果然，你又想不起来了。", "芽芽:没关系。我陪着你，总会想起来的。"],
		"opening_dialogue_approved", {"lines": lines})
	report["tutorial_boundaries"] = []
	for tutorial_target in [{"name": "Register", "radius": 120.0},
			{"name": "Store", "radius": 150.0}, {"name": "Cauldron", "radius": 140.0}]:
		var target := scene.get_node("InteractPoints/" + tutorial_target["name"])
		var radius: float = tutorial_target["radius"]
		var crossing := find_tutorial_crossing(target, radius)
		if crossing.is_empty():
			check(false, "tutorial_boundary_" + tutorial_target["name"])
			continue
		player.global_position = crossing["far"]
		player.last_valid = player.global_position
		tm.start([{"type": "move_to", "target": target.display_name, "radius": radius},
			{"type": "interact", "target": target.display_name}])
		await get_tree().process_frame
		var before: int = tm.idx
		Input.action_press(crossing["action"])
		var steps := 0
		while player.global_position.distance_to(crossing["near"]) > 5.0 and steps < 100:
			await get_tree().physics_frame
			steps += 1
		Input.action_release(crossing["action"])
		await get_tree().process_frame
		var boundary := {"name": target.display_name, "radius": radius,
			"far": xy(crossing["far"]), "far_effective": crossing["far_distance"],
			"near": xy(player.global_position),
			"near_effective": player.interaction_distance_to(target), "steps": steps,
			"before_idx": before, "after_idx": tm.idx}
		report["tutorial_boundaries"].append(boundary)
		check(before == 0 and tm.idx == 1 and steps < 100,
			"tutorial_boundary_" + tutorial_target["name"], boundary)
		tm.skip_all()
		await get_tree().process_frame
	player.global_position = Vector2(1400, 630)
	player.last_valid = player.global_position
	tm.start([{"type": "dialog", "speaker": "测试", "lines": ["测试"]},
		{"type": "interact", "target": "仓库"}])
	await get_tree().process_frame
	var store := scene.get_node("InteractPoints/Store")
	var button: Control = ui._buttons.get(store)
	events.clear()
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	player._unhandled_input(event)
	check(tm.active and tm.idx == 0 and player.input_locked and not button.visible
		and events.is_empty(), "dialog_suppresses_ui_and_e")
	tm.skip_all()
	await get_tree().process_frame
	check(not tm.active and not player.input_locked and player.is_physics_processing(),
		"dialog_skip_restores_player")
	tm.start([{"type": "interact", "target": "仓库"},
		{"type": "move_to", "target": "仓库", "radius": 150.0}])
	await get_tree().process_frame
	tm._on_player_interact(scene.get_node("InteractPoints/FoodCart"))
	check(tm.idx == 0, "wrong_target_does_not_advance")
	tm._on_player_interact(store)
	check(tm.idx == 1, "right_interact_advances")
	player.global_position = Vector2(1400, 800)
	player.last_valid = player.global_position
	await get_tree().process_frame
	var before: int = tm.idx
	player.global_position = Vector2(1400, 765)
	player.last_valid = player.global_position
	await get_tree().process_frame
	report["tutorial_radius"] = {"store": 150.0, "register": 120.0, "cauldron": 140.0,
		"far_effective": maxf(0.0, store.interaction_distance_from(Vector2(1400, 800)) - player.collision_radius_world()),
		"near_effective": maxf(0.0, store.interaction_distance_from(Vector2(1400, 765)) - player.collision_radius_world())}
	check(before == 1 and tm.idx > before, "move_to_uses_effective_distance", report["tutorial_radius"])
	if tm.active:
		tm.skip_all()
	await get_tree().process_frame
	tm.start([{"type": "cutscene_guest", "camera_pos": Vector2(1000, 320), "delay": 0.0},
		{"type": "interact", "target": "仓库"}])
	await get_tree().process_frame
	events.clear()
	player._unhandled_input(event)
	check(tm.active and tm.idx == 0 and player.input_locked and not button.visible
		and events.is_empty(), "cutscene_suppresses_ui_and_e")
	tm.skip_all()
	await get_tree().process_frame
	var cam := scene.get_node("Camera")
	check(not tm.active and not player.input_locked and not cam.paused
		and player.is_physics_processing(), "cutscene_skip_restores_state")

func side_point(side: String, lo: Vector2, hi: Vector2, mid: Vector2,
		tangent: int, gap: int) -> Vector2:
	match side:
		"top": return Vector2(mid.x + tangent, lo.y - gap)
		"bottom": return Vector2(mid.x + tangent, hi.y + gap)
		"left": return Vector2(lo.x - gap, mid.y + tangent)
		_: return Vector2(hi.x + gap, mid.y + tangent)

func find_tutorial_crossing(target: Node2D, radius: float) -> Dictionary:
	var bounds := polygon_bounds(target.world_interaction_polygon())
	var lo: Vector2 = bounds[0]
	var hi: Vector2 = bounds[1]
	var mid := (lo + hi) * 0.5
	for side in ["bottom", "left", "right", "top"]:
		for tangent in range(-120, 121, 12):
			var far := side_point(side, lo, hi, mid, tangent, int(radius + 55))
			var near := side_point(side, lo, hi, mid, tangent, int(radius - 5))
			if not line_walkable(far, near):
				continue
			var far_d: float = maxf(0.0, target.interaction_distance_from(far) - player.collision_radius_world())
			var near_d: float = maxf(0.0, target.interaction_distance_from(near) - player.collision_radius_world())
			if far_d > radius + 5.0 and near_d < radius - 5.0:
				return {"far": far, "near": near, "far_distance": far_d,
					"action": {"top": "ui_down", "bottom": "ui_up", "left": "ui_right", "right": "ui_left"}[side]}
	return {}

func line_walkable(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / 6.0)
	for i in range(steps + 1):
		if not zone.is_point_inside(a.lerp(b, float(i) / float(steps))):
			return false
	return true

func polygon_bounds(points: PackedVector2Array) -> Array[Vector2]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for point in points:
		lo = lo.min(point)
		hi = hi.max(point)
	return [lo, hi]

func vertices(points: PackedVector2Array) -> Array:
	var result := []
	for point in points:
		result.append(xy(point))
	return result

func xy(point: Vector2) -> Array:
	return [snappedf(point.x, 0.001), snappedf(point.y, 0.001)]

func argument(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""

func check(ok: bool, name: String, details: Dictionary = {}) -> void:
	report["checks"].append({"name": name, "pass": ok, "details": details})
	if not ok:
		failures += 1
		print("INT_UI_02 FAIL ", name, " ", details)

func on_interacted(target: Node2D) -> void:
	events.append(target.display_name if "display_name" in target else target.name)
