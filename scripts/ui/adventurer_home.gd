extends CanvasLayer
## 独立全屏页面保留餐厅实例；关闭后恢复原处理模式、人物站位和经营状态。
const BackButton := preload("res://scripts/ui/components/sprout_back_button.gd")
const ResourceCounter := preload("res://scripts/ui/components/resource_counter.gd")
const SummonPanel := preload("res://scripts/ui/components/summon_panel.gd")
const FeedbackToast := preload("res://scripts/ui/components/feedback_toast.gd")
var summon_panel: Control
var summon_toast: Label
var gold_counter: ResourceCounter
var dust_counter: ResourceCounter
var recruit_results: Control
var _summoning := false
const Growth = preload("res://scripts/characters/character_progression.gd")
const SignTab := preload("res://scripts/ui/components/home_sign_tab.gd")
const ART_ROOT := "res://assets/ui/home_collection/"
const COLLECTION_PORTRAITS := ["yufeng", "jiaopopo", "ahong", "xiluomei", "chengyan", "lanjiao"]
const CardsModal := preload("res://scripts/ui/components/character_details_modal.gd")
const PORTRAIT_PAPER := Color("#f5f0e6")
const SHEET_WASH := Color(0.98, 0.94, 0.84, 0.56)
var cards_modal: Control
var _selected_card: Button
var back_button: Button
var character_buttons: Dictionary = {}
var slots: Array[Button] = []
var tabs: Array[Button] = []
var selected_tab := 0
var design: Control
var collection_scroll: ScrollContainer
var collection_grid: GridContainer
var acquire_hint: Label
var collection_heading: Label
var collection_frame: Panel
var _restaurant: Node
var _previous_process_mode: int
var _closing := false

static func open_page(tree: SceneTree) -> void:
	if is_instance_valid(tree.get_first_node_in_group("adventurer_home")):
		return
	var page: CanvasLayer = load("res://scenes/adventurer_home.tscn").instantiate()
	page._restaurant = tree.current_scene
	tree.root.add_child(page)

func _ready() -> void:
	add_to_group("adventurer_home")
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(_restaurant):
		_previous_process_mode = _restaurant.process_mode
		_restaurant.process_mode = Node.PROCESS_MODE_DISABLED
	_install_collection()
	back_button = BackButton.new()
	back_button.name = "BackButton"
	$Page.add_child(back_button)
	back_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	back_button.offset_left = 24
	back_button.offset_right = 80
	back_button.offset_top = 24
	back_button.offset_bottom = 80
	back_button.pressed.connect(close_page)
	gold_counter = ResourceCounter.new()
	gold_counter.name = "GoldCounter"
	gold_counter.configure(ResourceCounter.GOLD)
	$Page.add_child(gold_counter)
	gold_counter.position = Vector2(100, 34)
	gold_counter.set_value(SaveManager.gold_balance())
	dust_counter = ResourceCounter.new()
	dust_counter.configure(preload("res://assets/ui/recruitment/stardust.png"))
	$Page.add_child(dust_counter)
	dust_counter.position = Vector2(260, 34)
	summon_toast = FeedbackToast.attach_to($Page)
	# 详情拥有独立画布，主页面的页签/前景z_index不能越过全屏遮罩。
	var details_layer := CanvasLayer.new()
	details_layer.name = "CharacterDetailsLayer"
	details_layer.layer = layer + 1
	add_child(details_layer)
	cards_modal = CardsModal.new()
	details_layer.add_child(cards_modal)
	cards_modal.closed.connect(_cards_closed)
	recruit_results = preload("res://scripts/ui/components/recruit_results.gd").new()
	details_layer.add_child(recruit_results)
	recruit_results.closed.connect(_recruit_closed)
	$Page.resized.connect(_layout_collection)
	_layout_collection()

func _process(_delta: float) -> void:
	gold_counter.set_value(SaveManager.gold_balance())
	dust_counter.position.x = gold_counter.position.x + gold_counter.size.x + 24
	dust_counter.set_value(SaveManager.stardust_balance())

