extends Node2D
## 演出只推进已保存检查点；经营结算全部交给 SaveManager。
const Catalog := preload("res://scripts/restaurant/customer_catalog.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
var hud: Node
var actors: Dictionary = {}
var phases: Dictionary = {}
var busy := false
var _elapsed := 0.0
var _generation := 0
var _shade: ColorRect
var _dialog: Control
var _arrival_toast_shown := false
var _first_arrival_tutorial_done := false
var _arrival_tutorial_busy := false
var _arrival_tutorial_pending := false
var _arrival_camera_before := {}

func _ready() -> void:
	add_to_group("restaurant_customers")
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ui)
	_shade = ColorRect.new()
	# 所有顾客对白统一使用弹窗规范蒙层透明度。
	_shade.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_shade)
	_shade.hide()
	_dialog = preload("res://scenes/ui/dialog_box.tscn").instantiate()
	ui.add_child(_dialog)
	_dialog.visibility_changed.connect(_sync_dialog_backdrop)
	get_viewport().size_changed.connect(_layout_dialog)
	_layout_dialog()
	_dialog.hide()

func _layout_dialog() -> void:
	# 固定左右30像素边距，与1152宽时的原对白版式一致。
	_dialog.anchor_left = 0.0
	_dialog.anchor_right = 1.0
	_dialog.offset_left = 30.0
	_dialog.offset_right = -30.0

func _sync_dialog_backdrop() -> void:
	# 绑定实际可见性，包含接单、餐后及直接展示对白的入口。
	_shade.visible = _dialog.visible or _arrival_tutorial_busy

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.2 or not SaveManager.is_chapter_1_done(): return
	_elapsed = 0.0
	var arrival := SaveManager.ensure_restaurant_customer()
	if arrival.get("created", false):
		hud.show_toast("你有新顾客哦~")
		_arrival_toast_shown = true
		if not _first_arrival_tutorial_done and int(SaveManager.restaurant_customers().get("serial", 0)) == 1:
			_arrival_tutorial_pending = true
	if _arrival_tutorial_pending and not busy and is_instance_valid(hud._player) and not hud._player.input_locked and hud._player.is_physics_processing():
		_start_first_arrival_tutorial()
	_sync()
	_clear_arrival_toast_if_seen()

func _start_first_arrival_tutorial() -> void:
	if _arrival_tutorial_busy or not is_inside_tree(): return
	if busy or not is_instance_valid(hud._player) or hud._player.input_locked or not hud._player.is_physics_processing():
		_arrival_tutorial_pending = true
		return
	_arrival_tutorial_pending = false
	var state := SaveManager.restaurant_customers()
	var front: Dictionary = state.get("front", {})
	if front.is_empty(): return
	var actor := actors.get(str(front.get("id", ""))) as Sprite2D
	if not is_instance_valid(actor):
		await get_tree().process_frame
		actor = actors.get(str(front.get("id", ""))) as Sprite2D
	if not is_instance_valid(actor): return
	var camera := get_viewport().get_camera_2d()
	if not is_instance_valid(camera): return
	_first_arrival_tutorial_done = true
	_arrival_tutorial_busy = true
	hud._lock_player()
	_arrival_camera_before = {"position": camera.global_position, "zoom": camera.zoom,
		"process": camera.is_processing(), "physics": camera.is_physics_processing()}
	camera.set_process(false)
	camera.set_physics_process(false)
	_shade.show()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "global_position", actor.global_position + Vector2(0, 60), 0.45)
	tween.tween_property(camera, "zoom", Vector2(1.35, 1.35), 0.45)
	await tween.finished
	if not is_inside_tree(): return
	_dialog.start("芽芽", ["有新顾客来了，快去前台接单吧。"], load("res://assets/characters/yaya_portrait.png"))
	await _dialog.finished
	_dialog.hide()
	_shade.hide()
	if is_instance_valid(camera) and not _arrival_camera_before.is_empty():
		camera.global_position = _arrival_camera_before.position
		camera.zoom = _arrival_camera_before.zoom
		camera.set_process(_arrival_camera_before.process)
		camera.set_physics_process(_arrival_camera_before.physics)
		camera.reset_smoothing()
	_arrival_camera_before.clear()
	_arrival_tutorial_busy = false
	hud._unlock_player()

func _clear_arrival_toast_if_seen() -> void:
	if not _arrival_toast_shown or not is_instance_valid(hud._player): return
	var front: Dictionary = SaveManager.restaurant_customers().get("front", {})
	if front.is_empty(): return
	var actor: Node = actors.get(str(front.get("id", "")))
	if not is_instance_valid(actor): return
	if hud._player.global_position.distance_to(actor.global_position) <= 150.0:
		hud.toast_label.dismiss()
		_arrival_toast_shown = false
		SaveManager.consume_customer_arrival_notice()

