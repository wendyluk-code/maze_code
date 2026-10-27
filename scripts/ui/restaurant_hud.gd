extends CanvasLayer
## 常驻声望；章后交互的提示和确认层。
const Confirmation := preload("res://scripts/ui/components/team_entry_modal.gd")
const Toast := preload("res://scripts/ui/components/feedback_toast.gd")
const Transition := preload("res://scripts/ui/components/scene_transition.gd")
const AdventurerHome := preload("res://scripts/ui/adventurer_home.gd")
const ResourceCounter := preload("res://scripts/ui/components/resource_counter.gd")
const RecipeBook := preload("res://scripts/ui/components/recipe_book_panel.gd")
const RecipeUnlock := preload("res://scripts/ui/components/recipe_unlock.gd")
const RecipeCatalog := preload("res://scripts/cooking/recipe_catalog.gd")
signal recipe_unlock_closed
var reputation_counter: ResourceCounter
var gold_counter: ResourceCounter
var reputation_label: Label
var toast_label: Toast
var confirmation: Confirmation
var question: Label
var confirm_button: SproutButton
var cancel_button: SproutButton
var _destination := ""
var _player: Node
var _locked_before := false
var _physics_before := true
var _player_lock_depth := 0
var _warehouse_open := false
var _cooking_open := false
var customer_flow: Node2D
var _recipe_entry: Button
var _recipe_book: Control
var _recipe_unlock: Control
var exploration_guide: Node
var discard_flow: Node
var bento_entry: Button
var bento_modal: Control
var freezer: Control

func _ready() -> void:
	name = "RestaurantHUD"
	layer = 65
	add_to_group("restaurant_hud")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SproutTheme.make_theme()
	add_child(root)
	var stamina_counter := preload("res://scripts/ui/components/stamina_counter.gd").new()
	root.add_child(stamina_counter)
	reputation_counter = ResourceCounter.new()
	reputation_counter.name = "ReputationCounter"
	reputation_counter.configure(ResourceCounter.REPUTATION)
	reputation_label = reputation_counter.value_label
	gold_counter = ResourceCounter.new()
	gold_counter.name = "GoldCounter"
	gold_counter.configure(ResourceCounter.GOLD)
	# 常驻声望归属任务层；确认框与toast仍保留在本HUD的模态层。
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker):
		tracker.add_child(reputation_counter)
		tracker.add_child(gold_counter)
	else:
		root.add_child(reputation_counter)
		root.add_child(gold_counter)
	_refresh_reputation()
	_build_recipe_entry(root)
	toast_label = Toast.attach_to(root)
	confirmation = Confirmation.new()
	root.add_child(confirmation)
	question = confirmation.question
	cancel_button = confirmation.cancel_button
	confirm_button = confirmation.confirm_button
	confirmation.cancelled.connect(_close_confirmation)
	confirmation.confirmed.connect(_confirm_destination)
	discard_flow = preload("res://scripts/restaurant/discard_flow.gd").new()
	discard_flow.hud = self
	root.add_child(discard_flow)
	freezer = preload("res://scripts/ui/components/freezer_modal.gd").new()
	root.add_child(freezer)
	freezer.closed.connect(_unlock_player)
	freezer.feedback.connect(show_toast)
	call_deferred("_connect_player")
	customer_flow = preload("res://scripts/restaurant/customer_flow.gd").new()
	customer_flow.hud = self
	get_parent().get_parent().add_child.call_deferred(customer_flow)
	exploration_guide = preload("res://scripts/ch2_exploration_guide.gd").new()
	exploration_guide.restaurant = self
	add_child(exploration_guide)

func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player):
		_player.interacted.connect(_on_interacted)
	var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
	if is_instance_valid(warehouse):
		warehouse.inspected.connect(_warehouse_closed)
		warehouse.cancelled.connect(_warehouse_closed)
		warehouse.claimed.connect(func(_result: Dictionary): _warehouse_closed())
	var cooking := get_tree().get_first_node_in_group("cooking_modal")
	if is_instance_valid(cooking):
		cooking.cancelled.connect(_cooking_closed)
		cooking.result_confirmed.connect(_on_cooking_result_confirmed)