func _install_collection() -> void:
	design = Control.new()
	design.size = Vector2(1280, 720)
	design.theme = SproutTheme.make_theme()
	$Page.add_child(design)
	var frame := Panel.new()
	collection_frame = frame
	frame.position = Vector2(128, 108)
	frame.size = Vector2(1106, 480)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := SproutTheme.thin_panel_style(SHEET_WASH)
	frame_style.border_color = Color(1.0, 0.96, 0.85, 0.7)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(18)
	frame_style.shadow_color = Color(0.22, 0.13, 0.06, 0.16)
	frame_style.shadow_size = 10
	frame.add_theme_stylebox_override("panel", frame_style)
	design.add_child(frame)
	for index in 2:
		var tab := SignTab.new()
		tab.text = "角色簿" if index == 0 else "招募"
		tab.position = Vector2(36, 174 + index * 82)
		tab.z_index = 3
		design.add_child(tab)
		tab.pressed.connect(_select_tab.bind(index))
		tabs.append(tab)
	collection_heading = Label.new()
	collection_heading.position = Vector2(234, 128)
	collection_heading.size = Vector2(358, 35)
	collection_heading.add_theme_font_size_override("font_size", 23)
	collection_heading.add_theme_color_override("font_color", SproutTheme.INK)
	collection_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(collection_heading)
	_art(design, "header_leaf", Vector2(181, 123), Vector2(35, 45))
	_art(design, "header_rule", Vector2(603, 126), Vector2(591, 41))
	collection_scroll = ScrollContainer.new()
	collection_scroll.position = Vector2(234, 178)
	collection_scroll.size = Vector2(954, 340)
	collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	collection_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	collection_scroll.follow_focus = true
	design.add_child(collection_scroll)
	collection_grid = GridContainer.new()
	collection_grid.columns = 4
	collection_grid.add_theme_constant_override("h_separation", 23)
	collection_grid.add_theme_constant_override("v_separation", 16)
	collection_scroll.add_child(collection_grid)
	_refresh_collection()
	acquire_hint = Label.new()
	acquire_hint.text = "招募暂未开放"
	acquire_hint.position = Vector2(288, 300)
	acquire_hint.size = Vector2(916, 60)
	acquire_hint.add_theme_color_override("font_color", SproutTheme.INK)
	acquire_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	acquire_hint.add_theme_font_size_override("font_size", 28)
	design.add_child(acquire_hint)
	acquire_hint.hide()
	summon_panel = SummonPanel.new()
	# 招募内容在原位栅栏后方，通过头侧姓名与上移操作区避让前景。
	summon_panel.z_index = 0
	summon_panel.balance_reader = SaveManager.gold_balance
	design.add_child(summon_panel)
	summon_panel.summon_requested.connect(_on_summon_requested)
	# 透明轮廓前景与背景使用完全相同的适配；绘制在主页面之后、卡牌蒙层之前。
	var foreground_fence := TextureRect.new()
	foreground_fence.name = "ForegroundFence"
	foreground_fence.texture = load(ART_ROOT + "fence_foreground.png")
	foreground_fence.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foreground_fence.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foreground_fence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Page.add_child(foreground_fence)
	foreground_fence.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select_tab(0)

