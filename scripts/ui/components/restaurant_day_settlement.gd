extends SproutModal
## 已确认v11布局，1000×550设计坐标；只展示持久回执。
const Cycle := preload("res://scripts/restaurant/service_cycle.gd")
const Day := preload("res://scripts/restaurant/restaurant_day.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
const Icons := preload("res://scripts/ui/components/bag_icon_display.gd")
const Currency := preload("res://scripts/ui/components/resource_counter.gd")
const Chart := preload("res://scripts/ui/components/restaurant_day_chart.gd")
var content: Control
var summary: Panel
var chart: Control
var loss_scroll: ScrollContainer
var review: Label
var history: Array = []
var current_stats := {}
var intro: TextureRect
var introducing := false

func open_with_intro(stats: Dictionary) -> void:
	open(stats)
	introducing = true
	_confirm_button.disabled = true
	_confirm_button.release_focus()
	chart.stop_animation()
	chart._apply_progress(0.0)
	intro = preload("res://scripts/ui/components/restaurant_settlement_intro.gd").new()
	add_child(intro)
	intro.finished.connect(func():
		introducing = false
		_confirm_button.disabled = false
		_confirm_button.grab_focus()
		chart.set_process(true))
	intro.start(self,bool(stats.get("closed_day",false)))

static func review_text(stats: Dictionary) -> String:
	if stats.get("closed_day",false): return "今日歇业\n金币与声望变化均为0"
	if not stats.get("portions_complete",false): return "旧存档缺少完整损耗记录\n无法确认本日料理损耗"
	if int(stats.get("menu_sold",0))==0: return "今天的料理都损耗了，\n下次留意接单和上菜时间吧！"
	if stats.get("losses",{}).is_empty(): return "今天的料理全部售出，\n一点也没浪费！"
	return "今天有部分料理损耗了，\n下次合理安排备餐与上菜吧！"

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	var style := SproutTheme.thin_panel_style(SproutTheme.PANEL)
	style.set_content_margin_all(0)
	_panel.add_theme_stylebox_override("panel",style)
	add_child(_panel)
	content = Control.new()
	content.custom_minimum_size = Vector2(1000,550)
	_panel.add_child(content)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	if not is_instance_valid(_panel): return
	var factor := minf(get_viewport_rect().size.x/1280.0,get_viewport_rect().size.y/720.0)
	_panel.scale = Vector2.ONE * factor
	_panel.size = Vector2(1000,550)
	_panel.position = (get_viewport_rect().size-Vector2(1000,550)*factor)*0.5

func _place(node: Control, parent: Control, rect: Rect2) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func _label(parent: Control, text: String, rect: Rect2, font_size := 20, centered := false, ink := SproutTheme.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",ink)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(label,parent,rect)
	return label

func _icon(parent: Control, texture: Texture2D, rect: Rect2) -> void:
	var icon := TextureRect.new()
	icon.texture = Icons.texture(texture)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(icon,parent,rect)

func open(stats: Dictionary) -> void:
	if is_instance_valid(intro):
		intro.motion.kill()
		remove_child(intro)
		intro.queue_free()
	introducing = false
	_panel.pivot_offset = Vector2.ZERO
	_panel.show()
	if is_instance_valid(chart): chart.stop_animation()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	current_stats = stats.duplicate(true)
	history = Day.settlement_history(SaveManager,stats)
	_title_label = _label(content,"今日营业结算",Rect2(60,14,880,46),30,true)
	_label(content,"第 %d 天" % int(stats.get("day",1)),Rect2(32,61,936,28),18,true,SproutTheme.INK_MUTED)
	summary = Panel.new()
	summary.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style())
	_place(summary,content,Rect2(24,104,316,344))
	_icon(summary,Currency.GOLD,Rect2(18,18,34,34))
	_label(summary,"金币",Rect2(64,17,90,36),22)
	var income_label := _label(summary,str(int(stats.get("income",0))),Rect2(184,12,110,44),32)
	while income_label.get_theme_font("font").get_string_size(income_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,income_label.get_theme_font_size("font_size")).x>110 and income_label.get_theme_font_size("font_size")>14:
		income_label.add_theme_font_size_override("font_size",income_label.get_theme_font_size("font_size")-2)
	_icon(summary,Currency.REPUTATION,Rect2(18,69,34,34))
	_label(summary,"声望",Rect2(64,68,90,36),22)
	var reputation_label := _label(summary,"%+d" % int(stats.get("reputation",0)),Rect2(184,63,110,44),28)
	summary.tooltip_text = "本日营业收入：%d\n扣款：%d\n净金币变化：%+d\n已完成料理单：%d" % [int(stats.get("income",0)),int(stats.get("deductions",0)),int(stats.get("net",0)),int(stats.get("completed",0))]
	var losses: Dictionary = stats.get("losses",{})
	var known := bool(stats.get("losses_known",false))
	loss_scroll = null
	if losses.is_empty():
		review = _label(summary,review_text(stats),Rect2(18,116,280,212),20,true,SproutTheme.INK_MUTED)
	else:
		_label(summary,"损耗" if known else "已记录损耗",Rect2(18,116,280,28),21)
		loss_scroll = ScrollContainer.new()
		loss_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_place(loss_scroll,summary,Rect2(14,151,288,120))
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation",0)
		loss_scroll.add_child(list)
		for id in losses:
			if int(losses[id])<=0: continue
			var row := Control.new()
			row.custom_minimum_size = Vector2(268,40)
			list.add_child(row)
			_icon(row,Recipes.item_texture(id),Rect2(0,3,34,34))
			var name_label := _label(row,str(Recipes.get_recipe(id).get("name",id)),Rect2(42,0,176,40),18)
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			name_label.tooltip_text = name_label.text
			_label(row,"× %d" % int(losses[id]),Rect2(222,0,46,40),19)
		var rule := ColorRect.new()
		rule.color = Color("e1d3b7")
		_place(rule,summary,Rect2(18,280,280,1))
		review = _label(summary,review_text(stats),Rect2(18,290,280,48),17,false,SproutTheme.INK_MUTED)
	chart = Chart.new()
	chart.entries = history
	chart.today = int(stats.get("day",1))
	_place(chart,content,Rect2(354,104,622,344))
	var income := int(current_stats.get("income",0))
	var reputation := int(current_stats.get("reputation",0))
	income_label.text = "0"
	reputation_label.text = "0"
	chart.animation_progress.connect(func(value: float):
		income_label.text = str(roundi(income*value))
		var shown_rep := roundi(reputation*value)
		reputation_label.text = "%+d" % shown_rep if shown_rep!=0 else "0"
	)
	_icon(chart,Currency.GOLD,Rect2(500,16,26,26))
	_icon(chart,Currency.REPUTATION,Rect2(576,16,26,26))
	_body_label = _label(content,"旧存档：仅展示可确认的本日回执与历史" if stats.get("legacy",false) else "",Rect2(24,448,952,25),14,true,SproutTheme.INK_MUTED)
	_confirm_button = SproutButton.new().set_icon_visible(false).set_focus_visual(false)
	_confirm_button.text = "明日准备"
	_confirm_button.add_theme_stylebox_override("normal",SproutTheme.selected_style())
	_place(_confirm_button,content,Rect2(400,473,200,52))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	show()
	if not stats.get("closed_day",false):
		GameAudio.business_completed(SaveManager._active_save_path, int(stats.get("day",1)))
	_layout()
	_confirm_button.grab_focus()

func close_modal() -> void:
	if not visible or introducing: return
	if Cycle.acknowledge_settlement(SaveManager).success:
		chart.stop_animation()
		super.close_modal()
	else:
		_body_label.text = "保存失败，请再次点击明日准备；账目不会重复结算"
		_body_label.show()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_ESCAPE]: close_modal()
