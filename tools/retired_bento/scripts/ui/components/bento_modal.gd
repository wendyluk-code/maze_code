extends ColorRect
signal closed
signal feedback(message: String)
const Store = preload("res://scripts/restaurant/bento_store.gd")
const Catalog = preload("res://scripts/cooking/recipe_catalog.gd")
const Display = preload("res://scripts/ui/components/bag_icon_display.gd")
const Style = preload("res://scripts/ui/components/modal_style.gd")
const FreezerView = preload("res://scripts/ui/components/freezer_modal.gd")
const ActionIcon = preload("res://scripts/ui/components/freezer_action_icon.gd")
var draft: Dictionary = {}
var summary: Label
var pending_action := ""
var pending_slot := ""
var _timers: Array=[]
var _tick := 0.0
var _signature := ""
var panel: Panel
var tiles: Dictionary={}
var details: VBoxContainer
var right_scroll: ScrollContainer
var confirmation: Control
var all_button: Button
var assemble_button: Button
var selected := "attack"
var in_maze := false
var status: Label

static var _entry_texture: ImageTexture

static func entry_texture() -> Texture2D:
	if _entry_texture == null:
		var image := Display.texture(preload("res://assets/ui/bento/lunchbox-approved.png")).get_image()
		image.generate_mipmaps()
		_entry_texture = ImageTexture.create_from_image(image)
	return _entry_texture

static func make_entry(parent: Control) -> Button:
	var b := Button.new()
	parent.add_child(b)
	b.name="BentoEntry"
	b.tooltip_text="便当盒"
	b.icon=entry_texture()
	b.expand_icon=true
	b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 背包源图保留透明边；按其实际可见高度匹配，不能只复用56像素画布宽度。
	var backpack := preload("res://scripts/ui/components/backpack_reward.gd").entry_texture()
	var backpack_visible := Display.texture(backpack)
	var visible_height := 56.0 * backpack_visible.get_height() / backpack.get_width()
	b.add_theme_constant_override("icon_max_width", roundi(visible_height * b.icon.get_width() / b.icon.get_height()))
	for state in ["normal","hover","pressed","focus","disabled"]: b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	b.custom_minimum_size=Vector2(64,64)
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left=88
	b.offset_right=152
	b.offset_top=-80
	b.offset_bottom=-16
	preload("res://scripts/ui/components/entry_icon_shadow.gd").attach(b,"BentoShadow")
	b.hide()
	return b

func _style(fill: Color, border: Color = Color("b38b54")) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=fill
	s.border_color=border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(12)
	return s

func _label(text: String, font_size: int = 20) -> Label:
	var l := Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",SproutTheme.INK)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func _badge(eaten: bool) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style := _style(Color("c5d7a4") if eaten else Color("efdb9b"))
	style.set_border_width_all(0)
	style.set_content_margin_all(3)
	badge.add_theme_stylebox_override("panel",style)
	var label := _label("已食用" if eaten else "未食用",17)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)
	badge.custom_minimum_size=Vector2(80,28)
	return badge

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color=Style.BACKDROP
	theme=SproutTheme.make_theme()
	panel=Panel.new()
	panel.add_theme_stylebox_override("panel",_style(Color("f0d5a0")))
	add_child(panel)
	panel.size=Vector2(1064,554)
	var title := _label("便当盒",28)
	title.position=Vector2(0,12)
	title.size=Vector2(1064,40)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	status=_label("",19)
	status.position=Vector2(24,56)
	panel.add_child(status)
	summary=_label("",19)
	summary.position=Vector2(390,56)
	summary.size=Vector2(370,28)
	summary.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(summary)
	var tray := Panel.new()
	tray.position=Vector2(20,98)
	tray.size=Vector2(654,362)
	tray.add_theme_stylebox_override("panel",_style(Color("b6935e")))
	panel.add_child(tray)
	for i in Store.SLOTS.size():
		var key: String=Store.SLOTS[i]
		var tile := Button.new()
		tile.position=Vector2(12+i*212,12) if i<3 else Vector2(12+(i-3)*318,184)
		tile.size=Vector2(204 if i<3 else 310,166)
		tile.clip_contents=true
		tray.add_child(tile)
		tile.pressed.connect(func(): selected=key; right_scroll.scroll_vertical=0; refresh())
		tiles[key]=tile
	right_scroll=ScrollContainer.new()
	right_scroll.position=Vector2(692,98)
	right_scroll.size=Vector2(352,362)
	right_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	right_scroll.add_theme_stylebox_override("panel",_style(Color("fff4dc")))
	panel.add_child(right_scroll)
	details=VBoxContainer.new()
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation",10)
	right_scroll.add_child(details)
	var close := SproutButton.new().configure("关闭").set_icon_visible(false)
	panel.add_child(close)
	close.custom_minimum_size=Vector2(118,36)
	close.position=Vector2(758,506)
	close.size=Vector2(118,36)
	close.pressed.connect(dismiss)
	all_button=SproutButton.new().configure("全部食用").set_icon_visible(false)
	panel.add_child(all_button)
	all_button.custom_minimum_size=Vector2(154,36)
	all_button.position=Vector2(890,506)
	all_button.size=Vector2(154,36)
	all_button.pressed.connect(func(): _eat("all"))
	assemble_button=SproutButton.new().configure("完成装配").set_icon_visible(false)
	panel.add_child(assemble_button)
	assemble_button.custom_minimum_size=Vector2(154,36)
	assemble_button.position=Vector2(890,506)
	assemble_button.size=Vector2(154,36)
	assemble_button.pressed.connect(_save_draft)
	confirmation=preload("res://scripts/ui/components/destination_confirmation.gd").new()
	add_child(confirmation)
	confirmation.cancelled.connect(func(): confirmation.hide())
	confirmation.confirmed.connect(_confirm_action)
	hide()

