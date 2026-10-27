extends Node2D
## 首段探索：靠近魔物判定战力，捕获物经出口带回餐厅。
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
const SettlementExit := preload("res://data/maze/settlement_exit.gd")
const SettlementPortal := preload("res://scripts/maze/settlement_portal.gd")
const LootModal := preload("res://scripts/ui/components/loot_modal.gd")
const CaptureRun := preload("res://scripts/maze/capture_run.gd")
const MazeMap := preload("res://scripts/ui/components/maze_map.gd")
const TaskTracker := preload("res://scripts/ui/order_tracking.gd")
const ResourceCounter := preload("res://scripts/ui/components/resource_counter.gd")
const WhiteTigerElder := preload("res://scripts/maze/white_tiger_elder.gd")
const RegionRoutes = preload("res://data/maze/region_routes.gd")
const SaltPool = preload("res://data/maze/salt_pool_roads.gd")
const MossPool = preload("res://data/maze/moss_pool_roads.gd")
const Fenshui := preload("res://data/maze/fenshui_roads.gd")
const FenshuiGates = preload("res://data/maze/fenshui_gates.gd")
var fenshui_gate_prompts: Dictionary = {}
@export var region_id := "maze_entry"
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
var exit_prompt: WorldPrompt
var settlement_prompt: WorldPrompt
var salt_moss_prompt: WorldPrompt
var settlement_portal: Node2D
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
var _entry_aborted := false
var _busy := false
var _interact_armed := false
var _previous_auto_quit := true
var _arrival_toast_shown := false
var elder: Node2D
var exploration_guide: Node
var yf_encounter: Node2D
var capture_flow: Node
var _ui_root: Control
var bento_entry: Button
var bento_modal: Control
var _bento_prior_lock := false
var _bento_prior_physics := true
var backpack_entry: Button
var backpack_warehouse: Control
var _backpack_locked_before := false
var _backpack_physics_before := true

