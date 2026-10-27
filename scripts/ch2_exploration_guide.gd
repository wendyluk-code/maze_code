extends CanvasLayer
## 第二章食材回流教学。检查点只描述教程，不替代接单、捕获和结算事务。
const KEY := "ch2_guide_01"
const Run := preload("res://scripts/maze/capture_run.gd")
const PORTRAIT := preload("res://assets/characters/yaya_portrait.png")
const FREEZER_NOTICE := "freezer_unlock"
const FREEZER_LINE := "【冰柜】已解锁，可以存放多出来的料理。注意在保鲜期前使用掉哦。"
var restaurant: Node
var maze: Node
var guide: Control
var reading := false
var lesson_id := ""
var targets: Array[Control] = []
var allowed: Array[Control] = []
var original_scales: Dictionary = {}
var original_pivots: Dictionary = {}
var after_read: Callable
var old_locked := false
var old_physics := true
var locked_player: Node
var camera: Camera2D
var camera_state := {}
var gate := false
var motion_player: Node
var motion_physics := true
var world_focus := Rect2()
var hold_frames := 0
var pending_save: Callable
var transient_targets: Array[Control] = []
var external_circles: Array[Vector4] = []
var paused_attempt: Control
var bag_lesson_busy := false
var operation_glows: Array[Panel] = []
var operation_shades: Dictionary = {}
var operation_focus_styles: Dictionary = {}
var glow_tween: Tween
const LINES := {
	"01_recipe":"接到新订单！可以点击左下角【食谱】查看各个料理所需要的食材。",
	"05_power":"小心，靠近魔物会触发他们战斗，单击鼠标左键可以发起攻击，边拉开距离边打倒它们吧！",
	"06_absorb":"魔物被击败后可以选择将其变为食材",
	"05_switch":"按【Tab键】可以切换不同角色的技能，选择趁手的技能进行攻击吧",
	"07_capture":"每次捕获都会消耗1点饱腹度，试着捕获吧！",
	"11_suppress":"魔物要跑掉了，快速按J镇压住它！",
	"13_bag":"成功啦！本趟探索获得的食材会暂时存放在左下角【背包】，需要完成探索后才能带回餐厅，努力到达终点吧。",
	"18_return":"恭喜完成第一次探索！本趟带回的食材已经存放到仓库，快去查看吧。"
}

func _ready() -> void:
	layer = 110
	name = "ExplorationGuide"
	guide = preload("res://scenes/ui/tutorial_guide.tscn").instantiate()
	guide.external_owner = true
	add_child(guide)
	guide.remove_from_group("tutorial_guide")
	guide.dialog.set_process_input(false)
	guide.dialog.set_process_unhandled_input(false)
	guide.dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide.dialog_done.connect(_read_done)

func state() -> Dictionary:
	var value: Variant = SaveManager._state.get(KEY, {})
	if not value is Dictionary or value.is_empty(): return {}
	if value.get("step", "") not in ["recipe","source","source_close","entrance","explore","warehouse","done"]: return {}
	if not value.get("seen", {}) is Dictionary or not value.get("banked", {}) is Dictionary: return {}
	var data: Dictionary = value.duplicate(true)
	if not data.get("revision",0) == 2:
		var old: Dictionary = data.get("seen",{})
		for pair in [["04_power","05_power"],["05_absorb","06_absorb"],["06_food","07_capture"],["08_bag","13_bag"],["10_warehouse","18_return"]]:
			if old.get(pair[0],false): data.seen[pair[1]] = true
		data.revision = 2
	return data

func _save_step(step: String) -> bool:
	var previous: Dictionary = SaveManager._state.duplicate(true)
	var data := state()
	data.step = step
	SaveManager._state[KEY] = data
	if SaveManager.save(): return true
	SaveManager._state = previous
	guide.show()
	guide.show_toast("教学进度未保存，请按 E 重试")
	pending_save = func():
		if _save_step(step): _clear()
	return false

func _seen(id: String) -> bool:
	return bool(state().get("seen", {}).get(id, false))

func _mark(id: String) -> bool:
	if id == FREEZER_NOTICE:
		if SaveManager.acknowledge_freezer_notice(): return true
		guide.show_toast("解锁提示进度未保存，请按 E 重试")
		return false
	var previous: Dictionary = SaveManager._state.duplicate(true)
	var data := state()
	if not data.has("seen"): data.seen = {}
	data.seen[id] = true
	SaveManager._state[KEY] = data
	if SaveManager.save(): return true
	SaveManager._state = previous
	guide.show_toast("教学进度未保存，请按 E 重试")
	return false