func _process(delta: float) -> void:
	if not visible: return
	var factor := minf(1.0,minf((size.x-40)/1064.0,(size.y-40)/554.0))
	panel.scale=Vector2.ONE*factor
	panel.position=(size-panel.size*factor)/2
	_tick+=delta
	if _tick>=1.0:
		_tick=0.0
		if _signature!=_state_signature(): refresh()
		for timer in _timers:
			if is_instance_valid(timer.label): timer.label.text=FreezerView._remaining(timer.deadline)

func present(maze_context: bool) -> void:
	in_maze=maze_context
	draft.clear()
	confirmation.hide()
	right_scroll.scroll_vertical=0
	refresh()
	show()
	_process(0)

func refresh() -> void:
	var scroll_y := right_scroll.scroll_vertical
	right_scroll.set_deferred("scroll_vertical",scroll_y)
	_timers.clear()
	var b := Store.snapshot(SaveManager)
	status.text="迷宫 · 非战斗中" if in_maze else "餐厅 · 装配"
	all_button.visible=in_maze
	assemble_button.visible=not in_maze
	var slots: Dictionary=b.get("slots",{})
	var uneaten: int=slots.values().filter(func(r): return not r.eaten).size()
	summary.text=("已食用 %d份 · 未食用 %d份" % [slots.size()-uneaten,uneaten]) if in_maze else ("已保存 %d · 本次暂选 %d" % [slots.size(),draft.size()])
	all_button.disabled=b.is_empty() or uneaten==0
	assemble_button.disabled=b.is_empty() or draft.is_empty()
	_signature=_state_signature()
	for key in tiles:
		var tile: Button=tiles[key]
		for child in tile.get_children(): tile.remove_child(child); child.queue_free()
		for state in ["normal","hover","pressed","focus"]: tile.add_theme_stylebox_override(state,_style(Color("fff4dc") if selected==key else Color("e8d4a9"),Color("91a65b") if selected==key else Color("d3b57c")))
		var heading := _label(Store.NAMES[key],19)
		tile.add_child(heading)
		heading.position=Vector2(10,6)
		var row: Dictionary=slots.get(key,{})
		var is_draft := row.is_empty() and draft.has(key)
		if is_draft: row={"id":draft[key].recipe_id,"stars":draft[key].quality,"eaten":false}
		if row.is_empty():
			var empty := _label("空格" if in_maze else "+\n选择料理",21)
			empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			empty.position=Vector2(0,55)
			empty.size=Vector2(tile.size.x,80)
			tile.add_child(empty)
			continue
		if in_maze:
			var state := _badge(row.eaten)
			state.position=Vector2(tile.size.x-85,7)
			state.size=Vector2(80,25)
			tile.add_child(state)
		elif is_draft:
			var cancel := Style.close_button()
			cancel.name="CancelDraft"
			cancel.tooltip_text="取消本次选择"
			cancel.position=Vector2(tile.size.x-46,0)
			tile.add_child(cancel)
			cancel.pressed.connect(func(): draft.erase(key); refresh())
		elif not row.eaten:
			var trash := ActionIcon.new()
			trash.trash=true
			trash.name="DiscardSaved"
			trash.position=Vector2(tile.size.x-40,6)
			tile.add_child(trash)
			trash.pressed.connect(func(): _ask_discard(key))
		if row.eaten:
			var plate := Control.new()
			plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
			tile.add_child(plate)
			plate.position=Vector2(tile.size.x/2,68)
			plate.draw.connect(func():
				plate.draw_set_transform(Vector2.ZERO,0,Vector2(1,0.55))
				plate.draw_circle(Vector2.ZERO,39,Color("b49a63"))
				plate.draw_circle(Vector2.ZERO,36,Color("fff3ce"))
				plate.draw_circle(Vector2.ZERO,28,Color("dbc795")))
		else:
			var icon := TextureRect.new()
			icon.texture=Display.texture(Catalog.item_texture(row.id))
			icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position=Vector2((tile.size.x-64)/2,38)
			icon.size=Vector2(64,60)
			icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
			tile.add_child(icon)
		for info in [[Catalog.get_recipe(row.id).name,100,19],[Store.description(key,row.stars,row.id),129,15]]:
			var label := _label(info[0],info[2])
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.position=Vector2(4,info[1])
			label.size=Vector2(tile.size.x-8,28)
			tile.add_child(label)
	for child in details.get_children(): details.remove_child(child); child.queue_free()
	var row: Dictionary=slots.get(selected,{})
	if not in_maze and row.is_empty():
		_candidates()
		return
	details.add_child(_label(Store.NAMES[selected]+"料理",24))
	if row.is_empty():
		details.add_child(_label("此格尚未放入料理",19))
		return
	var dish_row := HBoxContainer.new()
	dish_row.add_theme_constant_override("separation",10)
	details.add_child(dish_row)
	var food_icon := TextureRect.new()
	food_icon.texture=Display.texture(Catalog.item_texture(row.id))
	food_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	food_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_icon.custom_minimum_size=Vector2(80,80)
	food_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dish_row.add_child(food_icon)
	var dish_text := VBoxContainer.new()
	dish_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	dish_row.add_child(dish_text)
	var name_label := _label(Catalog.get_recipe(row.id).name,21)
	dish_text.add_child(name_label)
	var stars_host := Control.new()
	stars_host.custom_minimum_size=Vector2(120,42)
	dish_text.add_child(stars_host)
	var stars := preload("res://scripts/ui/cooking_rating_stars.gd").new()
	stars.uniform=true
	stars_host.add_child(stars)
	stars.scale=Vector2.ONE*0.42
	stars.quality=int(row.stars)
	stars.elapsed=2.0
	stars.stop()
	stars.queue_redraw()
	var effect := _label(Store.description(selected,row.stars,row.id),22)
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size=Vector2(286,56)
	details.add_child(effect)
	var state := _badge(row.eaten)
	state.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	details.add_child(state)
	if not row.eaten:
		if in_maze:
			var eat := SproutButton.new().configure("食用").set_icon_visible(false)
			eat.name="EatButton"
			eat.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
			details.add_child(eat)
			eat.custom_minimum_size=Vector2(150,36)
			eat.pressed.connect(func(): _eat(selected))
		var discard := SproutButton.new().configure("丢弃").set_icon_visible(false)
		discard.name="DiscardButton"
		discard.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		details.add_child(discard)
		discard.custom_minimum_size=Vector2(150,36)
		discard.pressed.connect(func(): _ask_discard(selected))
		discard.visible=in_maze

