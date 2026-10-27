extends SproutModal
## 复用通用窗体，左右翻转只作用于内容面板，遮罩持续阻挡输入。
signal choice(capture: bool)
signal dismissed
var flipping := false
var tutorial_only_yes := false:
	set(value):
		tutorial_only_yes = value
		if is_instance_valid(_cancel_button):
			_cancel_button.disabled = value
			if value and _cancel_button.has_focus(): _confirm_button.grab_focus()
var can_capture := false
var victory := false
var toast: Callable
var _flip: Tween
var entry_only := false

var illustration: TextureRect
var illustration_frames: Array[Texture2D] = []
var illustration_key := ""
var animation_time := 0.0
var power_row: HBoxContainer
var hero_power: Label
var monster_power: Label
var guidance: Label
var satiety_icon: TextureRect
var cost_row: HBoxContainer
const ESCAPE_ART := preload("res://assets/ui/battle_results/capture_escape.png")
var remaining_row: HBoxContainer
var remaining_value: Label

func _build() -> void:
	_overlay = ColorRect.new()
	_overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_panel = PanelContainer.new()
	_panel.theme = SproutTheme.make_theme()
	_panel.add_theme_stylebox_override("panel",SproutTheme.thin_panel_style())
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",16)
	_panel.add_child(column)
	_title_label = _label("",24,SproutTheme.INK)
	column.add_child(_title_label)
	illustration = TextureRect.new()
	illustration.custom_minimum_size = Vector2(260,170)
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(illustration)
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation",8)
	column.add_child(group)
	_body_label = _label("",18,SproutTheme.INK)
	group.add_child(_body_label)
	power_row = HBoxContainer.new()
	power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	power_row.add_theme_constant_override("separation",22)
	group.add_child(power_row)
	hero_power = _label("",18,SproutTheme.INK)
	monster_power = _label("",18,Color("#b84b40"))
	power_row.add_child(hero_power)
	power_row.add_child(monster_power)
	guidance = _label("战力提升方式\n击败魔物、升级或更换角色",16,SproutTheme.INK_MUTED)
	column.add_child(guidance)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation",14)
	column.add_child(actions)
	var confirm_column := VBoxContainer.new()
	confirm_column.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_column.add_theme_constant_override("separation", 6)
	remaining_row = HBoxContainer.new()
	remaining_row.alignment = BoxContainer.ALIGNMENT_CENTER
	remaining_row.add_theme_constant_override("separation", 4)
	remaining_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var remaining_text := _label("当前剩余", 14, SproutTheme.INK_MUTED)
	remaining_row.add_child(remaining_text)
	var remaining_icon := TextureRect.new()
	remaining_icon.texture = preload("res://assets/ui/character_details/satiety.png")
	remaining_icon.custom_minimum_size = Vector2(18, 18)
	remaining_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	remaining_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	remaining_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remaining_row.add_child(remaining_icon)
	remaining_value = _label("0", 14, SproutTheme.INK_MUTED)
	remaining_row.add_child(remaining_value)
	_cancel_button = SproutButton.new()
	_confirm_button = SproutButton.new()
	for button in [_cancel_button]:
		button.set_icon_visible(false)
		button.set_focus_visual(false)
		button.custom_minimum_size = Vector2(190,52)
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		actions.add_child(button)
	actions.add_child(confirm_column)
	_confirm_button.set_icon_visible(false)
	_confirm_button.set_focus_visual(false)
	_confirm_button.custom_minimum_size = Vector2(190,52)
	_confirm_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	confirm_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_confirm_button.text = ""
	confirm_column.add_child(_confirm_button)
	confirm_column.add_child(remaining_row)
	satiety_icon = TextureRect.new()
	satiety_icon.texture = preload("res://assets/ui/character_details/satiety.png")
	satiety_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	satiety_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	satiety_icon.custom_minimum_size = Vector2(18, 18)
	satiety_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	satiety_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	satiety_icon.visible = false
	cost_row = HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_theme_constant_override("separation", 3)
	var cost_prefix := _label("是（消耗", 18, SproutTheme.INK)
	cost_prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_prefix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(cost_prefix)
	cost_row.add_child(satiety_icon)
	var cost_value := _label("1）", 18, SproutTheme.INK)
	cost_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(cost_value)
	_confirm_button.add_child(cost_row)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	return label

func _set_art(kind: String, won: bool) -> void:
	if kind in ["silverfish","thunder_eel","wind_frog","mimic_crab","blind_scorpion","rockmane"]:
		illustration_key=kind+("_win" if won else "_lose")
		illustration_frames.clear()
		var texture: Texture2D=load("res://assets/monsters/"+kind+("/defeated.png" if won else "/attack.png"))
		var cell := Vector2(texture.get_width()/4.0,texture.get_height()/4.0)
		for i in 4:
			var frame := AtlasTexture.new()
			frame.atlas=texture
			frame.region=Rect2(Vector2(3 if won else i,0)*cell,cell)
			illustration_frames.append(frame)
		animation_time=0
		illustration.texture=illustration_frames[0]
		illustration.show()
		return
	illustration_key = kind+ ("_win" if won else "_lose")
	var file := illustration_key+ ("_v2" if illustration_key=="snail_lose" else "")
	var source := load("res://assets/ui/battle_results/"+file+".png") as Texture2D
	illustration_frames.clear()
	# 以透明间隙划分实际帧；统一画布宽度和垂直基线，避免生成图非等距造成截断。
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/battle_results/regions.json"))
	var boxes: Array = regions[file]
	var canvas_width := 0
	for box in boxes: canvas_width = maxi(canvas_width,int(box[2]))
	for box in boxes:
		var frame := AtlasTexture.new()
		frame.atlas = source
		frame.region = Rect2(float(box[0]),float(box[1]),float(box[2]),float(box[3]))
		var padding := canvas_width-int(box[2])
		frame.margin = Rect2(padding/2.0,0,padding,0)
		illustration_frames.append(frame)
	animation_time = 0
	illustration.texture = illustration_frames[0]
	illustration.show()

