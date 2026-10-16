extends Node2D
## 首段探索。史莱姆暂时只展示爬行动画，待正式战斗流程完成后接入。
const Roads := preload("res://data/maze/entry_roads.gd")
const Player := preload("res://scripts/maze/maze_player.gd")
const FollowCamera := preload("res://scripts/maze/maze_camera.gd")
const MAP := preload("res://assets/maps/maze_entry.png")
const Confirmation := preload("res://scripts/ui/components/destination_confirmation.gd")
const Toast := preload("res://scripts/ui/components/feedback_toast.gd")
const WorldPrompt := preload("res://scripts/ui/components/world_interaction_prompt.gd")
const Transition := preload("res://scripts/ui/components/scene_transition.gd")
const ChestCatalog := preload("res://data/maze/entry_chests.gd")
const ExplorationChest := preload("res://scripts/maze/exploration_chest.gd")
const DigCatalog := preload("res://data/maze/entry_dig_sites.gd")
const ExplorationDigSite := preload("res://scripts/maze/exploration_dig_site.gd")
const LootModal := preload("res://scripts/ui/components/loot_modal.gd")
const SlimeEncounter := preload("res://scripts/maze/slime_encounter.gd")
const MazeMap := preload("res://scripts/ui/components/maze_map.gd")
const TaskTracker := preload("res://scripts/ui/order_tracking.gd")
const ResourceCounter := preload("res://scripts/ui/components/resource_counter.gd")
const WhiteTigerElder := preload("res://scripts/maze/white_tiger_elder.gd")
const YufengSaliaEncounter := preload("res://scripts/maze/yufeng_salia_encounter.gd")
var gold_counter: ResourceCounter
var map_ui: Control
var task_tracker: Control
var _task_host: Control
var _tasks_blocked := false
var _prompt_host: Control
var _resource_prompt_anchors: Array[Dictionary] = []
var slime: Node2D
var chests: Array[Node2D] = []
var chest_target: Node2D
var dig_sites: Array[Node2D] = []
var dig_target: Node2D
var loot_modal: Control
var _loot_locked_before := false
var _loot_physics_before := true
var player: Node2D
var camera: Camera2D
var toast_label: Toast
var confirmation: Confirmation
var entrance_prompt: WorldPrompt
var workshop_prompt: WorldPrompt
var _destination := ""
var _locked_before := false
var _physics_before := true
var _entry_retry_seconds := 0.0
var last_message := ""
var trigger_counts: Dictionary = {}
var _inside: Dictionary = {}
var _last_position := Vector2.ZERO
var _saved_position := Vector2.ZERO
var _idle_time := 0.0
var _save_time := 0.0
var _entry_ready := false
var _busy := false
var _interact_armed := false
var _previous_auto_quit := true
var _arrival_toast_shown := false
var elder: Node2D
var yufeng_salia: Node2D
var _ui_root: Control
var backpack_entry: Button
var backpack_warehouse: Control
var _backpack_locked_before := false
var _backpack_physics_before := true
var first_slime_flow: Node

