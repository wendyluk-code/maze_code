extends Node
## 餐厅专用丢弃流程。所有状态写入由 SaveManager 的单次原子事务负责。
var hud: Node
var confirmation: Control
var _expected := {}
var _open := false
var _saving := false
var _toast_z_before := 0

func _ready() -> void:
	confirmation = preload("res://scripts/restaurant/discard_confirmation.gd").new()
	get_parent().add_child.call_deferred(confirmation)
	confirmation.cancelled.connect(close)
	confirmation.confirmed.connect(_confirm)

func request(target: Node2D) -> void:
	var player: Node = hud._player
	if _open or not is_instance_valid(player) or player.input_locked or not player.is_physics_processing():
		return
	if player.nearest_interactable() != target or hud.Transition.is_active(get_tree()):
		return
	if not SaveManager.can_discard_carried_food():
		# 第一章已有统一的错误目标提示；同一 interacted 信号不叠两个提示。
		if not TutorialManager.active:
			hud.show_toast("请先完成当前任务")
		return
	if TutorialManager.active or SaveManager.cooking_state().status == "active":
		return
	if is_instance_valid(hud.exploration_guide) and not hud.exploration_guide.allows_world_interaction("垃圾桶"):
		return
	_expected = SaveManager.discardable_carried_items()
	if _expected.is_empty():
		hud.show_toast("没有可丢弃的食材或料理")
		return
	hud.toast_label.dismiss()
	_toast_z_before = hud.toast_label.z_index
	hud.toast_label.z_index = maxi(1, _toast_z_before)
	hud._lock_player()
	_open = true
	confirmation.present(_expected)

func close() -> void:
	if not _open or _saving:
		return
	confirmation.hide()
	hud.toast_label.z_index = _toast_z_before
	_open = false
	_expected.clear()
	hud._unlock_player()

func _confirm() -> void:
	if not _open or _saving:
		return
	_saving = true
	var result := SaveManager.discard_carried_food(_expected)
	_saving = false
	if result.success:
		close()
		hud.show_toast("已丢弃")
	elif result.reason == "save_failed":
		hud.show_toast("保存失败，物品未丢弃，请重试")
	else:
		close()
		hud.show_toast("随身物品已变化，请重新确认" if result.reason == "changed" else "暂时无法丢弃")

func _exit_tree() -> void:
	if _open and is_instance_valid(hud):
		hud._unlock_player()