func _process(delta: float) -> void:
	if not visible or not illustration.visible or illustration_frames.is_empty(): return
	animation_time += delta
	illustration.texture = illustration_frames[int(animation_time/0.3)%4]

func present(won: bool, kind: String, enough_food: bool, current_power: int = 0, target_power: int = 0, remaining_food: int = 0) -> void:
	victory = won
	can_capture = enough_food
	_title_label.text = "战斗胜利" if won else "战力不足"
	_body_label.text = "击败它了！\n是否将它捕获变为食材？" if won else "当前战力不足，请先提升战力再来"
	power_row.visible = not won
	guidance.visible = not won
	hero_power.text = "当前战力 %d" % current_power
	monster_power.text = "魔物战力 %d" % target_power
	_cancel_button.text = "否"
	_cancel_button.visible = won
	satiety_icon.visible = won
	_confirm_button.text = "知道了" if not won else ""
	cost_row.visible = won
	remaining_value.text = "%d" % remaining_food
	remaining_row.visible = won
	if won and entry_only:
		can_capture = true
		cost_row.hide()
		satiety_icon.hide()
		remaining_row.hide()
		_confirm_button.text = "是"
	_layout_satiety_icon()
	_confirm_button.modulate = Color(0.55,0.55,0.55,1) if won and not enough_food else Color.WHITE
	if won and entry_only: _confirm_button.modulate = Color.WHITE
	_set_art(kind,won)
	_layout(460,390 if won else 430)
	show()
	if won and not tutorial_only_yes: _cancel_button.grab_focus()
	else: _confirm_button.grab_focus()
	await flip_in()

func present_capture_failure(kind: String = "slime") -> void:
	victory = false
	can_capture = false
	_title_label.text = "魔物溜走了"
	_body_label.text = "没捕获成功"
	illustration_frames.clear()
	var escape_width := 2172.0 / 4.0
	for index in 4:
		var frame := AtlasTexture.new()
		frame.atlas = ESCAPE_ART
		frame.region = Rect2(index * escape_width, 0, escape_width, 724)
		illustration_frames.append(frame)
	illustration.texture = illustration_frames[0]
	animation_time = 0.0
	illustration.show()
	power_row.hide()
	guidance.hide()
	_cancel_button.hide()
	_confirm_button.text = "知道了"
	cost_row.visible = false
	satiety_icon.visible = false
	remaining_row.visible = false
	_confirm_button.modulate = Color.WHITE
	_layout(460,360)
	show()
	_confirm_button.grab_focus()
	await flip_in()

func _layout(width: float, height: float) -> void:
	_panel.custom_minimum_size = Vector2(width,height)
	_panel.size = Vector2(width,height)
	_panel.offset_left = -width/2
	_panel.offset_right = width/2
	_panel.offset_top = -height/2
	_panel.offset_bottom = height/2

func _layout_satiety_icon() -> void:
	return

func flip_in() -> void:
	flipping = true
	_panel.pivot_offset = _panel.size/2
	_panel.scale.x = 0.01
	_flip = create_tween()
	_flip.tween_property(_panel,"scale:x",1.0,0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _flip.finished
	flipping = false

func flip_out() -> void:
	flipping = true
	_panel.pivot_offset = _panel.size/2
	_flip = create_tween()
	_flip.tween_property(_panel,"scale:x",0.01,0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _flip.finished
	hide()
	_panel.scale.x = 1
	flipping = false

func _on_confirm_pressed() -> void:
	if flipping: return
	if not victory: dismissed.emit()
	elif not can_capture:
		if toast.is_valid(): toast.call("饱腹度不足，无法捕获")
	else: choice.emit(true)

func _on_cancel_pressed() -> void:
	if tutorial_only_yes: return
	if flipping: return
	if victory: choice.emit(false)
	else: dismissed.emit()

func _on_close_pressed() -> void:
	if tutorial_only_yes: return
	_on_cancel_pressed()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey: return
	get_viewport().set_input_as_handled()
	if flipping or not event.pressed or event.echo: return
	match event.keycode:
		KEY_ESCAPE: _on_cancel_pressed()
		KEY_TAB,KEY_LEFT,KEY_RIGHT:
			if victory and not _cancel_button.disabled and _confirm_button.has_focus(): _cancel_button.grab_focus()
			else: _confirm_button.grab_focus()
		KEY_ENTER,KEY_KP_ENTER,KEY_SPACE:
			if _cancel_button.has_focus() and victory: _on_cancel_pressed()
			else: _on_confirm_pressed()

func _unhandled_input(_event: InputEvent) -> void:
	pass


func present_exploration_failure(kind: String) -> void:
	present(false,kind,false)
	_title_label.text="探索失败"
	_body_label.text="生命值已耗尽，本次探索结束。"
	guidance.text="本趟捕获的食材将全部丢失，已消耗的饱腹度不会返还。"
	guidance.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	guidance.custom_minimum_size.x=420
	power_row.hide()
	_confirm_button.text="返回餐厅"
	_layout(480,430)
