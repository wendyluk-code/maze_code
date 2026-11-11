extends Node
const Service := preload("res://scripts/restaurant/ganlu_service.gd")
var hud: Node
var modal: Control
var discard_modal: Control
var held_label: Label
var freezer_view: Node2D
var checkpoint := 0.0
var cold_dirty := false

func _ready() -> void:
	modal = preload("res://scripts/ui/components/ganlu_pour_modal.gd").new()
	get_parent().add_child.call_deferred(modal)
	modal.closed.connect(hud._unlock_player)
	modal.feedback.connect(hud.show_toast)
	discard_modal = preload("res://scripts/restaurant/discard_confirmation.gd").new()
	get_parent().add_child.call_deferred(discard_modal)
	discard_modal.cancelled.connect(func(): discard_modal.hide(); hud._unlock_player())
	discard_modal.confirmed.connect(func():
		if Service.discard(SaveManager).success:
			discard_modal.hide()
			hud._unlock_player()
		else: hud.show_toast("丢弃未保存，请重试"))
	held_label = Label.new()
	held_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	held_label.position = Vector2(-300,-48)
	get_parent().add_child.call_deferred(held_label)
	call_deferred("_attach_freezer")

func _attach_freezer() -> void:
	for target in get_tree().get_nodes_in_group("interactable"):
		if str(target.get("display_name")) != "冰柜": continue
		freezer_view = preload("res://scripts/restaurant/ganlu_freezer_view.gd").new()
		freezer_view.controller = self
		target.add_child(freezer_view)
		break
	# 中断的倒水未端起，不保留半杯；保存失败时允许在餐车重试清理。
	if Service.snapshot(SaveManager).held.get("phase", "") == "pouring": Service.discard(SaveManager)

func _process(delta: float) -> void:
	if is_instance_valid(hud.customer_flow) and hud.customer_flow._arrival_tutorial_busy: return
	var before_tick := Service.snapshot(SaveManager)
	Service.tick(SaveManager, delta)
	cold_dirty = cold_dirty or before_tick != Service.snapshot(SaveManager)
	checkpoint += delta
	if checkpoint >= 1.0:
		checkpoint = 0
		var state := Service.snapshot(SaveManager)
		if cold_dirty and Service.commit(SaveManager, state).success: cold_dirty = false
	if is_instance_valid(held_label):
		var cup: Dictionary = Service.snapshot(SaveManager).held
		held_label.text = ""

func cart() -> void:
	if Service.snapshot(SaveManager).held.get("phase", "") == "pouring":
		if not Service.discard(SaveManager).success:
			hud.show_toast("保存失败，请重试")
			return
	if SaveManager.hands_occupied():
		hud.show_toast("请先放下、交付或丢弃手中的物品")
		return
	hud._lock_player()
	modal.open()

func discard() -> bool:
	if Service.snapshot(SaveManager).held.is_empty(): return false
	if not is_instance_valid(hud._player) or hud._player.input_locked: return true
	hud._lock_player()
	discard_modal.present({"甘露水":1})
	return true

func serve(id: String = "") -> bool:
	if Service.snapshot(SaveManager).held.is_empty(): return false
	if id.is_empty():
		hud.show_toast("请靠近要交付的顾客")
		return true
	var balance_before := Vector2i(SaveManager.gold_balance(),SaveManager.reputation())
	var result := Service.deliver(SaveManager, id)
	if result.success:
		if not result.get("angry", false) and not result.get("question", false) and float(result.get("factor", 0.0)) >= 1.0:
			GameAudio.play_served(&"water")
		hud.show_balance_change(balance_before)
		if result.get("question", false):
			hud.customer_flow.show_feedback(id,"question")
		if not result.get("angry",false) and not result.get("question",false) and float(result.get("factor",1.0)) < 1.0:
			hud.customer_flow.show_feedback(id,"bad_drink")
		hud.customer_flow._sync()
	else: hud.show_toast("空杯无法交付，请到垃圾桶丢弃" if result.reason == "empty_cup" else "当前无法交付，请重试")
	return true

func can_use_freezer() -> bool:
	if not is_instance_valid(freezer_view) or not SaveManager.freezer_unlocked() or TutorialManager.active: return false
	if not is_instance_valid(hud._player) or hud._player.input_locked: return false
	if is_instance_valid(hud.exploration_guide) and not hud.exploration_guide.allows_world_interaction("冰柜"): return false
	return hud._player.nearest_interactable() == freezer_view.get_parent()

func use_slot(index: int) -> void:
	if not can_use_freezer(): return
	if index != freezer_view.nearest_slot(): return
	if Service.chilling(Service.snapshot(SaveManager).slots[index]): return
	GameAudio.interaction()
	var result := Service.slot(SaveManager, index)
	if not result.success:
		hud.show_toast("请先端走手中的甘露水" if result.reason == "hands_full" else "请先到小餐车倒一杯甘露水" if result.reason == "empty_cup" else "冰镇操作未保存，请重试")

func freezer_action() -> void:
	if not can_use_freezer(): return
	use_slot(freezer_view.nearest_slot())

func food_freezer() -> void:
	if not can_use_freezer(): return
	hud._lock_player()
	hud.freezer.open()