func _player() -> Node:
	return maze.player if is_instance_valid(maze) else restaurant._player

func _rect(target: Control) -> Rect2:
	return target.get_global_transform_with_canvas() * target.get_meta("lesson_rect", Rect2(Vector2.ZERO, target.size))

func _focus(nodes: Array) -> void:
	targets.clear()
	for node in nodes:
		if is_instance_valid(node) and node is Control: targets.append(node)

func _restore_targets() -> void:
	if glow_tween != null:
		glow_tween.kill()
		glow_tween = null
	for glow in operation_glows:
		glow.queue_free()
	operation_glows.clear()
	for target in operation_focus_styles:
		if is_instance_valid(target):
			if operation_focus_styles[target] != null:
				target.add_theme_stylebox_override("focus", operation_focus_styles[target])
			else:
				target.remove_theme_stylebox_override("focus")
	operation_focus_styles.clear()
	for shade in operation_shades:
		if is_instance_valid(shade): shade.color.a = operation_shades[shade]
	operation_shades.clear()
	targets.clear()

func _start_operation_glow() -> void:
	for target in allowed:
		if target is BaseButton:
			operation_focus_styles[target] = target.get_theme_stylebox("focus") if target.has_theme_stylebox_override("focus") else null
			target.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var glow := Panel.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.set_corner_radius_all(3)
		style.set_border_width_all(2)
		style.shadow_size = 10
		glow.add_theme_stylebox_override("panel", style)
		guide.add_child(glow)
		operation_glows.append(glow)
		# 只在强制操作期间移除业务窗的底色，保留其输入拦截节点。
		var parent := target.get_parent()
		while parent != null and not parent is CanvasLayer:
			for child in parent.get_children():
				if child is ColorRect and child.anchor_right == 1.0 and child.anchor_bottom == 1.0:
					if not operation_shades.has(child): operation_shades[child] = child.color.a
					child.color.a = 0.0
			parent = parent.get_parent()
	_set_operation_glow(1.0)
	glow_tween = create_tween().set_loops()
	glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_method(_set_operation_glow, 1.0, 0.4, 0.55)
	glow_tween.tween_method(_set_operation_glow, 0.4, 1.0, 0.55)

func _set_operation_glow(strength: float) -> void:
	for glow in operation_glows:
		var style := glow.get_theme_stylebox("panel") as StyleBoxFlat
		style.shadow_color = Color(Color("#f4b83e"), 0.95 * strength)
		style.border_color = Color(Color("#f4b83e"), 0.55 * strength)

func _camera_focus(point: Vector2, factor := 1.3) -> void:
	camera = get_viewport().get_camera_2d()
	if not is_instance_valid(camera): return
	camera_state = {"position":camera.global_position,"zoom":camera.zoom,"process":camera.is_processing(),"physics":camera.is_physics_processing()}
	camera.set_process(false)
	camera.set_physics_process(false)
	# 将世界目标放到对白上方可视区域的中心。
	camera.global_position = point + Vector2(0,82.0/(camera.zoom.y*factor))
	camera.zoom *= factor
	if is_instance_valid(maze):
		var half := get_viewport().get_visible_rect().size / camera.zoom * 0.5
		camera.global_position = Vector2(clampf(point.x,half.x,Run.Roads.SIZE.x-half.x),clampf(point.y-75,half.y,Run.Roads.SIZE.y-half.y))
	camera.reset_smoothing()

func _restore_camera() -> void:
	if is_instance_valid(camera) and not camera_state.is_empty():
		camera.global_position = camera_state.position
		camera.zoom = camera_state.zoom
		camera.set_process(camera_state.process)
		camera.set_physics_process(camera_state.physics)
		camera.reset_smoothing()
	camera_state.clear()

func explain(id: String, text: String, nodes: Array, callback: Callable = Callable()) -> void:
	_clear()
	lesson_id = id
	reading = true
	after_read = callback
	locked_player = _player()
	if is_instance_valid(locked_player):
		old_locked = locked_player.input_locked
		old_physics = locked_player.is_physics_processing()
		locked_player.input_locked = true
		locked_player.set_physics_process(false)
	_focus(nodes)
	guide.show()
	guide.play_dialog("芽芽", [text], PORTRAIT)
	guide.dialog.set_process_input(false)
	guide.dialog.set_process_unhandled_input(false)
	guide.set_dim(0.72 if gate or reading else 0.0)
	hold_frames = 2

