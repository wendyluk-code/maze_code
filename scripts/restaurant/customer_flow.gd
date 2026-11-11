extends Node2D
## 演出只推进已保存检查点；经营结算全部交给 SaveManager。
const Catalog := preload("res://scripts/restaurant/customer_catalog.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Layout := preload("res://scripts/restaurant/three_seat_layout.gd")
var hud: Node
var actors: Dictionary = {}
var phases: Dictionary = {}
var busy := false
var _elapsed := 0.0
var selected_id := ""
var questions: Dictionary = {}
var _generation := 0
var _shade: ColorRect
var _dialog: Control
var _arrival_toast_shown := false
var _first_arrival_tutorial_done := false
var _arrival_tutorial_busy := false
var _arrival_tutorial_pending := false
var arrival_lesson: CanvasLayer
var _business_error := ""

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
	_shade.visible = _dialog.visible

func _process(delta: float) -> void:
	_layout_bubbles()
	_update_selection()
	if _start_ganlu_lesson(): return
	if _arrival_tutorial_busy:
		_elapsed = 0.0
		return
	if SaveManager.is_chapter_1_done() and _arrival_tutorial_due():
		_elapsed = 0.0
		_sync()
		_start_first_arrival_tutorial()
		return
	_elapsed += delta
	if _elapsed < 0.2 or not SaveManager.is_chapter_1_done(): return
	var elapsed := _elapsed
	_elapsed = 0.0
	# 剧情暂停经营；取料、烹饪和倒水时继续计时。
	if TutorialManager.active or busy or not is_instance_valid(hud._player): return
	if is_instance_valid(hud.exploration_guide) and hud.exploration_guide.reading: return
	if not preload("res://scripts/restaurant/service_cycle.gd").migrate_customers(SaveManager).success: return
	var balance_before := Vector2i(SaveManager.gold_balance(),SaveManager.reputation())
	var timed := preload("res://scripts/restaurant/service_cycle.gd").tick(SaveManager, elapsed)
	if not timed.success:
		if timed.get("reason","")=="portion_inventory_mismatch" and _business_error!=timed.reason:
			hud.show_toast("菜单归属与库存不一致，营业结算未扣除物品，请检查存档")
		_business_error = timed.get("reason","")
		return
	_business_error = ""
	hud.show_balance_change(balance_before)
	var arrival := SaveManager.ensure_restaurant_customer()
	_sync()
	_clear_arrival_toast_if_seen()

func _layout_bubbles() -> void:
	for actor in actors.values():
		var bubble = actor.get_node("OrderBubble")
		if "selected" in bubble and actor.texture != null: bubble.follow(actor)

func _arrival_tutorial_due() -> bool:
	var checkpoint: Dictionary = SaveManager._state.get("restaurant_arrival_lesson_v1",{})
	if checkpoint.get("phase","") == "done" or _first_arrival_tutorial_done: return false
	var day := preload("res://scripts/restaurant/restaurant_day.gd").snapshot(SaveManager)
	var front: Dictionary = SaveManager.restaurant_customers().get("front",{})
	return day.get("day",0)==1 and day.get("status")=="open" and day.get("arrived",0)==1 and front.get("phase")=="front" and front.get("cycle",false)

func _start_ganlu_lesson() -> bool:
	if _arrival_tutorial_busy: return false
	if busy or TutorialManager.active or not SaveManager.is_chapter_1_done() or not is_instance_valid(hud._player) or hud._player.input_locked: return false
	var day := preload("res://scripts/restaurant/restaurant_day.gd").snapshot(SaveManager)
	if day.get("status")!="open": return false
	var flags: Dictionary = SaveManager._state.get("ganlu_lessons_v1",{})
	var script := preload("res://scripts/ui/components/ganlu_lesson.gd")
	for order in SaveManager.restaurant_customers().seated:
		if order.get("stage")!="drink" or order.phase!="waiting" or not actors.has(order.id): continue
		var kind := "iced" if int(order.get("drink_ice",0))>0 else "warm"
		if flags.get(kind,false): continue
		# 落座异步回调先提交waiting；教学暂停刷新前必须同步真实气泡。
		_sync()
		arrival_lesson = script.new()
		add_child(arrival_lesson)
		arrival_lesson.begin_lesson(self,kind,actors[order.id])
		return true
	var water := preload("res://scripts/restaurant/ganlu_service.gd")
	var cups := water.snapshot(SaveManager)
	if water.grade(cups.held)==4 and not flags.get("spoiled",false):
		for prop in get_tree().get_nodes_in_group("interactable"):
			if str(prop.get("display_name"))=="垃圾桶":
				arrival_lesson = script.new()
				add_child(arrival_lesson)
				arrival_lesson.begin_lesson(self,"spoiled",prop)
				return true
	if not flags.get("ready",false) and is_instance_valid(hud.ganlu.freezer_view):
		for i in range(3):
			if water.grade(cups.slots[i])==1:
				arrival_lesson = script.new()
				add_child(arrival_lesson)
				arrival_lesson.begin_lesson(self,"ready",hud.ganlu.freezer_view,i)
				return true
	return false

func _start_first_arrival_tutorial() -> void:
	if _arrival_tutorial_busy or not _arrival_tutorial_due(): return
	if busy or TutorialManager.active or not is_instance_valid(hud._player) or hud._player.input_locked or not hud._player.is_physics_processing():
		_arrival_tutorial_pending = true
		return
	_arrival_tutorial_pending = false
	var front: Dictionary = SaveManager.restaurant_customers().front
	var actor = actors.get(str(front.id))
	if not is_instance_valid(actor): return
	arrival_lesson = preload("res://scripts/ui/components/restaurant_arrival_lesson.gd").new()
	arrival_lesson.flow = self
	add_child(arrival_lesson)
	arrival_lesson.begin(front,actor)

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
			var bubble := preload("res://scripts/ui/components/service_order_bubble.gd").new() if order.get("cycle", false) else preload("res://scripts/ui/components/customer_order_bubble.gd").new()
			bubble.name = "OrderBubble"
			actor.add_child(bubble)
		# 候客始终由当前持久队列定位；提升队首或读档也不能沿用旧座位。
		if order.phase == "front": actors[order.id].position = Catalog.COUNTER
		elif order.phase == "queued": actors[order.id].position = Catalog.QUEUE[state.queue.find(order)]
		if order.phase in ["front", "queued", "waiting"] and phases.get(order.id) == order.phase and actors[order.id].get_node_or_null("CustomerFeedback") == null:
			_frame(actors[order.id], order.customer_id, 0 if order.phase in ["front", "queued"] else 1, 1 if Time.get_ticks_msec() % 3200 > 2850 else 0)
		if phases.get(order.id) != order.phase:
			phases[order.id] = order.phase
			_present(order, actors[order.id])
		var bubble = actors[order.id].get_node("OrderBubble")
		var show_order: bool = order.phase in ["front", "waiting"] and actors[order.id].get_node_or_null("CustomerFeedback") == null
		if "order_visible" in bubble: bubble.order_visible = show_order
		bubble.visible = show_order
		if bubble.visible:
			bubble.setup_order(order)
			if not "selected" in bubble: bubble.follow(actors[order.id])
	_layout_bubbles()
	for id in actors.keys():
		if id not in ids:
			actors[id].queue_free()
			actors.erase(id)
			phases.erase(id)
	if not busy and is_instance_valid(hud._player):
		for order in orders:
			if order.phase == "farewell":
				if order.get("cycle", false): _advance(order.id, "farewell", "leaving")
				elif not hud._player.input_locked: _farewell(order)
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
	var band: Array = bands.get(customer,bands.mage)[row]
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
	var motion: Tween = actor.get_meta("motion") if actor.has_meta("motion") else null
	if motion != null and motion.is_valid(): motion.kill()
	# 离场保存失败只重试事务，不能把已渐隐的人物重新点亮。
	if order.phase == "leaving" and actor.get_meta("departure_faded", false):
		_advance(order.id, "leaving", "departed")
		return
	actor.modulate.a = 1.0
	if order.phase == "queued": actor.position = Catalog.QUEUE[SaveManager.restaurant_customers().queue.find(order)]
	elif order.phase != "leaving" or actor.position == Vector2.ZERO:
		actor.position = Catalog.COUNTER if int(order.seat) < 0 else Catalog.SEATS[int(order.seat)] + Vector2(0, 24)
	match str(order.phase):
		"front", "queued":
			_frame(actor, order.customer_id, 0, 0)
		"waiting", "farewell": _frame(actor, order.customer_id, 1 if order.phase == "waiting" else 3, 0)
		"arriving":
			actor.position = Catalog.COUNTER
			_frame(actor, order.customer_id, 0, 0)
			actor.modulate.a = 0.0
			await _fade(actor, 1.0)
			if _valid_actor(order.id, actor, token, "arriving"): _advance(order.id, "arriving", "front")
		"seating":
			actor.position = Catalog.COUNTER
			_frame(actor, order.customer_id, 0, 0)
			await _fade(actor, 0.0)
			if not _valid_actor(order.id, actor, token, "seating"): return
			actor.position = Catalog.SEATS[int(order.seat)] + Vector2(0,24)
			_frame(actor, order.customer_id, 1, 0)
			await _fade(actor, 1.0)
			if _valid_actor(order.id, actor, token, "seating"):
				_frame(actor, order.customer_id, 1, 0)
				_advance(order.id, "seating", "waiting")
		"eating":
			for column in range(4):
				_frame(actor, order.customer_id, 2, column)
				await get_tree().create_timer(0.45).timeout
				if not _valid_actor(order.id, actor, token, "eating"): return
			_advance(order.id, "eating", "farewell")
		"leaving":
			# 所有经营离场共用原地渐隐；异常反馈仍先完整显示。
			var outcome: String = str(order.get("outcome",""))
			if order.get("cycle",false) and preload("res://scripts/ui/components/customer_feedback.gd").ROWS.has(outcome):
				_frame(actor,order.customer_id,0 if int(order.seat) < 0 else 1,0)
				show_feedback(order.id,outcome)
				await get_tree().create_timer(2.2).timeout
				if not _valid_actor(order.id,actor,token,"leaving"): return
				preload("res://scripts/ui/components/customer_feedback.gd").clear(actor)
			_frame(actor, order.customer_id, 0, 0)
			await _fade(actor, 0.0)
			if _valid_actor(order.id, actor, token, "leaving"):
				actor.set_meta("departure_faded", true)
				_advance(order.id, "leaving", "departed")

func _fade(actor: Sprite2D, alpha: float) -> void:
	var tween := create_tween()
	actor.set_meta("motion", tween)
	tween.tween_property(actor,"modulate:a",alpha,0.35)
	await tween.finished

func _valid_actor(id: String, actor, token: int, expected_phase := "") -> bool:
	if not (is_inside_tree() and token == _generation and is_instance_valid(actor) and actors.get(id) == actor): return false
	# 入场异步等待后重新检查已保存接单状态；旧转场不能把读档恢复的候客送进吧台。
	return expected_phase.is_empty() or SaveManager.restaurant_customer_order(id).get("phase", "") == expected_phase

func _advance(id: String, expected: String, next: String) -> void:
	var was_seating: bool = SaveManager.restaurant_customer_order(id).get("phase", "") == "seating"
	var was_arriving: bool = SaveManager.restaurant_customer_order(id).get("phase", "") == "arriving"
	var result := SaveManager.advance_restaurant_customer(id, expected, next)
	if result.success and was_seating and next == "waiting":
		GameAudio.play_cue(&"customer_seated")
	if result.success and was_arriving and next == "front":
		GameAudio.play_cue(&"customer_arrival")
	if not result.success:
		hud.show_toast("顾客进度未保存，请检查存档后重试")
		# 下轮重演当前持久检查点，绝不重复结算。
		phases.erase(id)

func take_order() -> void:
	if busy: return
	if not is_instance_valid(hud._player) or hud._player.input_locked: return
	var target = hud._player.nearest_interactable()
	if not is_instance_valid(target) or str(target.get("display_name")) != "前台": return
	var state := SaveManager.restaurant_customers()
	if state.get("seated", []).size() >= Catalog.SEATS.size():
		hud.show_toast("座位已满，请等待顾客离开")
		return
	var order: Dictionary = state.get("front", {})
	if order.is_empty():
		hud.show_toast("当前暂无订单，请等待顾客上门")
		return
	if order.phase != "front":
		hud.show_toast("请等顾客走到前台")
		return
	if order.get("cycle",false):
		var accepted := SaveManager.accept_restaurant_customer(str(order.id))
		if accepted.success: GameAudio.play_cue(&"order_accepted")
		if not accepted.success: hud.show_toast("接单未保存，请重试")
		_sync()
		return
	busy = true
	hud._lock_player()
	var token := _generation
	_shade.show()
	await get_tree().process_frame
	if not is_inside_tree() or token != _generation: return
	var ice := int(state.serial) % 2 if SaveManager.freezer_unlocked() else 0
	_dialog.start(Catalog.customer(order.customer_id).name, ["请给我一份%s，再来一杯甘露水，%s。" % [order.item_name, preload("res://scripts/restaurant/ganlu_service.gd").ICE_NAMES[ice]]], load(Catalog.customer(order.customer_id).portrait))
	await _dialog.finished
	if not is_inside_tree() or token != _generation: return
	var result := SaveManager.accept_restaurant_customer(order.id)
	if result.success: GameAudio.play_cue(&"order_accepted")
	_dialog.hide()
	_shade.hide()
	busy = false
	hud._unlock_player()
	hud.show_toast("已接单：%s" % order.item_name if result.success else "接单未成功，请重试")
	_sync()

## 有成品时按接单顺序直接交付一单；料理结果只匹配本次配方。
func _update_selection() -> void:
	selected_id = ""
	for actor in actors.values():
		var old_bubble = actor.get_node("OrderBubble")
		if "selected" in old_bubble:
			old_bubble.selected = false
			old_bubble.question = int(questions.get(str(actor.name),0)) > Time.get_ticks_msec()
			old_bubble.queue_redraw()
	if not is_instance_valid(hud._player) or hud._player.input_locked: return
	var target = hud._player.nearest_interactable()
	if not is_instance_valid(target) or str(target.get("display_name")) != "吧台": return
	var nearest := 85.0
	for order in SaveManager.customer_orders_active():
		if order.phase != "waiting": continue
		var point := Layout.service_point(int(order.seat))
		var distance: float = hud._player.global_position.distance_to(point)
		if distance < nearest:
			nearest = distance
			selected_id = str(order.id)
	for id in actors:
		var bubble = actors[id].get_node("OrderBubble")
		if not "selected" in bubble: continue
		bubble.selected = id == selected_id
		bubble.question = int(questions.get(id, 0)) > Time.get_ticks_msec()
		bubble.queue_redraw()

func deliver_ready_order(_item_id := "") -> void:
	if busy: return
	_update_selection()
	if selected_id.is_empty():
		hud.show_toast("请靠近要交付的顾客")
		return
	if not hud.ganlu.serve(selected_id): _deliver(selected_id)

func _deliver(id: String) -> void:
	var balance_before := Vector2i(SaveManager.gold_balance(),SaveManager.reputation())
	var result := SaveManager.deliver_restaurant_customer(id)
	if result.success:
		if result.get("outcome", "served") == "served": GameAudio.play_served(&"food")
		hud.show_balance_change(balance_before)
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
	if is_instance_valid(arrival_lesson): arrival_lesson.release()
	if busy and is_instance_valid(hud): hud._unlock_player()

func show_feedback(id: String, reason: String) -> void:
	if not actors.has(id): return
	var order := SaveManager.restaurant_customer_order(id)
	if not order.get("cycle",false): return
	var actor: Sprite2D = actors[id]
	var sound_key := "feedback_audio_" + reason
	if preload("res://scripts/ui/components/customer_feedback.gd").ROWS.has(reason) and not actor.get_meta(sound_key, false):
		actor.set_meta(sound_key, true)
		GameAudio.play_cue(&"failure")
	_frame(actor,str(order.customer_id),0 if int(order.seat) < 0 else 1,0)
	preload("res://scripts/ui/components/customer_feedback.gd").show_on(actor,str(order.customer_id),reason)