func _ready() -> void:
	add_to_group("maze_entry")
	var background := Sprite2D.new()
	background.texture = MAP
	background.centered = false
	add_child(background)
	player = Player.new()
	player.name = "Player"
	var saved := SaveManager.maze_exploration_state()
	player.position = Vector2(saved.position[0], saved.position[1]) if saved.region == "maze_entry" else Roads.SPAWN
	add_child(player)
	camera = FollowCamera.new()
	camera.name = "Camera2D"
	camera.add_to_group("maze_camera")
	camera.target = player
	add_child(camera)
	elder = WhiteTigerElder.new()
	elder.name = "WhiteTigerElder"
	add_child(elder)
	yufeng_salia = YufengSaliaEncounter.new()
	yufeng_salia.name = "YufengSaliaEncounter"
	add_child(yufeng_salia)
	# 同层先画爷爷、后画主角；只调整二者的遮挡顺序，不改变道具层级。
	move_child(elder, player.get_index())
	_build_ui()
	_build_chests()
	_build_dig_sites()
	slime = SlimeEncounter.new()
	add_child(slime)
	_last_position = player.position
	_saved_position = player.position
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_interact_armed = not Input.is_action_pressed("interact")
	_commit_entry()
	yufeng_salia.attach(player, camera, _ui_root)
	first_slime_flow = preload("res://scripts/maze/first_slime_flow.gd").new()
	add_child(first_slime_flow)
	first_slime_flow.attach(self)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 65
	add_child(layer)
	var root := Control.new()
	_ui_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SproutTheme.make_theme()
	layer.add_child(root)
	entrance_prompt = WorldPrompt.new()
	root.add_child(entrance_prompt)
	entrance_prompt.configure("前往餐厅", Roads.ENTRANCE + Vector2(13, -55))
	entrance_prompt.activated.connect(_open_confirmation.bind("餐厅"))
	workshop_prompt = WorldPrompt.new()
	root.add_child(workshop_prompt)
	workshop_prompt.configure("前往水轮工坊", Roads.GATE + Vector2(0, -45))
	workshop_prompt.activated.connect(_open_confirmation.bind("水轮工坊"))
	_task_host = Control.new()
	_task_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_task_host)
	_task_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	task_tracker = TaskTracker.new()
	_task_host.add_child(task_tracker)
	gold_counter = ResourceCounter.new()
	gold_counter.name = "GoldCounter"
	gold_counter.configure(ResourceCounter.GOLD)
	task_tracker.add_child(gold_counter)
	_sync_gold_counter()
	map_ui = MazeMap.new()
	map_ui.maze = self
	root.add_child(map_ui)
	backpack_entry = Button.new()
	backpack_entry.name = "BackpackEntry"
	backpack_entry.tooltip_text = "背包"
	backpack_entry.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backpack_entry.expand_icon = true
	backpack_entry.add_theme_constant_override("icon_max_width", 56)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		backpack_entry.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	root.add_child(backpack_entry)
	backpack_entry.icon = preload("res://scripts/ui/components/backpack_reward.gd").entry_texture()
	backpack_entry.custom_minimum_size = Vector2(64, 64)
	backpack_entry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	backpack_entry.offset_left = 16
	backpack_entry.offset_right = 80
	backpack_entry.offset_top = -80
	backpack_entry.offset_bottom = -16
	var backpack_shadow := Panel.new()
	backpack_shadow.name = "BackpackShadow"
	backpack_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backpack_shadow.show_behind_parent = true
	backpack_entry.add_child(backpack_shadow)
	backpack_shadow.position = Vector2(8,8)
	backpack_shadow.size = Vector2(48,48)
	var backpack_shadow_style := StyleBoxFlat.new()
	backpack_shadow_style.bg_color = Color.TRANSPARENT
	backpack_shadow_style.set_corner_radius_all(24)
	backpack_shadow_style.shadow_color = Color(0.20,0.16,0.10,0.18)
	backpack_shadow_style.shadow_size = 5
	backpack_shadow_style.shadow_offset = Vector2(0,2)
	backpack_shadow.add_theme_stylebox_override("panel",backpack_shadow_style)
	backpack_entry.hide()
	backpack_entry.pressed.connect(_open_backpack)
	if is_instance_valid(elder):
		elder.attach_ui(root)
	# 树顺序同时保证绘制与鼠标命中优先级，不能只提高 z_index。
	_prompt_host = Control.new()
	_prompt_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_host)
	_prompt_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entrance_prompt.reparent(_prompt_host,false)
	workshop_prompt.reparent(_prompt_host,false)
	RenderingServer.frame_pre_draw.connect(_place_resource_prompts)
	toast_label = Toast.attach_to(root)
	confirmation = Confirmation.new()
	root.add_child(confirmation)
	confirmation.confirmed.connect(_confirm_destination)
	confirmation.cancelled.connect(_close_confirmation)
	loot_modal = LootModal.new()
	root.add_child(loot_modal)
	loot_modal.closed.connect(_close_loot)
	backpack_warehouse = preload("res://scripts/ui/warehouse_modal.gd").new()
	root.add_child(backpack_warehouse)
	backpack_warehouse.cancelled.connect(_close_backpack)