func _ready() -> void:
	add_to_group("maze_entry")
	var background := Sprite2D.new()
	background.texture = load("res://assets/maps/fenshui_fences.png") if region_id == "fenshui" else MAP
	if region_id == "salt_pool": background.texture = load("res://assets/maps/salt_pool.png")
	if region_id == "moss_pool": background.texture = load("res://assets/maps/moss_pool.png")
	if region_id == "fenshui": background.scale = Fenshui.SIZE / background.texture.get_size()
	background.centered = false
	add_child(background)
	player = Player.new()
	player.name = "Player"
	var saved := SaveManager.maze_exploration_state()
	player.terrain = SaveManager.maze_terrain(region_id).new()
	player.position = Vector2(saved.position[0], saved.position[1]) if saved.region == region_id else player.terrain.SPAWN
	if region_id == "maze_entry" and player.position.x < SettlementExit.BLOCK_X + Roads.FOOT_RADIUS:
		player.position = SettlementExit.FRONT
	add_child(player)
	camera = FollowCamera.new()
	camera.name = "Camera2D"
	camera.add_to_group("maze_camera")
	camera.target = player
	camera.map_size = player.terrain.SIZE
	add_child(camera)
	if region_id == "maze_entry":
		elder = WhiteTigerElder.new()
		elder.name = "WhiteTigerElder"
		add_child(elder)
	# 同层先画爷爷、后画主角；只调整二者的遮挡顺序，不改变道具层级。
	if is_instance_valid(elder): move_child(elder, player.get_index())
	_build_ui()
	_build_chests()
	_build_dig_sites()
	if region_id == "maze_entry":
		settlement_portal = SettlementPortal.new()
		settlement_portal.position = SettlementExit.POSITION
		add_child(settlement_portal)
	elif region_id in ["fenshui","salt_pool","moss_pool"]:
		var marker = preload("res://scripts/maze/spawn_portal.gd").new()
		marker.name = "SpawnPortal"
		marker.position = RegionRoutes.route(region_id).marker
		add_child(marker)
	if region_id == "fenshui":
		var portal := SettlementPortal.new()
		portal.position = SaltPool.FENSHUI_PORTAL
		add_child(portal)
	if region_id == "salt_pool":
		var effects = preload("res://scripts/maze/salt_ground_effects.gd").new()
		effects.name = "SaltGroundEffects"
		effects.player = player
		add_child(effects)
		move_child(effects,player.get_index())
	if region_id in ["salt_pool","moss_pool"]:
		var link_portal := SettlementPortal.new()
		link_portal.name = "SaltMossPortal"
		link_portal.position = MossPool.SALT_SIDE_MARKER if region_id == "salt_pool" else MossPool.SALT_MARKER
		add_child(link_portal)
	_last_position = player.position
	for portal in get_tree().get_nodes_in_group("maze_portals"):
		if portal.get_parent() == self: player.portal_obstacles.append(portal)
	_saved_position = player.position
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_interact_armed = not Input.is_action_pressed("interact")
	_commit_entry()
	capture_flow = preload("res://scripts/maze/capture_flow.gd").new()
	add_child(capture_flow)
	capture_flow.attach(self)
	if region_id == "fenshui":
		yf_encounter=preload("res://scripts/maze/yufeng_salia_encounter.gd").new()
		add_child(yf_encounter)
		yf_encounter.attach(self)
	if region_id == "maze_entry":
		exploration_guide = preload("res://scripts/ch2_exploration_guide.gd").new()
		exploration_guide.maze = self
		add_child(exploration_guide)

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
	var stamina_counter := preload("res://scripts/ui/components/stamina_counter.gd").new()
	root.add_child(stamina_counter)
	# 体力向右靠近小地图，保留80像素偏移。
	stamina_counter.offset_left -= 80
	stamina_counter.offset_right -= 80
	entrance_prompt = WorldPrompt.new()
	root.add_child(entrance_prompt)
	entrance_prompt.configure("前往"+str(RegionRoutes.route(region_id).previous_name) if region_id != "maze_entry" else "前往餐厅", player.terrain.ENTRANCE + Vector2(0,-34))
	entrance_prompt.activated.connect(_open_confirmation.bind(str(RegionRoutes.route(region_id).previous_name) if region_id != "maze_entry" else "餐厅"))
	workshop_prompt = WorldPrompt.new()
	root.add_child(workshop_prompt)
	workshop_prompt.configure("前往水轮工坊", Roads.GATE + Vector2(0, -45))
	workshop_prompt.activated.connect(_open_confirmation.bind("水轮工坊"))
	exit_prompt = WorldPrompt.new()
	root.add_child(exit_prompt)
	exit_prompt.configure("携带食材返回餐厅",Roads.EXIT+Vector2(50,-50))
	exit_prompt.activated.connect(_open_confirmation.bind("出口"))
	settlement_prompt = WorldPrompt.new()
	root.add_child(settlement_prompt)
	settlement_prompt.configure("前往盐池" if region_id == "fenshui" else "前往分水庭", (SaltPool.FENSHUI_PORTAL if region_id == "fenshui" else SettlementExit.POSITION) + Vector2(0,-34))
	settlement_prompt.activated.connect(_open_confirmation.bind("下一区域"))
	if region_id in ["salt_pool","moss_pool"]:
		salt_moss_prompt = WorldPrompt.new()
		root.add_child(salt_moss_prompt)
		var link_name := "青苔池" if region_id == "salt_pool" else "盐池"
		var link_point: Vector2 = MossPool.SALT_SIDE_MARKER if region_id == "salt_pool" else MossPool.SALT_MARKER
		salt_moss_prompt.configure("前往"+link_name,link_point+Vector2(0,-34))
		salt_moss_prompt.activated.connect(_open_confirmation.bind(link_name))
	if region_id == "fenshui":
		for gate in FenshuiGates.GATES:
			var prompt := WorldPrompt.new()
			root.add_child(prompt)
			prompt.configure("前往"+gate.name,FenshuiGates.center(gate)+Vector2(0,-30))
			prompt.activated.connect(_open_confirmation.bind(gate.name))
			fenshui_gate_prompts[gate.name] = prompt

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
	backpack_entry.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	preload("res://scripts/ui/components/entry_icon_shadow.gd").attach(backpack_entry,"BackpackShadow")
	backpack_entry.hide()
	backpack_entry.pressed.connect(_open_backpack)
	bento_entry = preload("res://scripts/ui/components/bento_modal.gd").make_entry(root)
	bento_entry.pressed.connect(_open_bento)
	bento_modal = preload("res://scripts/ui/components/bento_modal.gd").new()
	root.add_child(bento_modal)
	bento_modal.feedback.connect(show_toast)
	bento_modal.closed.connect(_close_bento)
	if is_instance_valid(elder):
		elder.attach_ui(root)
	# 树顺序同时保证绘制与鼠标命中优先级，不能只提高 z_index。
	_prompt_host = Control.new()
	_prompt_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_host)
	_prompt_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entrance_prompt.reparent(_prompt_host,false)
	workshop_prompt.reparent(_prompt_host,false)
	exit_prompt.reparent(_prompt_host,false)
	settlement_prompt.reparent(_prompt_host,false)
	if is_instance_valid(salt_moss_prompt): salt_moss_prompt.reparent(_prompt_host,false)
	RenderingServer.frame_pre_draw.connect(_place_resource_prompts)
	toast_label = Toast.attach_to(root)
	confirmation = Confirmation.new()
	root.add_child(confirmation)
	confirmation.confirmed.connect(_confirm_destination)
	confirmation.cancelled.connect(_close_confirmation)
	confirmation.secondary_selected.connect(_finish_exploration_choice)
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
	for config in ChestCatalog.all(region_id):
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
	for config in DigCatalog.all(region_id):
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
	if region_id!="maze_entry" and CaptureRun.portal_combat_locked(SaveManager): available=false
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
		show_toast("挖掘保存失败，未领取物品；请松开 E 后重试" if is_dig else "宝箱保存失败，未领取金币；请松开 E 后重试")
		_update_chest_target()
		_update_prompts()
		return
	source.hide()
	map_ui.refresh_resources()
	_saved_position = player.position
	toast_label.dismiss()
	if is_dig:
		var item: String=result.get("item","wood")
		var food_catalog=preload("res://scripts/cooking/recipe_catalog.gd")
		var items: Array[Dictionary] = [{"name": "木材" if item=="wood" else food_catalog.get_ingredient(item).name, "quantity": result.amount, "icon": ExplorationDigSite.wood_texture() if item=="wood" else food_catalog.item_texture(item)}]
		loot_modal.show_items(items)
	else:
		loot_modal.show_reward(result.amount, result.total)

