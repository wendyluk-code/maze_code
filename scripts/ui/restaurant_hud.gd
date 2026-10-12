extends CanvasLayer
## 常驻声望；章后交互的提示和确认层。
const Confirmation := preload("res://scripts/ui/components/destination_confirmation.gd")
const Toast := preload("res://scripts/ui/components/feedback_toast.gd")
const Transition := preload("res://scripts/ui/components/scene_transition.gd")
const AdventurerHome := preload("res://scripts/ui/adventurer_home.gd")
const ResourceCounter := preload("res://scripts/ui/components/resource_counter.gd")
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
var _warehouse_open := false
var _cooking_open := false

func _ready() -> void:
	name = "RestaurantHUD"
	layer = 65
	add_to_group("restaurant_hud")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SproutTheme.make_theme()
	add_child(root)
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
	toast_label = Toast.attach_to(root)
	confirmation = Confirmation.new()
	root.add_child(confirmation)
	question = confirmation.question
	cancel_button = confirmation.cancel_button
	confirm_button = confirmation.confirm_button
	confirmation.cancelled.connect(_close_confirmation)
	confirmation.confirmed.connect(_confirm_destination)
	call_deferred("_connect_player")

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
		cooking.result_confirmed.connect(func(_result: Dictionary): _cooking_closed())

func _process(_delta: float) -> void:
	_refresh_reputation()

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

func show_toast(message: String) -> void:
	toast_label.show_message(message)

func _on_interacted(target: Node2D) -> void:
	if TutorialManager.active or not SaveManager.is_chapter_1_done() or SaveManager.chapter_1_outro_state() == "title":
		return
	if not is_instance_valid(_player) or _player.input_locked or _player.nearest_interactable() != target:
		return
	var tracker := get_tree().get_first_node_in_group("order_tracking")
	if is_instance_valid(tracker):
		tracker.collapse_details()
	match str(target.get("display_name")):
		"前台":
			var result := SaveManager.accept_waiting_customer_order()
			if result.success:
				show_toast("已接单：%s" % str(result.order.item_name))
			else:
				var messages := {"no_customer": "当前暂无订单，请等待顾客上门", "active_order": "请先完成当前订单", "save_failed": "接单未保存，请重试"}
				show_toast(str(messages.get(result.reason, "暂时无法接单")))
		"吧台":
			var result := SaveManager.deliver_customer_order()
			if result.success:
				show_toast("上菜完成，声望 +%d" % int(result.reputation_awarded))
			else:
				var messages := {"missing_dish": "请先制作顾客需要的料理", "save_failed": "上菜未保存，请重试"}
				show_toast(str(messages.get(result.reason, "当前暂无用餐需求，请先接单")))
		"仓库":
			var warehouse := get_tree().get_first_node_in_group("warehouse_modal")
			if is_instance_valid(warehouse) and not warehouse._open:
				_lock_player()
				_warehouse_open = true
				warehouse.open_stock()
		"小餐车":
			_feature_feedback("送餐", 5000)
		"冰柜":
			_feature_feedback("冷藏", 2000)
		"迷宫入口":
			if not SaveManager.can_enter_maze():
				show_toast("请先完成第一章的出发准备")
				return
			_open_confirmation("迷宫")
		"冒险者之家入口":
			_go_to_destination("冒险者之家")
		"魔法汤锅", "料理台":
			if not SaveManager.has_waiting_diner():
				show_toast("请先接单并领取食材")
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
	_locked_before = _player.input_locked
	_physics_before = _player.is_physics_processing()
	_player.input_locked = true
	_player.set_physics_process(false)

func _unlock_player() -> void:
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

func _open_confirmation(destination: String) -> void:
	_destination = destination
	toast_label.dismiss()
	_lock_player()
	confirmation.open_destination(destination)

func _close_confirmation() -> void:
	if not confirmation.visible:
		return
	confirmation.hide()
	_unlock_player()

func _confirm_destination() -> void:
	if not confirmation.visible or Transition.is_active(get_tree()):
		return
	_close_confirmation()
	_go_to_destination(_destination)

func _go_to_destination(destination_name: String) -> void:
	if Transition.is_active(get_tree()) or is_instance_valid(get_tree().get_first_node_in_group("adventurer_home")):
		return
	toast_label.dismiss()
	if destination_name == "迷宫":
		if not SaveManager.can_enter_maze():
			show_toast("请先完成第一章的出发准备")
			return
		# 第二章标记由目标地图就绪后提交；转场失败不会提前开始。
		var destination := load(SaveManager.MAZE_SCENE) as PackedScene
		var error := await Transition.change_scene(get_tree(), destination)
		if error != OK:
			show_toast("迷宫加载失败，请重试")
		return
	if destination_name == "冒险者之家":
		AdventurerHome.open_page(get_tree())

func _exit_tree() -> void:
	if _warehouse_open or _cooking_open or (is_instance_valid(confirmation) and confirmation.visible):
		_unlock_player()