func _process(_delta: float) -> void:
	_refresh_reputation()
	if is_instance_valid(bento_entry):
		bento_entry.visible = preload("res://scripts/restaurant/bento_store.gd").unlocked(SaveManager)
		bento_entry.disabled = not is_instance_valid(_player) or _player.input_locked

func _refresh_reputation() -> void:
	if not is_instance_valid(reputation_counter):
		return
	# 声望与任务按钮共享父级、绘制层级和透明度；不为任何弹窗单独判断显隐。
	# 若任务层尚未就绪，先隐藏，避免回退到 HUD 的模态层显示。
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if not is_instance_valid(tracker):
		reputation_counter.hide()
		gold_counter.hide()
		return
	if reputation_counter.get_parent() != tracker:
		reputation_counter.reparent(tracker, false)
		gold_counter.reparent(tracker, false)
	tracker.enable_restaurant_scrolling()
	# 唯一独立门槛：首次成功给铁山上菜；凭证随存档和回放状态恢复。
	reputation_counter.set_value(SaveManager.reputation())
	reputation_counter.visible = SaveManager.has_first_order_settlement()
	gold_counter.set_value(SaveManager.gold_balance())
	gold_counter.visible = SaveManager.is_gold_display_unlocked()
	if tracker.has_method("entry_rect"):
		var entry: Rect2 = tracker.entry_rect()
		var next_x := entry.end.x + 20.0
		for counter in [reputation_counter, gold_counter]:
			counter.position = Vector2(next_x, entry.get_center().y - counter.get_combined_minimum_size().y * 0.5)
			if counter.visible:
				next_x += counter.get_combined_minimum_size().x + 20.0

func _build_recipe_entry(root: Control) -> void:
	# 常驻入口低于 UIOverlay(layer=1) 的对白与仓库；弹窗仍留在本HUD。
	var entry_layer := CanvasLayer.new()
	entry_layer.name = "RecipeEntryLayer"
	entry_layer.layer = 0
	add_child(entry_layer)
	var entry_root := Control.new()
	entry_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entry_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_root.theme = root.theme
	entry_layer.add_child(entry_root)
	_recipe_entry = Button.new()
	_recipe_entry.name = "RecipeEntry"
	_recipe_entry.tooltip_text = "菜谱"
	_recipe_entry.custom_minimum_size = Vector2(64, 64)
	_recipe_entry.icon = RecipeUnlock.entry_texture()
	_recipe_entry.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_recipe_entry.expand_icon = true
	_recipe_entry.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_entry.add_theme_constant_override("icon_max_width", 56)
	_recipe_entry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_recipe_entry.offset_left = 16
	_recipe_entry.offset_right = 80
	_recipe_entry.offset_top = -80
	_recipe_entry.offset_bottom = -16
	for state in ["normal", "hover", "pressed", "focus"]:
		_recipe_entry.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_recipe_entry.hide()
	entry_root.add_child(_recipe_entry)
	preload("res://scripts/ui/components/entry_icon_shadow.gd").attach(_recipe_entry,"RecipeShadow")
	bento_entry = preload("res://scripts/ui/components/bento_modal.gd").make_entry(entry_root)
	bento_modal = preload("res://scripts/ui/components/bento_modal.gd").new()
	root.add_child(bento_modal)
	bento_modal.closed.connect(_unlock_player)
	bento_modal.feedback.connect(show_toast)
	bento_entry.pressed.connect(func():
		if not is_instance_valid(_player) or _player.input_locked: return
		_lock_player()
		bento_modal.present(false))
	_recipe_entry.pressed.connect(_open_recipe_book)
	_recipe_entry.visible = SaveManager.unlocked_recipe_ids().has(SaveManager.FIRST_ORDER_ITEM_ID)
	_recipe_unlock = RecipeUnlock.new()
	_recipe_unlock.closed.connect(_on_recipe_unlock_closed)
	add_child(_recipe_unlock)
	_recipe_book = RecipeBook.new()
	add_child(_recipe_book)
	_recipe_book.closed.connect(func(): _unlock_player())
	_recipe_book.hide()
	_recipe_book.set_recipes(_recipe_data())