func show_mined_salt(amount: int) -> void:
	# 奖励已由采矿事务保存；这里只复用采集弹窗及输入恢复。
	_loot_locked_before = player.input_locked
	_loot_physics_before = player.is_physics_processing()
	_busy = true
	player.input_locked = true
	player.set_physics_process(false)
	_update_prompts()
	toast_label.dismiss()
	await get_tree().create_timer(0.45).timeout
	var catalog = preload("res://scripts/cooking/recipe_catalog.gd")
	var items: Array[Dictionary] = [{"name":"岩盐","quantity":amount,"icon":catalog.item_texture("rock_salt")}]
	loot_modal.show_items(items)
func _close_loot() -> void:
	_busy = false
	player.input_locked = _loot_locked_before or not _entry_ready
	player.set_physics_process(_loot_physics_before)
	_interact_armed = not Input.is_action_pressed("interact")
	get_viewport().gui_release_focus()
	_update_chest_target()
	_update_prompts()

func _near_destination() -> String:
	if region_id == "moss_pool":
		if player.position.distance_to(MossPool.SALT_MARKER)<80.0: return "盐池"
		return "分水庭" if player.position.distance_to(MossPool.ENTRANCE)<MossPool.INTERACT_RADIUS else ""
	if region_id == "salt_pool":
		if player.position.distance_to(MossPool.SALT_SIDE_MARKER)<80.0: return "青苔池"
		return "分水庭" if player.position.distance_to(SaltPool.ENTRANCE)<SaltPool.INTERACT_RADIUS else ""
	if region_id == "fenshui":
		if player.position.distance_to(SaltPool.FENSHUI_PORTAL)<65.0: return "下一区域"
		if player.position.distance_to(Fenshui.ENTRANCE)<Fenshui.INTERACT_RADIUS: return "枯水渠"
		for gate in FenshuiGates.GATES:
			if player.position.distance_to(FenshuiGates.center(gate)) < 70.0: return gate.name
		return ""
	if SettlementExit.can_bank(player.position):
		return "下一区域"
	if player.position.distance_to(Roads.ENTRANCE) < 43.0:
		return "餐厅"
	if player.position.distance_to(Roads.GATE) < 31.0:
		return "水轮工坊"
	return ""