func _read_done() -> void:
	if not reading: return
	var callback := after_read
	var id := lesson_id
	if not _mark(id):
		pending_save = _read_done
		return
	_clear()
	if callback.is_valid(): callback.call()
	hold_frames = 2

func _clear() -> void:
	if reading and is_instance_valid(locked_player):
		locked_player.input_locked = old_locked
		locked_player.set_physics_process(old_physics)
	reading = false
	gate = false
	_release_motion()
	world_focus = Rect2()
	allowed.clear()
	if is_instance_valid(paused_attempt): paused_attempt.tutorial_paused = false
	paused_attempt = null
	_restore_targets()
	_restore_camera()
	if is_instance_valid(guide) and guide.is_inside_tree():
		guide.external_operation = false
		guide.external_cutouts.clear()
		guide.external_circles = false
		guide.finish_all()

func operation(id: String, text: String, nodes: Array) -> void:
	if lesson_id == id and gate: return
	_clear()
	lesson_id = id
	gate = true
	motion_player = _player()
	if is_instance_valid(motion_player):
		motion_physics = motion_player.is_physics_processing()
		motion_player.set_physics_process(false)
	for node in nodes:
		if is_instance_valid(node): allowed.append(node)
	_focus(nodes)
	guide.show()
	guide.external_operation = true
	_start_operation_glow()
	guide.setup({"hint":text})
	guide.set_dim(preload("res://scripts/ui/components/modal_style.gd").BACKDROP.a)
	for target in allowed:
		guide.external_cutouts.append(_rect(target))
	guide._sync_dialog_mask()

func _release_motion() -> void:
	if is_instance_valid(motion_player): motion_player.set_physics_process(motion_physics)
	motion_player = null

func _input(event: InputEvent) -> void:
	if not reading and not pending_save.is_valid() and (state().is_empty() or state().get("step", "") == "done"): return
	if hold_frames > 0:
		get_viewport().set_input_as_handled()
		return
	if pending_save.is_valid():
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("interact"):
			var retry := pending_save
			pending_save = Callable()
			retry.call()
		return
	if reading:
		get_viewport().set_input_as_handled()
		if guide.dialog._is_advance_event(event): guide.dialog._advance()
	elif gate:
		if event is InputEventMouse:
			for target in allowed:
				if is_instance_valid(target) and _rect(target).has_point(event.position):
					if event is InputEventMouseButton and event.pressed: _release_motion()
					return
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if hold_frames > 0: hold_frames -= 1
	if not is_instance_valid(guide): return
	guide.external_cutouts.clear()
	guide.external_circles = false
	if gate:
		for index in range(allowed.size()):
			var target := allowed[index]
			if is_instance_valid(target):
				# 九宫格按钮纹理四边有2像素透明留白；光框贴合可见边缘，点击范围不缩小。
				var rect := target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, target.size).grow(-2.0)
				operation_glows[index].position = rect.position
				operation_glows[index].size = rect.size
	if is_instance_valid(maze):
		var active: bool = not state().is_empty() and state().get("step","") != "done"
		maze.capture_flow.dialog.tutorial_only_yes = active and not _seen("07_capture")
		maze.capture_flow.attempt.tutorial_only_yes = active and not _seen("11_suppress")
	if is_instance_valid(maze) and reading and targets.has(maze.backpack_entry): maze.backpack_entry.show()
	guide.set_dim(0.72 if gate or reading else 0.0)
	if reading or pending_save.is_valid() or hold_frames > 0: return
	var data := state()
	if is_instance_valid(restaurant) and SaveManager.freezer_notice_pending() and (data.is_empty() or data.get("step", "") == "done"):
		if not TutorialManager.active and is_instance_valid(restaurant._player) and is_instance_valid(restaurant.customer_flow):
			if not restaurant._player.input_locked and restaurant._player.is_physics_processing() and not restaurant.customer_flow.busy and not restaurant.customer_flow._arrival_tutorial_busy:
				explain(FREEZER_NOTICE, FREEZER_LINE, [])
		return
	if data.is_empty() or data.get("step", "") == "done": return
	if is_instance_valid(restaurant): _restaurant_tick(str(data.get("step", "")))
	elif is_instance_valid(maze) and maze._entry_ready: _maze_tick(str(data.get("step", "")))