func _recipe_data() -> Array:
	var recipe := RecipeCatalog.get_recipe("salt_grilled_rockmane")
	var meat := load("res://assets/ui/ingredients/rockmane_meat.png")
	var salt := load("res://assets/ui/ingredients/rock_salt.png")
	var result: Array = [{"id": "salt_grilled_rockmane", "name": str(recipe.name), "icon": load("res://assets/ui/ingredients/salt_grilled_rockmane.png"),
		"description": str(recipe.description), "gold": RecipeCatalog.order_gold("salt_grilled_rockmane"),
		"ingredients": [{"id": "rockmane_meat", "name": "岩鬃肉", "quantity": 1, "icon": meat, "source": "获取：迷宫探索"},
		{"id": "rock_salt", "name": "岩盐", "quantity": 1, "icon": salt, "source": "获取：迷宫探索"}]}]

	for id in SaveManager.unlocked_recipe_ids():
		if id == "salt_grilled_rockmane": continue
		var config := RecipeCatalog.get_recipe(id)
		var ingredients: Array = []
		for ingredient_id in config.ingredients:
			var ingredient := RecipeCatalog.get_ingredient(ingredient_id)
			ingredients.append({"id": ingredient_id, "name": ingredient.name, "quantity": config.ingredients[ingredient_id], "icon": RecipeCatalog.item_texture(ingredient_id), "source": str(ingredient.get("source", "迷宫探索"))})
		result.append({"id": id, "name": config.name, "icon": RecipeCatalog.item_texture(id), "description": str(config.get("description", "")), "gold": RecipeCatalog.order_gold(id), "uses": config.get("uses",["订单"]), "exploration_category": config.get("exploration_category",""), "ingredients": ingredients})
	return result

func show_recipe_unlock() -> void:
	if not is_instance_valid(_recipe_unlock) or _recipe_unlock.visible: return
	var result := SaveManager.unlock_first_recipe()
	if not result.success:
		show_toast("菜谱解锁保存失败，请重试")
		return
	_recipe_entry.hide()
	_recipe_unlock.present(_recipe_entry)

func _on_recipe_unlock_closed() -> void:
	recipe_unlock_closed.emit()

func _open_recipe_book() -> void:
	if is_instance_valid(exploration_guide) and not exploration_guide.allows_recipe(): return
	if not _recipe_entry.visible or _recipe_unlock.visible or not is_instance_valid(_player) or _player.input_locked or not SaveManager.unlocked_recipe_ids().has(SaveManager.FIRST_ORDER_ITEM_ID) or _recipe_book.visible: return
	_lock_player()
	_recipe_book.set_recipes(_recipe_data())
	_recipe_book.show()

func show_toast(message: String) -> void:
	toast_label.show_message(message)