func _sync() -> void:
	var state := SaveManager.restaurant_customers()
	if not SaveManager._customers_valid(state): return
	var orders: Array = state.seated.duplicate(true)
	if not state.front.is_empty(): orders.append(state.front)
	orders.append_array(state.queue)
	var ids: Array = []
	for order in orders:
		ids.append(order.id)
		if not actors.has(order.id):
			var actor := Sprite2D.new()
			actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			actor.name = str(order.id)
			add_child(actor)
			actors[order.id] = actor
			var bubble := preload("res://scripts/ui/components/customer_order_bubble.gd").new()
			bubble.name = "OrderBubble"
			actor.add_child(bubble)
		# 候客始终由当前持久队列定位；提升队首或读档也不能沿用旧座位。
		if order.phase == "front": actors[order.id].position = Catalog.COUNTER
		elif order.phase == "queued": actors[order.id].position = Catalog.QUEUE[state.queue.find(order)]
		if order.phase in ["front", "queued", "waiting"] and phases.get(order.id) == order.phase:
			_frame(actors[order.id], order.customer_id, 0 if order.phase in ["front", "queued"] else 1, 1 if Time.get_ticks_msec() % 3200 > 2850 else 0)
		if phases.get(order.id) != order.phase:
			phases[order.id] = order.phase
			_present(order, actors[order.id])
		var bubble = actors[order.id].get_node("OrderBubble")
		bubble.visible = order.phase == "waiting"
		if bubble.visible:
			bubble.setup(str(order.item_id))
			bubble.follow(actors[order.id])
	for id in actors.keys():
		if id not in ids:
			actors[id].queue_free()
			actors.erase(id)
			phases.erase(id)
	if not busy and is_instance_valid(hud._player) and not hud._player.input_locked:
		for order in orders:
			if order.phase == "farewell":
				_farewell(order)
				break

func _frame(actor: Sprite2D, customer: String, row: int, column: int, legacy := false) -> void:
	var config := Catalog.legacy_customer(customer) if legacy else Catalog.customer(customer)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(config.get("actions", "res://assets/characters/customers/%s.png" % customer))
	# 原图1254方形：列按四等分，行按实际脚底/帽顶边界校准，防止串入邻帧。
	var dimensions := atlas.atlas.get_size()
	var x0 := floorf(dimensions.x * column / 4.0)
	var bands := {"mage": [[0, 321], [322, 633], [635, 945], [948, 1254]],
		"dingdang": [[0, 330], [333, 628], [634, 921], [928, 1254]],
		"half_elf": [[0, 330], [340, 634], [640, 934], [944, 1254]]}
	var band: Array = bands[customer][row]
	atlas.region = Rect2(x0, band[0], floorf(dimensions.x * (column + 1) / 4.0) - x0, int(band[1]) - int(band[0]))
	if config.has("cell_size"):
		var cell := int(config.cell_size)
		atlas.region = Rect2(column * cell, row * cell, cell, cell)
	atlas.filter_clip = true
	actor.scale = Vector2.ONE * float(config.scale)
	actor.texture = atlas
	actor.flip_h = row in [1, 2]
	actor.offset = Vector2(0, -atlas.region.size.y * 0.5)

func _present(order: Dictionary, actor: Sprite2D) -> void:
	var token := _generation
	actor.modulate.a = 1.0
	if order.phase == "queued": actor.position = Catalog.QUEUE[SaveManager.restaurant_customers().queue.find(order)]
	else: actor.position = Catalog.COUNTER if order.phase == "front" else Catalog.SEATS[int(order.seat)] + Vector2(0, 24)
	match str(order.phase):
		"front", "queued":
			_frame(actor, order.customer_id, 0, 0)
			actor.modulate.a = 0.0
			create_tween().tween_property(actor, "modulate:a", 1.0, 0.35)
		"waiting", "farewell": _frame(actor, order.customer_id, 1 if order.phase == "waiting" else 3, 0)
		"seating":
			actor.position = Catalog.COUNTER
			_frame(actor, order.customer_id, 0, 0)
			var tween := create_tween()
			tween.tween_property(actor, "modulate:a", 0.0, 0.30)
			await tween.finished
			if not _valid_actor(order.id, actor, token, "seating"): return
			actor.position = Catalog.SEATS[int(order.seat)] + Vector2(0, 24)
			_frame(actor, order.customer_id, 1, 0)
			tween = create_tween()
			tween.tween_property(actor, "modulate:a", 1.0, 0.35)
			await tween.finished
			if _valid_actor(order.id, actor, token, "seating"): _advance(order.id, "seating", "waiting")
		"eating":
			for column in range(4):
				_frame(actor, order.customer_id, 2, column)
				await get_tree().create_timer(0.45).timeout
				if not _valid_actor(order.id, actor, token): return
			_advance(order.id, "eating", "farewell")
		"leaving":
			_frame(actor, order.customer_id, 3, 2)
			await get_tree().create_timer(0.4).timeout
			if not _valid_actor(order.id, actor, token): return
			_frame(actor, order.customer_id, 3, 3)
			var tween := create_tween()
			tween.tween_property(actor, "modulate:a", 0.0, 0.35)
			await tween.finished
			if _valid_actor(order.id, actor, token): _advance(order.id, "leaving", "departed")

