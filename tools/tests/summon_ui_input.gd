extends Node
## 召唤组件真实渲染与输入验收；模拟余额只注入组件，不触碰玩家存档。
const SummonPanel := preload("res://scripts/ui/components/summon_panel.gd")
var gold := 0
var requests: Array = []
var checks: Array = []
var failed := 0
var panel: Control
var evidence := "res://output/summon_ui"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var background := TextureRect.new()
	background.texture = load("res://assets/maps/adventurer_home_collection.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var design := Control.new()
	design.size = Vector2(1280, 720)
	root.add_child(design)
	panel = SummonPanel.new()
	panel.z_index = 0
	panel.balance_reader = func(): return gold
	panel.summon_requested.connect(func(count, cost): requests.append([count, cost]))
	design.add_child(panel)
	for index in 2:
		var tab = load("res://scripts/ui/components/home_sign_tab.gd").new()
		tab.text = "角色簿" if index == 0 else "召唤"
		tab.position = Vector2(36, 174 + index * 82)
		tab.z_index = 3
		design.add_child(tab)
		tab.set_selected(index == 1)
	var fence := TextureRect.new()
	fence.texture = load("res://assets/ui/home_collection/fence_foreground.png")
	fence.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fence.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fence)
	fence.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for resolution in [Vector2i(1152, 648), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(resolution)
		await get_tree().create_timer(0.15).timeout
		design.scale = Vector2.ONE * float(resolution.x) / 1280.0
		for amount in [0, 999, 1000, 8999, 9000, 10000]:
			gold = amount
			await get_tree().create_timer(0.25).timeout
			_check(panel.single_button.disabled == (amount < 1000), "单抽余额边界 %d" % amount)
			_check(panel.ten_button.disabled == (amount < 9000), "十连余额边界 %d" % amount)
			_check(panel.single_price.get_theme_color("font_color") == (panel.SHORTAGE_COLOR if amount < 1000 else panel.PRICE_COLOR), "单抽价格颜色 %d" % amount)
			var color: Color = panel.SHORTAGE_COLOR if amount < 9000 else panel.PRICE_COLOR
			_check(panel.ten_price.text.contains(color.to_html(false)) and panel.ten_price.text.contains("[s]10000[/s]"), "十连价格颜色和原价划线 %d" % amount)
			var before := requests.size()
			await _click(panel.single_button)
			await _click(panel.ten_button)
			_check(requests.size() - before == int(amount >= 1000) + int(amount >= 9000), "真实鼠标：不足按钮不能触发 %d" % amount)
			if amount in [999, 1000, 9000]:
				get_viewport().warp_mouse(Vector2(10, 10))
				if get_viewport().gui_get_focus_owner(): get_viewport().gui_get_focus_owner().release_focus()
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(evidence.path_join("component_%d_%dx%d.png" % [amount, resolution.x, resolution.y]))
		gold = 1000
		panel.refresh_balance()
		panel.single_button.grab_focus()
		var before := requests.size()
		await _key(KEY_ENTER)
		_check(requests.size() == before + 1, "键盘Enter单抽触发一次")
		gold = 0
		panel._request_summon(1, 1000)
		_check(requests.size() == before + 1, "激活边界重新读取余额，阻止过期点击")
	var result := {"failures": failed, "checks": checks, "display": DisplayServer.get_name()}
	var report := FileAccess.open(evidence.path_join("component-report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "\t"))
	print("SUMMON_UI: ", checks.size(), " checks, ", failed, " failures")
	get_tree().quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	checks.append({"passed": ok, "label": label})
	if not ok:
		failed += 1
		push_error(label)

func _click(button: Control) -> void:
	var at := button.get_global_rect().get_center()
	get_viewport().warp_mouse(at)
	await get_tree().process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
