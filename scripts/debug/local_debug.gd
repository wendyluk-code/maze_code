extends CanvasLayer
## 隐藏的本地调试入口，仅调试构建启用；暂停并保留原暂停状态。
const Growth = preload("res://scripts/characters/character_progression.gd")
const Run = preload("res://scripts/maze/capture_run.gd")
var buffer := ""
var last_digit := 0
var down: Dictionary = {}
var panel: Control
var status: Label
var amount: SpinBox
var was_paused := false
var previous_focus: Control
var blocked_inputs: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	_build()

func _process(_delta: float) -> void:
	# 轮询物理键，确保底层模态窗吞掉输入事件时仍可唤出。
	for digit in 10:
		for code in [KEY_0 + digit, KEY_KP_0 + digit]:
			var pressed := Input.is_physical_key_pressed(code)
			if pressed and not down.get(code, false): _digit(str(digit))
			down[code] = pressed

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build(): return
	if not panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode < KEY_0 or event.keycode > KEY_9:
			if event.keycode < KEY_KP_0 or event.keycode > KEY_KP_9: buffer = ""
	if panel.visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func _digit(value: String) -> void:
	if panel.visible: return
	var now := Time.get_ticks_msec()
	if now - last_digit > 3000: buffer = ""
	last_digit = now
	buffer = (buffer + value).right(5)
	if buffer == "78789":
		buffer = ""
		open_panel()

func _build() -> void:
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := PanelContainer.new()
	box.theme = SproutTheme.make_theme()
	box.add_theme_stylebox_override("panel", SproutTheme.panel_style(Color("#fff2d4")))
	box.custom_minimum_size = Vector2(540, 440)
	center.add_child(box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	box.add_child(rows)
	var title := Label.new()
	title.text = "本地调试工具"
	title.add_theme_font_size_override("font_size", 28)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "修改当前本地存档 · 游戏已暂停\n饱腹度仅作用于当前队伍，不超过角色上限"
	rows.add_child(hint)
	amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 1000000
	amount.value = 1000
	rows.add_child(amount)
	for entry in [["金币", "gold"], ["星尘", "dust"], ["队伍饱腹度", "food"], ["补满队伍饱腹度", "fill_food"]]:
		var button := SproutButton.new()
		button.configure(entry[0] if entry[1] == "fill_food" else "增加" + entry[0])
		button.set_icon_visible(false)
		button.pressed.connect(func():
			var result := grant(entry[1], int(amount.value))
			status.text = result.message
		)
		rows.add_child(button)
	status = Label.new()
	status.text = ""
	rows.add_child(status)
	var close := SproutButton.new()
	close.configure("关闭（Esc）")
	close.set_icon_visible(false)
	close.pressed.connect(close_panel)
	rows.add_child(close)
	panel.hide()

func open_panel() -> void:
	if not OS.is_debug_build() or panel.visible: return
	previous_focus = get_viewport().gui_get_focus_owner()
	was_paused = get_tree().paused
	get_tree().paused = true
	_block_inputs(get_tree().root)
	panel.show()
	status.text = "金币 %d　星尘 %d" % [SaveManager.gold_balance(), SaveManager.stardust_balance()]
	amount.get_line_edit().grab_focus()

func close_panel() -> void:
	if not is_instance_valid(panel) or not panel.visible: return
	panel.hide()
	for entry in blocked_inputs:
		if not is_instance_valid(entry.node): continue
		var node: Node = entry.node
		node.set_process_input(entry.input)
		node.set_process_shortcut_input(entry.shortcut)
		node.set_process_unhandled_input(entry.unhandled)
		node.set_process_unhandled_key_input(entry.key)
	blocked_inputs.clear()
	get_tree().paused = was_paused
	buffer = ""
	if is_instance_valid(previous_focus): previous_focus.grab_focus()

func _block_inputs(node: Node) -> void:
	if node == self: return
	blocked_inputs.append({"node": node, "input": node.is_processing_input(), "shortcut": node.is_processing_shortcut_input(), "unhandled": node.is_processing_unhandled_input(), "key": node.is_processing_unhandled_key_input()})
	node.set_process_input(false)
	node.set_process_shortcut_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child in node.get_children(): _block_inputs(child)

func grant(kind: String, value: int) -> Dictionary:
	if not OS.is_debug_build() or value < 1 or value > 1000000: return {"success": false, "message": "数量无效"}
	var sm := get_node("/root/SaveManager")
	if sm._replaying or sm._prologue_preview: return {"success": false, "message": "重播预览中不能修改存档"}
	var before: Dictionary = sm.data.duplicate(true)
	var next: Dictionary = before.duplicate(true)
	match kind:
		"gold":
			if not Growth._integer(next.get("gold"), 0, 9007199254740991 - value): return {"success": false, "message": "金币记录无效或超过上限"}
			next.gold = int(next.gold) + value
		"dust":
			var balance: int = sm.stardust_balance()
			if balance < 0 or balance > 9007199254740991 - value: return {"success": false, "message": "星尘记录无效或超过上限"}
			var record: Dictionary = next.get("recruitment_v1", {}).duplicate(true)
			record.stardust = balance + value
			next.recruitment_v1 = record
		"food", "fill_food":
			var food := Growth.satiety_snapshot(sm)
			var run := Run.snapshot(sm)
			var party: Array = sm.exploration_entry_party()
			if run.get("active", false):
				if not Run.valid(run): return {"success": false, "message": "探索记录无效"}
				party = []
				for member in run.members: party.append(member.id)
			if not food.valid or party.is_empty(): return {"success": false, "message": "没有可修改的当前队伍"}
			var remaining := float(value)
			for id in party:
				var stats := Growth.record(sm, id)
				if not stats.valid or not food.values.has(id): return {"success": false, "message": "角色记录无效"}
				var addition := maxf(0, float(stats.satiety_max) - float(food.values[id]))
				if kind == "food": addition = minf(addition, remaining)
				food.values[id] += addition
				remaining -= addition
			next[Growth.FOOD_KEY] = {"values": food.values, "at": food.at, "paused": food.paused}
			if run.get("active", false):
				run.satiety = Run._party_food(food, run.members)
				next[Run.KEY] = run
		_:
			return {"success": false, "message": "未知资源"}
	sm.data = next
	if not sm.save():
		sm.data = before
		return {"success": false, "message": "保存失败，修改已撤回"}
	return {"success": true, "message": "已增加并保存（饱腹度不超过上限）"}