func _on_interacted(target: Node2D) -> void:
	if str(target.get("display_name")) == "冰柜" and not SaveManager.freezer_unlocked():
		if is_instance_valid(_player) and not _player.input_locked and _player.nearest_interactable() == target:
			show_toast("完成【初遇御风】剧情后解锁")
		return
	if str(target.get("display_name")) == "垃圾桶":
		discard_flow.request(target)
		return
	if TutorialManager.active or not SaveManager.is_chapter_1_done() or SaveManager.chapter_1_outro_state() == "title":
		return
	if not is_instance_valid(_player) or _player.input_locked or _player.nearest_interactable() != target:
		return
	if is_instance_valid(exploration_guide) and not exploration_guide.allows_world_interaction(str(target.get("display_name"))): return
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker):
		tracker.collapse_details()
	match str(target.get("display_name")):
		"前台":
			customer_flow.take_order()
		"吧台":
			customer_flow.deliver_ready_order()
		"仓库":
			var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
			if is_instance_valid(warehouse) and not warehouse._open:
				_lock_player()
				_warehouse_open = true
				warehouse.open_stock()
		"小餐车":
			_feature_feedback("送餐", 5000)
		"冰柜":
			_lock_player()
			freezer.open()
		"迷宫入口":
			if not SaveManager.can_enter_maze():
				show_toast("请先完成第一章的出发准备")
				return
			_open_confirmation("迷宫")
		"冒险者之家入口":
			_go_to_destination("冒险者之家")
		"魔法汤锅", "料理台":
			if SaveManager.carried_dish_count() > 0:
				show_toast("请先存放或处理携带的料理")
				return
			var cooking := get_tree().get_first_node_in_group("cooking_modal")
			if is_instance_valid(cooking) and not cooking._open:
				_lock_player()
				_cooking_open = true
				cooking.open_for_order()

func _feature_feedback(feature: String, _required: int) -> void:
	# 玩法等待后续设计；此阶段不因达到门槛宣称已可用。
	show_toast("%s暂未解锁" % feature)

func _lock_player() -> void:
	if _player_lock_depth == 0:
		_locked_before = _player.input_locked
		_physics_before = _player.is_physics_processing()
	_player_lock_depth += 1
	_player.input_locked = true
	_player.set_physics_process(false)

func _unlock_player() -> void:
	if _player_lock_depth <= 0: return
	_player_lock_depth -= 1
	if _player_lock_depth > 0: return
	if is_instance_valid(_player):
		_player.input_locked = _locked_before
		_player.set_physics_process(_physics_before)

func _warehouse_closed() -> void:
	if _warehouse_open:
		_warehouse_open = false
		_unlock_player()

func _cooking_closed() -> void:
	if _cooking_open:
		_cooking_open = false
		_unlock_player()

func _on_cooking_result_confirmed(result: Dictionary) -> void:
	_cooking_closed()
	# 成品随人物携带，交付只由吧台交互触发。

func _open_confirmation(destination: String) -> void:
	_destination = destination
	toast_label.dismiss()
	_lock_player()
	if destination == "迷宫":
		confirmation.open_exploration()
	else:
		confirmation.open_destination(destination)

func _close_confirmation() -> void:
	if not confirmation.visible:
		return
	confirmation.hide()
	_unlock_player()

func _confirm_destination() -> void:
	if not confirmation.visible or Transition.is_active(get_tree()):
		return
	if _destination == "迷宫":
		var request := SaveManager.request_maze_entry(confirmation.selected)
		if not request.success:
			show_toast("体力不足" if request.reason == "insufficient_stamina" else "暂时无法前往迷宫")
			return
	_close_confirmation()
	_go_to_destination(_destination)

func _go_to_destination(destination_name: String) -> void:
	if Transition.is_active(get_tree()) or is_instance_valid(get_tree().get_first_node_in_group("adventurer_home")):
		return
	toast_label.dismiss()
	if destination_name == "迷宫":
		if not SaveManager._maze_entry_pending:
			_open_confirmation("迷宫")
			return
		if not SaveManager.can_enter_maze():
			SaveManager.cancel_maze_entry()
			show_toast("请先完成第一章的出发准备")
			return
		# 第二章标记由目标地图就绪后提交；转场失败不会提前开始。
		var destination := load(SaveManager.MAZE_SCENE) as PackedScene
		await _change_to_maze(destination)
		return
	if destination_name == "冒险者之家":
		AdventurerHome.open_page(get_tree())

func _change_to_maze(destination: PackedScene) -> void:
	var error := await Transition.change_scene(get_tree(), destination)
	if error != OK:
		SaveManager.cancel_maze_entry()
		show_toast("迷宫加载失败，请重试")

func _exit_tree() -> void:
	if _warehouse_open or _cooking_open or (is_instance_valid(confirmation) and confirmation.visible):
		_unlock_player()