func _update_prompts() -> void:
	var available: bool = _entry_ready and not _busy and not player.input_locked and not confirmation.visible
	var target := _near_destination() if available else ""
	entrance_prompt.visible = target in ["餐厅","枯水渠","分水庭"]
	workshop_prompt.visible = region_id == "maze_entry" and target == "水轮工坊"
	for destination in fenshui_gate_prompts:
		fenshui_gate_prompts[destination].visible = target == destination
	exit_prompt.visible = false
	settlement_prompt.visible = target == "下一区域"
	if is_instance_valid(salt_moss_prompt):
		salt_moss_prompt.visible = target == ("青苔池" if region_id == "salt_pool" else "盐池")

func _open_confirmation(destination: String) -> void:
	if CaptureRun.portal_combat_locked(SaveManager):
		show_toast("战斗中无法使用路标，请先脱离战斗")
		return
	if not _entry_ready or _busy or player.input_locked or confirmation.visible or _near_destination() != destination:
		return
	_destination = destination
	_locked_before = player.input_locked
	_physics_before = player.is_physics_processing()
	player.input_locked = true
	player.set_physics_process(false)
	toast_label.dismiss()
	if destination=="餐厅":
		confirmation.open_confirmation("放弃本趟探索返回餐厅？\n本趟捕获物将全部失去。","放弃并返回","继续探索")
	elif destination=="出口":
		confirmation.open_confirmation("携带本趟捕获食材返回餐厅？","带回食材","继续探索")
	elif destination=="下一区域":
		confirmation.open_region_choice("盐池" if region_id == "fenshui" else "分水庭")
	elif destination in ["枯水渠","分水庭"]:
		confirmation.open_region_choice(str(RegionRoutes.route(region_id).previous_name))
	elif destination == "青苔池":
		confirmation.open_region_choice("青苔池")
	elif destination == "盐池":
		confirmation.open_region_choice("盐池")
	else:
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

func _finish_exploration_choice() -> void:
	if not confirmation.visible: return
	var destination := _destination
	_close_confirmation()
	if destination in ["下一区域","枯水渠","分水庭","青苔池","盐池"]:
		return_to_restaurant(true)

func _confirm_destination() -> void:
	if not confirmation.visible:
		return
	var destination := _destination
	_close_confirmation()
	if destination == "餐厅":
		return_to_restaurant()
	elif destination == "出口":
		return_to_restaurant(true)
	elif destination == "下一区域":
		if region_id == "fenshui":
			travel_region("salt_pool", SaltPool.SPAWN)
		else:
			travel_region("fenshui", Fenshui.SPAWN)
	elif destination in ["枯水渠","分水庭"]:
		travel_region(RegionRoutes.route(region_id).previous_id, RegionRoutes.route(region_id).return_point)
	elif destination == "青苔池":
		travel_region("moss_pool", MossPool.SALT_ARRIVAL if region_id == "salt_pool" else MossPool.SPAWN)
	elif destination == "盐池":
		travel_region("salt_pool", MossPool.SALT_SIDE_ARRIVAL)
	elif destination in fenshui_gate_prompts or destination == "水轮工坊":
		trigger_counts["gate"] = int(trigger_counts.get("gate", 0)) + 1
		show_toast("当前区域未开放，以后再来探索吧~")

func travel_region(destination_id: String, point: Vector2) -> void:
	if CaptureRun.portal_combat_locked(SaveManager):
		show_toast("战斗中无法使用路标，请先脱离战斗")
		return
	if _busy or not _entry_ready or player.input_locked or Transition.is_active(get_tree()): return
	var scene_path: String = {"moss_pool":"res://scenes/maze_moss_pool.tscn","salt_pool":"res://scenes/maze_salt_pool.tscn","fenshui":"res://scenes/maze_fenshui.tscn"}.get(destination_id,SaveManager.MAZE_SCENE)
	var scene := load(scene_path) as PackedScene
	if scene == null: return
	var previous: Dictionary = SaveManager.get("_state").duplicate(true)
	var result := CaptureRun.change_region(SaveManager, destination_id, point)
	if not result.success:
		show_toast("区域进度保存失败，仍停留在当前区域")
		push_warning("区域切换拒绝："+str(result))
		return
	_busy = true
	player.input_locked = true
	var error := await Transition.change_scene(get_tree(),scene)
	if error != OK:
		SaveManager.set("_state",previous)
		SaveManager.save()
		_busy = false
		player.input_locked = false
		show_toast("区域加载失败，请重试")

