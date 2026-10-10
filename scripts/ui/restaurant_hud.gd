extends CanvasLayer
## 常驻声望；章后交互的提示和确认层。
var reputation_label: Label
var toast_label: Label
var confirmation: ColorRect
var question: Label
var confirm_button: SproutButton
var cancel_button: SproutButton
var _toast_time := 0.0
var _destination := ""
var _player: Node
var _locked_before := false
var _physics_before := true
var _warehouse_open := false
var _cooking_open := false
var _confirm_armed := false

func _ready() -> void:
	name = "RestaurantHUD"
	layer = 65
	add_to_group("restaurant_hud")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = SproutTheme.make_theme()
	add_child(root)
	reputation_label = Label.new()
	reputation_label.position = Vector2(24, 22)
	reputation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reputation_label.add_theme_font_size_override("font_size", 22)
	reputation_label.add_theme_color_override("font_color", SproutTheme.CREAM)
	reputation_label.add_theme_color_override("font_outline_color", SproutTheme.INK)
	reputation_label.add_theme_constant_override("outline_size", 4)
	reputation_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.08, 0.04, 0.55))
	reputation_label.add_theme_constant_override("shadow_offset_x", 1)
	reputation_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(reputation_label)
	_refresh_reputation()
	var toast_center := CenterContainer.new()
	toast_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_center.offset_top = 22
	toast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_center)
	toast_label = Label.new()
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.add_theme_color_override("font_color", SproutTheme.CREAM)
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0.03, 0.04, 0.03, 0.82)
	toast_style.set_corner_radius_all(7)
	toast_style.content_margin_left = 16
	toast_style.content_margin_right = 16
	toast_style.content_margin_top = 10
	toast_style.content_margin_bottom = 10
	toast_label.add_theme_stylebox_override("normal", toast_style)
	toast_center.add_child(toast_label)
	toast_label.hide()
	confirmation = ColorRect.new()
	confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirmation.color = Color(0.03, 0.04, 0.03, 0.65)
	root.add_child(confirmation)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirmation.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	question = Label.new()
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 24)
	column.add_child(question)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	cancel_button = SproutButton.new().configure("取消").set_icon_visible(false).set_focus_visual(false)
	confirm_button = SproutButton.new().configure("确认前往").set_icon_visible(false).set_focus_visual(false)
	buttons.add_child(cancel_button)
	buttons.add_child(confirm_button)
	cancel_button.pressed.connect(_close_confirmation)
	confirm_button.pressed.connect(_confirm_destination)
	confirmation.hide()
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

func _process(delta: float) -> void:
	_refresh_reputation()
	_toast_time = maxf(0, _toast_time - delta)
	toast_label.visible = _toast_time > 0

func _refresh_reputation() -> void:
	# 首次成功上菜后才展示；凭证随存档及回放状态恢复，不以声望数值猜进度。
	reputation_label.text = "声望：%d" % SaveManager.reputation()
	reputation_label.visible = SaveManager.has_first_order_settlement()

func show_toast(message: String) -> void:
	toast_label.text = message
	_toast_time = 3.5
	toast_label.show()

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
			_open_confirmation("迷宫")
		"冒险者之家入口":
			_open_confirmation("冒险者之家")
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
	_confirm_armed = false
	_toast_time = 0.0
	toast_label.hide()
	question.text = "是否前往%s？" % destination
	_lock_player()
	confirmation.show()
	cancel_button.grab_focus()

func _close_confirmation() -> void:
	if not confirmation.visible:
		return
	confirmation.hide()
	_unlock_player()

func _confirm_destination() -> void:
	_close_confirmation()
	if _destination == "迷宫":
		var departure := get_tree().get_first_node_in_group("departure_panel")
		if is_instance_valid(departure):
			departure.open_map()
		return
	show_toast("冒险者之家暂未开放")

func _input(event: InputEvent) -> void:
	if not confirmation.visible:
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if not event.pressed and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
			_confirm_armed = true
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_close_confirmation()
			elif event.keycode == KEY_E and _confirm_armed:
				_confirm_destination()
			elif event.keycode in [KEY_TAB, KEY_LEFT, KEY_RIGHT]:
				if cancel_button.has_focus():
					confirm_button.grab_focus()
				else:
					cancel_button.grab_focus()
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				if confirm_button.has_focus():
					_confirm_destination()
				else:
					_close_confirmation()

func _exit_tree() -> void:
	if _warehouse_open or _cooking_open or (is_instance_valid(confirmation) and confirmation.visible):
		_unlock_player()