func _eat(slot: String) -> void:
	var result := Store.eat(SaveManager,slot)
	if not result.success: feedback.emit("已满，料理已保留" if result.get("reason")=="already_full" else "食用失败，请在迷宫非战斗时使用并检查存档")
	refresh()

func _discard() -> void:
	var result := Store.discard(SaveManager,pending_slot)
	confirmation.hide()
	if not result.success: feedback.emit("丢弃未保存，料理已保留")
	refresh()

func dismiss() -> void:
	if confirmation.visible: confirmation.hide(); return
	if not draft.is_empty():
		pending_action="close"
		confirmation.open_confirmation("放弃本次未保存的选择？","放弃选择","继续装配")
		return
	_finish_close()

func _input(event: InputEvent) -> void:
	if not visible or confirmation.visible: return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and event.keycode==KEY_ESCAPE: dismiss()

func _finish_close() -> void:
	draft.clear()
	hide()
	closed.emit()

func _ask_discard(slot: String) -> void:
	pending_action="discard"
	pending_slot=slot
	confirmation.open_confirmation("确定丢弃这份料理？","丢弃","取消")

func _confirm_action() -> void:
	confirmation.hide()
	if pending_action=="close": _finish_close()
	elif pending_action=="discard": _discard()

func _save_draft() -> void:
	var choices := {}
	for slot in draft: choices[slot]=int(draft[slot].id)
	var result := Store.assemble(SaveManager,choices)
	if result.success:
		draft.clear()
		feedback.emit("便当装配完成")
	else:
		var messages := {"expired":"所选料理已腐坏，请取消后重新选择","changed":"所选料理已变化，请重新选择","occupied":"格子已变化，请重新选择","save_failed":"保存失败，料理未移动，请重试","not_in_restaurant":"只能在餐厅出发前装配"}
		feedback.emit(messages.get(result.get("reason",""),"装配未保存，请检查料理记录"))
	refresh()