func _restaurant_tick(step: String) -> void:
	if not is_instance_valid(restaurant._player) or restaurant.customer_flow.busy: return
	# 餐厅说明等当前弹窗/来客镜头释放移动后再开始，避免保存另一流程的锁定态。
	if restaurant._player.input_locked or not restaurant._player.is_physics_processing() or restaurant.customer_flow._arrival_tutorial_busy: return
	if step == "recipe":
		if not _seen("01_recipe"):
			explain("01_recipe", LINES["01_recipe"], [], func(): _save_step("entrance"))
		else: _save_step("entrance")
	elif step in ["source", "source_close"]:
		# 旧版食材来源检查点不再依赖已删除的悬停/关闭节点。
		_save_step("entrance")
	elif step == "warehouse":
		if not _seen("18_return"):
			explain("18_return", LINES["18_return"], [], func(): _save_step("done"))
		else: _save_step("done")

func _maze_tick(step: String) -> void:
	var flow: Node = maze.capture_flow
	var run := Run.snapshot(SaveManager)
	if not Run.valid(run) or not run.get("active",false): return
	if step in ["recipe", "source", "source_close", "entrance"]:
		if _save_step("explore"): return
	if flow.dialog.visible and flow.dialog.flipping: return
	if not str(run.pending).is_empty():
		if flow.dialog.visible and flow.dialog.victory:
			if not _seen("06_absorb") and run.pending == "slime_1":
				explain("06_absorb", LINES["06_absorb"], [])
			elif _seen("06_absorb") and not _seen("07_capture"): operation("06_yes", "", [flow.dialog._confirm_button])
		elif flow.attempt.visible:
			var ui: Control = flow.attempt
			if ui.mode == "ready" and not _seen("11_suppress"):
				if not _seen("07_capture"):
					explain("07_capture", LINES["07_capture"], [])
				else: operation("07_yes", "", [ui.yes_button])
			elif ui.mode == "suppress" and not _seen("11_suppress"):
				explain("11_suppress", LINES["11_suppress"], [])
				paused_attempt = ui
				ui.tutorial_paused = true
			elif gate: _clear()
		return
	if gate: _clear()
	if not run.bag.is_empty() and not flow.busy and not _seen("13_bag"):
		if not bag_lesson_busy:
			_start_bag_lesson()

func _start_bag_lesson() -> void:
	bag_lesson_busy = true
	# 先建立教学状态但暂不显示对白，避免镜头移动过程中对白抢先出现。
	explain("13_bag", LINES["13_bag"], [])
	guide.hide_box()
	var target: Vector2 = maze.settlement_portal.global_position
	camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		camera_state = {"position":camera.global_position, "zoom":camera.zoom,
			"process":camera.is_processing(), "physics":camera.is_physics_processing()}
		camera.set_process(false)
		camera.set_physics_process(false)
		var half := get_viewport().get_visible_rect().size / (camera.zoom * 1.3) * 0.5
		var end_position: Vector2 = target
		if is_instance_valid(maze):
			end_position = Vector2(clampf(target.x, half.x, Run.Roads.SIZE.x-half.x),
				clampf(target.y-75, half.y, Run.Roads.SIZE.y-half.y))
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(camera, "global_position", end_position, 0.7)
		tween.tween_property(camera, "zoom", camera.zoom * 1.3, 0.7)
		await tween.finished
	if not is_inside_tree() or lesson_id != "13_bag":
		bag_lesson_busy = false
		return
	guide.play_dialog("芽芽", [LINES["13_bag"]], PORTRAIT)
	bag_lesson_busy = false

func _exit_tree() -> void:
	_clear()

## 非阅读阶段保持原业务入口可用，食谱不再是强制操作关卡。
func allows_world_interaction(_label: String) -> bool:
	return not reading and not pending_save.is_valid()

func allows_recipe() -> bool:
	return not reading and not pending_save.is_valid()

# 与血条使用同一目标选择器，在 slime_1 首次亮起血条时暂停讲解。
# 保留旧已读键，已有存档不会因触发时机调整而重播。
func before_combat(run: Dictionary) -> bool:
	if state().is_empty() or state().get("step", "") == "done": return false
	if reading or pending_save.is_valid(): return true
	if _seen("05_power"):
		if not _seen("05_switch") and int(state().get("combat_hits", 0)) >= 3:
			explain("05_switch", LINES["05_switch"], [])
			return true
		return false
	if Run.Combat.select_target(run, maze.player.position) != "slime_1": return false
	if reading: return true
	maze.toast_label.dismiss()
	explain("05_power", LINES["05_power"], [])
	return true
