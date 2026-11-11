extends Control

signal requested
var status_label: Label
var details_label: Label
var end_button: Button
var end_confirmation: Control
var _confirm_hud: Node
var _old_busy := false

class PlayButton extends Button:
	func _ready() -> void:
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	func _draw() -> void:
		var triangle := PackedVector2Array([Vector2(11, 10), Vector2(11, 24), Vector2(22, 17)])
		draw_colored_polygon(triangle, Color("607e43"))
		triangle.append(triangle[0])
		draw_polyline(triangle, Color("4e6638"), 1.0, true)

class PauseButton extends PlayButton:
	func _draw() -> void:
		for x in [11,20]: draw_rect(Rect2(x,10,4,14),Color("607e43"))

func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -90
	offset_right = 90
	offset_top = 0
	offset_bottom = 80
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := TextureRect.new()
	background.name = "HangingBoard"
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/restaurant_day/hanging_sign.png")
	# 裁掉长绳上段，保留绳结与完整牌身；按素材原比例显示，不压扁木牌。
	atlas.region = Rect2(315, 160, 1545, 490)
	background.texture = atlas
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = Vector2(180, 180.0 * 490.0 / 1545.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	status_label = Label.new()
	status_label.name = "Status"
	status_label.theme = SproutTheme.make_theme()
	status_label.position = Vector2(0, 20)
	status_label.size = Vector2(180, 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	var button := PlayButton.new()
	button.name = "OpenMenu"
	button.tooltip_text = "选择今日菜单"
	button.position = Vector2(140, 18)
	button.size = Vector2(34, 34)
	button.pressed.connect(func(): requested.emit())
	add_child(button)
	details_label = Label.new()
	details_label.name = "DayAndCountdown"
	details_label.theme = SproutTheme.make_theme()
	details_label.position = Vector2(-20, 56)
	details_label.size = Vector2(220, 22)
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.add_theme_color_override("font_color", SproutTheme.CREAM)
	details_label.add_theme_color_override("font_outline_color", SproutTheme.INK)
	details_label.add_theme_constant_override("outline_size", 2)
	details_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(details_label)
	end_button = PauseButton.new()
	end_button.name = "EndBusiness"
	end_button.tooltip_text = "主动结束今日营业"
	end_button.position = button.position
	end_button.size = button.size
	end_button.theme = SproutTheme.make_theme()
	add_child(end_button)
	end_button.pressed.connect(_request_end)
	end_confirmation = preload("res://scripts/ui/components/destination_confirmation.gd").new()
	var hud := get_tree().get_first_node_in_group("restaurant_hud")
	var modal_root: Node = hud.get_child(0) if is_instance_valid(hud) else get_parent()
	modal_root.add_child.call_deferred(end_confirmation)
	end_confirmation.cancelled.connect(_cancel_end)
	end_confirmation.confirmed.connect(_confirm_end)
	set_display(int(preload("res://scripts/restaurant/restaurant_day.gd").snapshot(SaveManager).get("day", 1)))

## 仅显示调用方提供的真实剩余时间；准备阶段不伪造倒计时。
func set_display(day: int, remaining_seconds: int = -1) -> void:
	status_label.text = "营业中" if remaining_seconds >= 0 else "准备中"
	var clock := "%02d:%02d" % [remaining_seconds / 60, remaining_seconds % 60] if remaining_seconds >= 0 else "--:--"
	details_label.text = "第 %d 天  ·  倒计时 %s" % [day, clock]

func _process(_delta: float) -> void:
	var day := preload("res://scripts/restaurant/restaurant_day.gd").snapshot(SaveManager)
	visible = SaveManager.is_chapter_1_done() and SaveManager.chapter_1_outro_state() == "done" and not preload("res://scripts/maze/first_exploration.gd").pending(SaveManager)
	get_node("OpenMenu").visible = day.get("status") not in ["open","closing"]
	end_button.visible = visible and day.get("status")=="open"
	if day.get("status") in ["open","closing"]:
		set_display(int(day.get("day",1)),int(ceil(float(day.get("remaining",0)))))
		if day.status == "closing":
			status_label.text = "结算中"
			details_label.text = "第 %d 天" % int(day.get("day",1))
	else:
		set_display(int(day.get("day",1)))
		if int(day.get("day",1))>=2:
			var seconds := int(ceil(float(day.get("preparation_left",3600.0))))
			details_label.text = "第 %d 天  ·  倒计时 %02d:%02d" % [int(day.day),seconds/60,seconds%60]

func _request_end() -> void:
	var hud = get_tree().get_first_node_in_group("restaurant_hud")
	if not is_instance_valid(hud) or not is_instance_valid(hud._player) or hud._player.input_locked or TutorialManager.active: return
	if preload("res://scripts/restaurant/restaurant_day.gd").snapshot(SaveManager).get("status")!="open": return
	_confirm_hud = hud
	_old_busy = hud.customer_flow.busy
	hud.customer_flow.busy = true
	hud._lock_player()
	end_confirmation.open_confirmation("确定结束今日营业？","结束营业","继续营业")
	end_confirmation.confirm_button.get_parent().alignment = BoxContainer.ALIGNMENT_CENTER

func _cancel_end() -> void:
	end_confirmation.hide()
	if is_instance_valid(_confirm_hud):
		_confirm_hud.customer_flow.busy = _old_busy
		_confirm_hud._unlock_player()
	_confirm_hud = null

func _confirm_end() -> void:
	var result := preload("res://scripts/restaurant/service_cycle.gd").settle(SaveManager,"manual")
	if result.success: _cancel_end()
	else:
		end_confirmation.question.text = "保存失败，请重试；库存与账目未改变。" if result.reason=="save_failed" else "菜单归属与库存不一致，未扣除物品。请检查存档后重试。"