func _sync_gold_counter() -> void:
	gold_counter.set_value(SaveManager.gold_balance())
	gold_counter.show()
	var entry: Rect2 = task_tracker.entry_rect()
	gold_counter.position = Vector2(entry.end.x + 20.0, entry.get_center().y - gold_counter.get_combined_minimum_size().y * 0.5)

func _build_chests() -> void:
	for config in ChestCatalog.all():
		if SaveManager.is_chest_claimed(config.id):
			continue
		var chest := ExplorationChest.new()
		chest.chest_id = config.id
		chest.position = config.position
		add_child(chest)
		move_child(chest, player.get_index())
		chests.append(chest)
		_lift_resource_prompt(chest)

func _build_dig_sites() -> void:
	for config in DigCatalog.all():
		if SaveManager.is_dig_site_claimed(config.id):
			continue
		var site := ExplorationDigSite.new()
		site.site_id = config.id
		site.position = config.position
		add_child(site)
		move_child(site, player.get_index())
		dig_sites.append(site)
		_lift_resource_prompt(site)

func _lift_resource_prompt(source: Node2D) -> void:
	var prompt: Sprite2D = source.prompt
	_resource_prompt_anchors.append({"source":source,"prompt":prompt,"local":prompt.transform})
	prompt.reparent(_prompt_host,false)

func _place_resource_prompts() -> void:
	for anchor in _resource_prompt_anchors:
		if is_instance_valid(anchor.source) and is_instance_valid(anchor.prompt):
			# 保留原偏移、尺寸与镜头缩放，仅改变所在界面层。
			anchor.prompt.global_transform = anchor.source.get_global_transform_with_canvas() * anchor.local

func _update_chest_target() -> void:
	chest_target = null
	dig_target = null
	var nearest := ChestCatalog.INTERACT_RADIUS
	var available: bool = _entry_ready and not _busy and not player.input_locked and not confirmation.visible
	if available and SaveManager.chest_reward_state_valid():
		for chest in chests:
			if not is_instance_valid(chest) or not chest.visible:
				continue
			var distance := player.position.distance_to(chest.position)
			if distance <= nearest:
				nearest = distance
				chest_target = chest
	if available and SaveManager.dig_reward_state_valid():
		for site in dig_sites:
			if not is_instance_valid(site) or not site.visible:
				continue
			var distance := player.position.distance_to(site.position)
			if distance <= minf(nearest, DigCatalog.INTERACT_RADIUS):
				nearest = distance
				dig_target = site
				chest_target = null
	for chest in chests:
		if is_instance_valid(chest):
			chest.set_targeted(chest == chest_target)
	for site in dig_sites:
		if is_instance_valid(site):
			site.set_targeted(site == dig_target)

func _open_chest(chest: Node2D) -> void:
	_open_loot(chest, false)

func _open_dig_site(site: Node2D) -> void:
	_open_loot(site, true)

func _open_loot(source: Node2D, is_dig: bool) -> void:
	if not _entry_ready or _busy or player.input_locked or confirmation.visible:
		return
	_update_chest_target()
	if source != (dig_target if is_dig else chest_target):
		return
	_loot_locked_before = player.input_locked
	_loot_physics_before = player.is_physics_processing()
	_busy = true
	player.input_locked = true
	player.set_physics_process(false)
	_update_chest_target()
	_update_prompts()
	var result := SaveManager.claim_exploration_dig_site(source.site_id, player.position) if is_dig else SaveManager.claim_exploration_chest(source.chest_id, player.position)
	if not result.success:
		_busy = false
		player.input_locked = _loot_locked_before
		player.set_physics_process(_loot_physics_before)
		show_toast("挖掘保存失败，未领取木材；请松开 E 后重试" if is_dig else "宝箱保存失败，未领取金币；请松开 E 后重试")
		_update_chest_target()
		_update_prompts()
		return
	source.hide()
	map_ui.refresh_resources()
	_saved_position = player.position
	toast_label.dismiss()
	if is_dig:
		var items: Array[Dictionary] = [{"name": "木材", "quantity": result.amount, "icon": ExplorationDigSite.wood_texture()}]
		loot_modal.show_items(items)
	else:
		loot_modal.show_reward(result.amount, result.total)