func _commit_entry() -> void:
	var requested := SaveManager._maze_entry_pending
	var result := CaptureRun.begin(SaveManager, player.position, region_id)
	_entry_ready = result.success
	player.input_locked = not _entry_ready
	if result.success:
		toast_label.dismiss()
		_saved_position = player.position
	else:
		if requested:
			SaveManager.cancel_maze_entry()
			_entry_aborted = true
			_return_failed_entry.call_deferred()
			return
		_entry_retry_seconds = 5.0
		show_toast("探索进度保存失败，正在自动重试", 5.0)

func _return_failed_entry() -> void:
	show_toast("探索保存失败，返回餐厅重新选择队伍", 5.0)
	while Transition.is_active(get_tree()): await get_tree().process_frame
	await Transition.change_scene(get_tree(), load(SaveManager.RESTAURANT_SCENE) as PackedScene)

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
		if _entry_aborted: return
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
	var blocked: bool = _busy or not _entry_ready or confirmation.visible or map_ui.expanded or player.input_locked
	var collecting: bool = false
	backpack_entry.visible = _entry_ready and (not blocked or collecting)
	backpack_entry.disabled = blocked
	# 解锁蒙层展示时尚不显示入口；确认后仅供飞入动画接收图标。
	var bento_show: bool = is_instance_valid(yf_encounter) and yf_encounter.phase == "bento_fly"
	bento_entry.visible = preload("res://scripts/restaurant/bento_store.gd").unlocked(SaveManager) and _entry_ready and (not blocked or bento_show)
	bento_entry.disabled = blocked
	if blocked == _tasks_blocked:
		return
	_tasks_blocked = blocked
	if blocked:
		task_tracker.collapse_details()
	_task_host.visible = not blocked
	task_tracker.set_process_input(not blocked)
	task_tracker._task_button.disabled = blocked

func _update_triggers() -> void:
	pass # 出口由现有通行确认组件处理；不再触发御风、萨莉亚剧情。

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
	var result := SaveManager.record_maze_location(region_id, player.position)
	if result.success:
		_saved_position = player.position
	else:
		# 不逐帧重试，下一次自动重试至少间隔 5 秒。
		_save_time = -4.0
		show_toast("保存失败，已保留上次进度，稍后自动重试")
	return result.success

func return_to_restaurant(bank: bool = false) -> void:
	if _busy or player.input_locked or (is_instance_valid(elder) and elder.is_busy()) or not _entry_ready or Transition.is_active(get_tree()):
		return
	var destination := load(SaveManager.RESTAURANT_SCENE) as PackedScene
	if destination == null:
		show_toast("餐厅加载失败，请重试")
		return
	var previous: Dictionary = SaveManager.get("_state").duplicate(true)
	var result := CaptureRun.finish(SaveManager,bank,player.position)
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
		SaveManager.set("_state",previous)
		SaveManager.save()
		show_toast("餐厅加载失败，请重试")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(player):
		if not _entry_ready or _save_position():
			get_tree().quit()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = _previous_auto_quit

func _open_backpack() -> void:
	if not _entry_ready or _busy or player.input_locked or map_ui.expanded or confirmation.visible: return
	_backpack_locked_before = player.input_locked
	_backpack_physics_before = player.is_physics_processing()
	_busy = true
	player.input_locked = true
	player.set_physics_process(false)
	toast_label.dismiss()
	backpack_warehouse.open_backpack(CaptureRun.snapshot(SaveManager).bag, true)

func _close_backpack() -> void:
	player.input_locked = _backpack_locked_before
	player.set_physics_process(_backpack_physics_before)
	_busy = false
	_interact_armed = not Input.is_action_pressed("interact")



func _open_bento() -> void:
	if not bento_entry.visible or player.input_locked or _busy: return
	if CaptureRun.portal_combat_locked(SaveManager):
		show_toast("战斗中无法使用便当盒")
		return
	_bento_prior_lock=player.input_locked
	_bento_prior_physics=player.is_physics_processing()
	player.input_locked=true
	player.set_physics_process(false)
	player.clear_combat_input()
	bento_modal.present(true)

func _close_bento() -> void:
	player.input_locked=_bento_prior_lock
	player.set_physics_process(_bento_prior_physics)