func _state_signature() -> String:
	var ledger := SaveManager.freezer_snapshot()
	var now := int(Time.get_unix_time_from_system())
	var timers: Array=[]
	for unit in ledger.get("stored",[]): timers.append(int(unit.expires_at)<=now)
	return JSON.stringify([Store.snapshot(SaveManager),ledger,timers])

func _candidates() -> void:
	details.add_child(_label("选择%s料理" % Store.NAMES[selected],23))
	var ledger := SaveManager.freezer_snapshot()
	var units: Array=[]
	for unit in ledger.get("stored",[]):
		if Store.recipe_slot(unit.recipe_id)==selected: units.append(unit)
	details.add_child(_label("来自冰柜 · 共%d份料理" % units.size(),17))
	if units.is_empty(): details.add_child(_label("暂无对应探索料理",18))
	for unit in units: _candidate(unit)

func _candidate(unit: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name="Unit_%d" % int(unit.id)
	card.add_theme_stylebox_override("panel",_style(Color("f6e9c9")))
	details.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",3)
	card.add_child(body)
	var title := HBoxContainer.new()
	body.add_child(title)
	title.add_child(_label(Catalog.get_recipe(unit.recipe_id).name,18))
	FreezerView._tags(title,unit.recipe_id)
	var rating := HBoxContainer.new()
	body.add_child(rating)
	var icon := TextureRect.new()
	icon.texture=Display.texture(Catalog.item_texture(unit.recipe_id))
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size=Vector2(46,46)
	rating.add_child(icon)
	var holder := Control.new()
	holder.custom_minimum_size=Vector2(82,34)
	rating.add_child(holder)
	var stars := preload("res://scripts/ui/cooking_rating_stars.gd").new()
	stars.uniform=true
	holder.add_child(stars)
	stars.scale=Vector2.ONE*0.30
	stars.quality=int(unit.quality)
	stars.elapsed=2.0
	stars.stop()
	stars.queue_redraw()
	var remaining := _label(FreezerView._remaining(int(unit.expires_at)),14)
	remaining.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	rating.add_child(remaining)
	_timers.append({"label":remaining,"deadline":int(unit.expires_at)})
	var effect := _label(Store.description(selected,int(unit.quality),unit.recipe_id),16)
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(effect)
	var add := SproutButton.new().configure("装入").set_icon_visible(false)
	add.name="SelectUnit"
	add.custom_minimum_size=Vector2(88,30)
	add.size_flags_horizontal=Control.SIZE_SHRINK_END
	add.disabled=int(unit.expires_at)<=int(Time.get_unix_time_from_system()) or (draft.has(selected) and int(draft[selected].id)==int(unit.id))
	body.add_child(add)
	add.custom_minimum_size=Vector2(88,30)
	add.add_theme_font_size_override("font_size",18)
	add.pressed.connect(func(): draft[selected]=unit.duplicate(true); refresh())