func _close_loot() -> void:
	_busy = false
	player.input_locked = _loot_locked_before or not _entry_ready
	player.set_physics_process(_loot_physics_before)
	_interact_armed = not Input.is_action_pressed("interact")
	get_viewport().gui_release_focus()
	_update_chest_target()
	_update_prompts()

func _near_destination() -> String:
	if player.position.distance_to(Roads.ENTRANCE) < 43.0:
		return "餐厅"
	if player.position.distance_to(Roads.GATE) < 31.0:
		return "水轮工坊"
	return ""

func _update_prompts() -> void:
	var available: bool = _entry_ready and not _busy and not player.input_locked and not confirmation.visible
	var target := _near_destination() if available else ""
	entrance_prompt.visible = target == "餐厅"
	workshop_prompt.visible = target == "水轮工坊"

func _open_confirmation(destination: String) -> void:
	if not _entry_ready or _busy or player.input_locked or confirmation.visible or _near_destination() != destination:
		return
	_destination = destination
	_locked_before = player.input_locked
	_physics_before = player.is_physics_processing()
	player.input_locked = true
	player.set_physics_process(false)
	toast_label.dismiss()
	confirmation.open_destination(destination)
	_update_prompts()

func _close_confirmation() -> void:
	if not confirmation.visible:
		return
	confirmation.hide()
	player.input_locked = _locked_before
	player.set_physics_process(_physics_before)
	_interact_armed = not Input.is_action_pressed("interact")
	_update_prompts()

func _confirm_destination() -> void:
	if not confirmation.visible:
		return
	var destination := _destination
	_close_confirmation()
	if destination == "餐厅":
		return_to_restaurant()
	elif destination == "水轮工坊":
		trigger_counts["gate"] = int(trigger_counts.get("gate", 0)) + 1
		show_toast("当前区域未开放，以后再来探索吧~")

func _commit_entry() -> void:
	var result := SaveManager.record_maze_location("maze_entry", player.position)
	_entry_ready = result.success
	player.input_locked = not _entry_ready
	if result.success:
		toast_label.dismiss()
		_saved_position = player.position
	else:
		_entry_retry_seconds = 5.0
		show_toast("探索进度保存失败，正在自动重试", 5.0)

func _process(delta: float) -> void:
	_sync_gold_counter()
	if not _arrival_toast_shown and bool(SaveManager.restaurant_customers().get("arrival_notice", false)):
		show_toast("你有新顾客哦~")
		_arrival_toast_shown = true
	_sync_task_access()
	_update_chest_target()
	_update_prompts()
	if is_instance_valid(elder):
		elder.set_near(player.position.distance_to(elder.position) <= WhiteTigerElder.Config.INTERACT_RADIUS and not _busy and not confirmation.visible and not map_ui.expanded)
	if not _entry_ready:
		_entry_retry_seconds -= delta
		if _entry_retry_seconds <= 0.0:
			_commit_entry()
		return
	if _busy or confirmation.visible or map_ui.expanded or (is_instance_valid(elder) and elder.is_busy()):
		return
	_update_triggers()
	_save_time += delta
	if player.position.distance_to(_last_position) < 0.05:
		_idle_time += delta
	else:
		_idle_time = 0.0
	_last_position = player.position
	if player.position.distance_to(_saved_position) > 0.1 and (_save_time >= 5.0 or (_idle_time >= 0.6 and _save_time >= 1.0)):
		_save_position()

func _sync_task_access() -> void:
	var blocked: bool = _busy or yufeng_salia.is_busy() or not _entry_ready or confirmation.visible or map_ui.expanded or player.input_locked
	var collecting: bool = is_instance_valid(elder) and (elder.phase == "backpack_collect" or (elder.phase == "restoring" and elder.backpack_arrived))
	backpack_entry.visible = SaveManager.elder_backpack_unlocked() and (not blocked or collecting)
	backpack_entry.disabled = blocked
	if blocked == _tasks_blocked:
		return
	_tasks_blocked = blocked
	if blocked:
		task_tracker.collapse_details()
	_task_host.visible = not blocked
	task_tracker.set_process_input(not blocked)
	task_tracker._task_button.disabled = blocked