func _art(parent: Control, asset: String, at: Vector2, extent: Vector2) -> TextureRect:
	var art := TextureRect.new()
	art.name = asset.to_pascal_case()
	art.texture = load(ART_ROOT + asset + ".png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.position = at
	art.size = extent
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(art)
	return art

func _select_tab(index: int) -> void:
	selected_tab = index
	collection_frame.visible = index == 0
	collection_heading.visible = index == 0
	design.get_node("HeaderLeaf").visible = index == 0
	design.get_node("HeaderRule").visible = index == 0
	collection_heading.text = "已收录 %02d / 16" % character_buttons.size() if index == 0 else "招募"
	for i in tabs.size(): tabs[i].set_selected(i == index)
	collection_scroll.visible = index == 0
	acquire_hint.hide()
	summon_panel.visible = index == 1
	if is_instance_valid(summon_toast): summon_toast.dismiss()

func _on_summon_requested(count: int, _cost: int) -> void:
	if selected_tab != 1 or _closing or _summoning: return
	_summoning = true
	var result := SaveManager.recruit(count)
	if not result.success:
		_summoning = false
		var messages := {"insufficient_gold": "金币不足", "save_failed": "保存失败，金币与奖励均未变更", "invalid_record": "收藏数据异常，无法招募", "stardust_limit": "星尘将超出余额上限，本次招募未扣费"}
		summon_toast.show_message(messages.get(result.reason, "当前无法招募"))
		return
	summon_toast.dismiss()
	for tab in tabs: tab.disabled = true
	back_button.disabled = true
	summon_panel.single_button.disabled = true
	summon_panel.ten_button.disabled = true
	recruit_results.present(result.results)
	_refresh_collection()

func _recruit_closed() -> void:
	_summoning = false
	for tab in tabs: tab.disabled = false
	back_button.disabled = false
	summon_panel.single_button.disabled = false
	summon_panel.ten_button.disabled = false
	summon_panel._balance = -1
	summon_panel.refresh_balance()
	_select_tab(selected_tab)
	summon_panel.single_button.grab_focus()

func _layout_collection() -> void:
	if not is_instance_valid(design):
		return
	var viewport: Vector2 = $Page.size
	var fit := minf(viewport.x / 1280.0, viewport.y / 720.0)
	design.scale = Vector2.ONE * fit
	design.position = (viewport - Vector2(1280, 720) * fit) * 0.5

func _show_cards(id: String) -> void:
	if cards_modal.visible: return
	_selected_card = character_buttons.get(id)
	for button in character_buttons.values(): button.disabled = true
	for tab in tabs: tab.disabled = true
	back_button.disabled = true
	cards_modal.present(id)

func _cards_closed() -> void:
	for button in character_buttons.values(): button.disabled = false
	for tab in tabs: tab.disabled = false
	back_button.disabled = false
	if is_instance_valid(_selected_card): _selected_card.grab_focus()

func close_page() -> void:
	if _summoning:
		recruit_results._show_overview()
		return
	if is_instance_valid(cards_modal) and cards_modal.visible:
		cards_modal.close_modal()
		return
	if _closing:
		return
	_closing = true
	back_button.disabled = true
	# 下一帧才恢复餐厅，避免本次返回按键/鼠标释放透传到原场景。
	call_deferred("queue_free")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_page()
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(_restaurant):
		_restaurant.process_mode = _previous_process_mode

func _refresh_collection() -> void:
	for child in collection_grid.get_children():
		collection_grid.remove_child(child)
		child.queue_free()
	slots.clear()
	character_buttons.clear()
	var collected: Array = SaveManager.owned_characters()
	var ids: Array = collected.duplicate()
	for id in Growth.CHARACTERS:
		if not ids.has(id): ids.append(id)
	for index in maxi(16, ids.size()):
		var id: String = ids[index] if index < ids.size() else ""
		var owned := not id.is_empty() and collected.has(id)
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(216, 216)
		slot.disabled = not owned
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if owned else Control.CURSOR_ARROW
		var style := SproutTheme.thin_panel_style(Color("#dfc7a0") if owned else PORTRAIT_PAPER)
		style.set_border_width_all(3 if owned else 2)
		style.border_color = Color("#c8b18c") if owned else Color("#cfbd9f")
		style.set_corner_radius_all(10)
		style.shadow_color = Color(0.28, 0.18, 0.09, 0.18)
		style.shadow_size = 5
		for state in ["normal", "disabled", "pressed"]: slot.add_theme_stylebox_override(state, style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.border_color = Color("#bd8736")
		hover.set_border_width_all(3)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		collection_grid.add_child(slot)
		slots.append(slot)
		# 纸纹缩进边框内，避免子纹理盖住原生描边；暖米金衬边与立绘白底分开。
		var paper := _art(slot, "card_blank" if owned else "card_missing", Vector2(3, 3), Vector2(210, 210))
		if owned: paper.self_modulate = Color("#ead9b9")
		if owned:
			var portrait_clip := Control.new()
			portrait_clip.position = Vector2(8, 8)
			portrait_clip.name = "PortraitClip"
			portrait_clip.size = Vector2(200, 168)
			portrait_clip.clip_contents = true
			portrait_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(portrait_clip)
			var portrait := TextureRect.new()
			portrait.texture = load(Growth.CHARACTERS[id].portrait)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.position = Vector2(0, -12)
			portrait.size = Vector2(200, 200)
			# 用户裁好的角色簿专用头像原样显示，不影响详情和其他头像入口。
			if id in COLLECTION_PORTRAITS:
				portrait.texture = load(ART_ROOT + "portrait_" + id + ".png")
				portrait.position = Vector2.ZERO
				portrait.size = Vector2(200, 168)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait_clip.add_child(portrait)
			character_buttons[id] = slot
			slot.pressed.connect(_show_cards.bind(id))
			_art(slot, "name_tieshan" if id == "tieshan" else "name_yaya", Vector2(8, 177), Vector2(200, 31))
			var caption := Label.new()
			caption.position = Vector2(57, 177)
			caption.size = Vector2(102, 31)
			caption.text = Growth.CHARACTERS[id].name
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.add_theme_font_size_override("font_size", 22)
			caption.add_theme_color_override("font_color", SproutTheme.INK)
			slot.add_child(caption)
