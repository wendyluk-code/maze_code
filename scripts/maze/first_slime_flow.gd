extends Node
const Transition := preload("res://scripts/ui/components/scene_transition.gd")
## 首场遭遇的界面编排；复用公共对白与物品领取框。
var maze: Node2D
var shield: Control
var dialog: Control
var phase := "idle"
var armed := false
var locked_before := false
var physics_before := true

func attach(host: Node2D) -> void:
	maze = host
	shield = Control.new()
	maze._ui_root.add_child(shield)
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	shield.hide()
	dialog = preload("res://scenes/ui/dialog_box.tscn").instantiate()
	shield.add_child(dialog)
	dialog.set_process_input(false)
	dialog.set_process_unhandled_input(false)
	dialog.finished.connect(_finished)
	dialog.hide_box()
	maze.loot_modal.closed.connect(_reward_closed)
	# 奖励框必须在对白遮罩上方，保留公共布局和鼠标命中。
	maze._ui_root.move_child(maze.loot_modal, -1)

func _process(_delta: float) -> void:
	if not is_instance_valid(maze): return
	var status: String = SaveManager.first_slime_state().get("status", "unseen")
	maze.slime.visible = status not in ["rewarded", "after_dialog", "completed"]
	if phase != "idle" or not maze._entry_ready or maze._busy or maze.player.input_locked or maze.confirmation.visible or maze.map_ui.expanded or maze.elder.is_busy() or maze.yufeng_salia.is_busy(): return
	if status == "battle":
		# 中断的战斗重新开始，不推断胜利、不发奖。
		_lock()
		phase = "transition"
		get_tree().set_meta("first_slime_battle_source", true)
		var error: int = await Transition.change_scene(get_tree(), load("res://scenes/battle/yaya_battle_demo.tscn"))
		if error != OK:
			get_tree().remove_meta("first_slime_battle_source")
			_unlock()
	elif status == "rewarded":
		_lock()
		phase = "reward"
		var items: Array[Dictionary] = [
			{"name": "史莱姆凝胶", "quantity": 4, "icon": preload("res://assets/ui/ingredients/slime_gel.png")},
			{"name": "金币", "quantity": 20, "icon": preload("res://scripts/ui/components/loot_modal.gd").coin_texture()},
		]
		maze.loot_modal.show_items(items)
		# 等待容器完成排版，仅补偿凝胶扁平主体的视觉大小。
		await get_tree().process_frame
		var gel_icon: TextureRect = maze.loot_modal.item_views[0].icon
		gel_icon.pivot_offset = gel_icon.size * 0.5
		gel_icon.scale = Vector2.ONE * 1.4
	elif status == "after_dialog":
		_lock()
		_say_after()
	elif status == "unseen" and maze.player.position.distance_to(maze.slime.position) <= 48.0:
		_lock()
		phase = "before"
		dialog.start("芽芽", ["前方有魔物，小心！"], preload("res://assets/characters/yaya_portrait.png"))

func _lock() -> void:
	locked_before = maze.player.input_locked
	physics_before = maze.player.is_physics_processing()
	maze._busy = true
	maze.player.input_locked = true
	maze.player.set_physics_process(false)
	maze.toast_label.dismiss()
	shield.show()
	armed = not Input.is_action_pressed("interact")

func _input(event: InputEvent) -> void:
	if phase not in ["before", "after"]: return
	if event.is_action_released("interact"): armed = true
	if event.is_action_pressed("interact") and not event.is_echo() and armed:
		armed = false
		dialog._advance()
	get_viewport().set_input_as_handled()

func _finished() -> void:
	dialog.hide_box()
	if phase == "before":
		if not SaveManager.begin_first_slime(maze.player.position).success:
			maze.show_toast("战斗进度保存失败，请重试")
			_unlock()
			return
		phase = "transition"
		get_tree().set_meta("first_slime_battle_source", true)
		var error: int = await Transition.change_scene(get_tree(), load("res://scenes/battle/yaya_battle_demo.tscn"))
		if error != OK:
			get_tree().remove_meta("first_slime_battle_source")
			SaveManager.settle_first_slime(false)
			_unlock()
	elif phase == "after":
		if not SaveManager.mark_first_slime_after_dialog():
			_say_after()
			maze.show_toast("进度保存失败，请再次确认")
			return
		_unlock()

func _reward_closed() -> void:
	if phase != "reward": return
	if not SaveManager.mark_first_slime_reward_seen():
		_unlock()
		maze.show_toast("领取进度保存失败，请再次收下")
		return
	# 原宝箱关闭回调先执行；重新持有本流程输入锁。
	maze._busy = true
	maze.player.input_locked = true
	maze.player.set_physics_process(false)
	_say_after()

func _say_after() -> void:
	phase = "after"
	armed = not Input.is_action_pressed("interact")
	dialog.start("芽芽", ["终于打到它了，我们继续向前走吧。"], preload("res://assets/characters/yaya_portrait.png"))

func _unlock() -> void:
	phase = "idle"
	shield.hide()
	maze._busy = false
	maze.player.input_locked = locked_before
	maze.player.set_physics_process(physics_before)
	maze._interact_armed = not Input.is_action_pressed("interact")