func _update_triggers() -> void:
	yufeng_salia.update_proximity()
	var zones := {"exit": player.position.x < 29.0, "yufeng_salia": player.position.distance_to(yufeng_salia.TRIGGER_POS) <= yufeng_salia.TRIGGER_RADIUS}
	for id in zones:
		if zones[id] and not _inside.get(id, false):
			trigger_counts[id] = int(trigger_counts.get(id, 0)) + 1
			match id:
				"exit": show_toast("分水庭区域制作中")
				"yufeng_salia":
					pass # 由update_proximity处理，避免保存失败或界面互斥消耗首次触发边沿。
		_inside[id] = zones[id]

func show_toast(message: String, seconds: float = 3.5) -> void:
	last_message = message
	toast_label.show_message(message, seconds)

func _unhandled_input(event: InputEvent) -> void:
	# 图形提示仍复用宝箱组件；命中检测在统一仲裁后进行，模态层可先消费点击。
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_update_chest_target()
		var target: Node2D = dig_target if is_instance_valid(dig_target) else chest_target
		if is_instance_valid(target) and target.prompt.is_visible_in_tree() \
				and target.prompt.get_rect().has_point(target.prompt.get_global_transform_with_canvas().affine_inverse() * event.position):
			get_viewport().set_input_as_handled()
			_open_loot(target, target == dig_target)
		return
	if event.is_action_released("interact"):
		_interact_armed = true
	if not _entry_ready or _busy or player.input_locked or map_ui.expanded or confirmation.visible or not event.is_action_pressed("interact") or event.is_echo():
		return
	# 出生时不使用此前确认入口按住的 E；先松开再新按。
	if not _interact_armed:
		return
	_interact_armed = false
	get_viewport().set_input_as_handled()
	if is_instance_valid(elder) and player.position.distance_to(elder.position) <= WhiteTigerElder.Config.INTERACT_RADIUS:
		elder.interact()
		return
	_update_chest_target()
	if is_instance_valid(dig_target):
		_open_dig_site(dig_target)
		return
	if is_instance_valid(chest_target):
		_open_chest(chest_target)
		return
	var destination := _near_destination()
	if not destination.is_empty():
		_open_confirmation(destination)

func _save_position() -> bool:
	_save_time = 0.0
	var result := SaveManager.record_maze_location("maze_entry", player.position)
	if result.success:
		_saved_position = player.position
	else:
		# 不逐帧重试，下一次自动重试至少间隔 5 秒。
		_save_time = -4.0
		show_toast("保存失败，已保留上次进度，稍后自动重试")
	return result.success

func return_to_restaurant() -> void:
	if _busy or yufeng_salia.is_busy() or player.input_locked or (is_instance_valid(elder) and elder.is_busy()) or not _entry_ready or Transition.is_active(get_tree()):
		return
	var destination := load(SaveManager.RESTAURANT_SCENE) as PackedScene
	if destination == null:
		show_toast("餐厅加载失败，请重试")
		return
	var result := SaveManager.record_maze_location("restaurant", player.position)
	if not result.success:
		show_toast("返回进度未保存，请重试")
		return
	_busy = true
	player.input_locked = true
	get_tree().set_meta("restaurant_return_from_maze", true)
	var error := await Transition.change_scene(get_tree(), destination)
	if error != OK:
		get_tree().remove_meta("restaurant_return_from_maze")
		_busy = false
		player.input_locked = false
		SaveManager.record_maze_location("maze_entry", player.position)
		show_toast("餐厅加载失败，请重试")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(player):
		if not _entry_ready or _save_position():
			get_tree().quit()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = _previous_auto_quit

func _open_backpack() -> void:
	if not SaveManager.elder_backpack_unlocked() or not _entry_ready or _busy or player.input_locked or map_ui.expanded or confirmation.visible: return
	_backpack_locked_before = player.input_locked
	_backpack_physics_before = player.is_physics_processing()
	_busy = true
	player.input_locked = true
	player.set_physics_process(false)
	toast_label.dismiss()
	backpack_warehouse.open_backpack()

func _close_backpack() -> void:
	player.input_locked = _backpack_locked_before
	player.set_physics_process(_backpack_physics_before)
	_busy = false
	_interact_armed = not Input.is_action_pressed("interact")