func _valid_actor(id: String, actor: Sprite2D, token: int, expected_phase := "") -> bool:
	if not (is_inside_tree() and token == _generation and is_instance_valid(actor) and actors.get(id) == actor): return false
	# 入场异步等待后重新检查已保存接单状态；旧转场不能把读档恢复的候客送进吧台。
	return expected_phase.is_empty() or SaveManager.restaurant_customer_order(id).get("phase", "") == expected_phase

func _advance(id: String, expected: String, next: String) -> void:
	var result := SaveManager.advance_restaurant_customer(id, expected, next)
	if not result.success:
		hud.show_toast("顾客进度未保存，请检查存档后重试")
		# 下轮重演当前持久检查点，绝不重复结算。
		phases.erase(id)

func take_order() -> void:
	if busy: return
	var state := SaveManager.restaurant_customers()
	if state.get("seated", []).size() >= 3:
		hud.show_toast("三席已满，请等待顾客离开")
		return
	var order: Dictionary = state.get("front", {})
	if order.is_empty():
		hud.show_toast("当前暂无订单，请等待顾客上门")
		return
	busy = true
	hud._lock_player()
	var token := _generation
	_shade.show()
	await get_tree().process_frame
	if not is_inside_tree() or token != _generation: return
	_dialog.start(Catalog.customer(order.customer_id).name, ["请给我一份%s。" % order.item_name], load(Catalog.customer(order.customer_id).portrait))
	await _dialog.finished
	if not is_inside_tree() or token != _generation: return
	var result := SaveManager.accept_restaurant_customer(order.id)
	_dialog.hide()
	_shade.hide()
	busy = false
	hud._unlock_player()
	hud.show_toast("已接单：%s" % order.item_name if result.success else "接单未成功，请重试")
	_sync()

## 有成品时按接单顺序直接交付一单；料理结果只匹配本次配方。
func deliver_ready_order(item_id := "") -> void:
	if busy: return
	var orders := SaveManager.customer_orders_active()
	for order in orders:
		if order.phase != "waiting" or (not item_id.is_empty() and order.item_id != item_id): continue
		if SaveManager.dish_quality(order.item_id) == 0: continue
		_deliver(str(order.id))
		return
	hud.show_toast("当前暂无用餐需求，请先接单" if orders.is_empty() else "请先制作顾客需要的料理")

func _deliver(id: String) -> void:
	var result := SaveManager.deliver_restaurant_customer(id)
	if result.success:
		hud.show_toast("上菜完成，声望 +%d，金币 +%d" % [result.reputation_awarded, result.gold_awarded])
		_sync()
	else:
		var messages := {"missing_dish": "请先制作这位顾客需要的料理", "save_failed": "上菜未保存，成品已保留，请到吧台重试", "already_completed": "这份订单已经结算"}
		hud.show_toast(messages.get(result.reason, "当前订单无法交付"))
func _farewell(order: Dictionary) -> void:
	busy = true
	hud._lock_player()
	var token := _generation
	_shade.show()
	await get_tree().process_frame
	if not is_inside_tree() or token != _generation: return
	_dialog.start(Catalog.customer(order.customer_id).name, [SaveManager.customer_review(order.id)], load(Catalog.customer(order.customer_id).portrait))
	await _dialog.finished
	if not is_inside_tree() or token != _generation: return
	_dialog.hide()
	_shade.hide()
	_advance(order.id, "farewell", "leaving")
	busy = false
	hud._unlock_player()

func _exit_tree() -> void:
	_generation += 1
	if _arrival_tutorial_busy and is_instance_valid(hud): hud._unlock_player()
	if busy and is_instance_valid(hud): hud._unlock_player()
