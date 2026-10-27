extends Control
## 捕获操作窗：显示真实快照；扣费与奖励由场景事务处理。
signal requested
signal cancelled
signal finished(passed: bool)
signal retry_requested
const T = preload("res://scripts/ui/components/sprout_theme.gd")
const Visuals = preload("res://scripts/ui/components/capture_visuals.gd")
const Run = preload("res://scripts/maze/capture_run.gd")
const Recipes = preload("res://scripts/cooking/recipe_catalog.gd")
const Progression = preload("res://scripts/characters/character_progression.gd")
const TARGET_LINE := 0.90
const HOLD_SECONDS := 3.0
const TIMEOUT := 10.0
var panel: Panel
var inner: Panel
var no_button: Button
var yes_button: Button
var close_button: Button
var cost_row: HBoxContainer
var remaining: Label
var remaining_icon: TextureRect
var status: Label
var name_label: Label
var probability: Label
var base_value: Label
var bonus_value: Label
var skills: RichTextLabel
var foods: Control
var sprite: TextureRect
var frames: Array[Texture2D] = []
var rope: Control
var track: Control
var gauge: Control
var mode := "closed"
var age := 0.0
var phase_time := 0.0
var hold_time := 0.0
var hold_qualified := false
var pressure := 0.0
var pulse := 0.0
var target_chance := 0
var can_pay := false
var result_passed := false
var guaranteed := false
var tutorial_paused := false
var tutorial_only_yes := false:
	set(value):
		tutorial_only_yes = value
		if is_instance_valid(no_button):
			no_button.disabled = value
			close_button.disabled = value
			if value and (no_button.has_focus() or close_button.has_focus()): yes_button.grab_focus()
var j_down := false
var intro_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = T.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = _box(self,Rect2(0,0,880,640),T.PANEL)
	_label(panel,"捕获魔物",Rect2(26,16,600,42),32)
	close_button = preload("res://scripts/ui/components/modal_style.gd").close_button()
	panel.add_child(close_button)
	close_button.position = Vector2(814,18)
	close_button.pressed.connect(_cancel)
	inner = _box(panel,Rect2(24,72,832,444),T.CREAM)
	var backdrop := _icon(inner,preload("res://assets/ui/capture/meadow.png"),Rect2(308,12,512,420))
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.clip_contents = true
	var divider := ColorRect.new()
	divider.color = Color("#a98049")
	divider.position = Vector2(296,12)
	divider.size = Vector2(2,420)
	inner.add_child(divider)
	sprite = _icon(inner,null,Rect2(470,176,180,166))
	var clip := Control.new()
	clip.position = Vector2(308,12)
	clip.size = Vector2(512,420)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(clip)
	rope = Visuals.Rope.new()
	clip.add_child(rope)
	var nameplate := _box(inner,Rect2(484,24,160,46),T.CREAM)
	var style := T.thin_panel_style()
	style.set_corner_radius_all(23)
	nameplate.add_theme_stylebox_override("panel",style)
	name_label = _label(inner,"",Rect2(484,24,160,46),24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gauge = Visuals.Fan.new()
	gauge.position = Vector2(690,92)
	inner.add_child(gauge)
	gauge.set_meta("lesson_rect", Rect2(-10,12,122,275))
	_label(inner,"捕获概率",Rect2(30,22,240,30),22)
	probability = _label(inner,"",Rect2(28,54,240,66),48,Color("#648744"))
	base_value = _label(inner,"",Rect2(30,126,260,25),17,T.INK_MUTED)
	bonus_value = _label(inner,"",Rect2(30,152,260,25),17,T.INK_MUTED)
	_label(inner,"捕获概率技能加成  无",Rect2(30,178,260,25),17,T.INK_MUTED)
	skills = RichTextLabel.new()
	skills.position = Vector2(30,212)
	skills.size = Vector2(258,78)
	skills.bbcode_enabled = true
	skills.scroll_active = false
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skills.add_theme_color_override("default_color",T.INK_MUTED)
	inner.add_child(skills)
	skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(inner,"可能获得",Rect2(30,299,220,30),21)
	foods = Control.new()
	inner.add_child(foods)
	foods.set_meta("lesson_rect", Rect2(24,332,270,100))
	foods.pivot_offset = Vector2(24,332)
	no_button = _button("否",Vector2(236,538))
	yes_button = _button("",Vector2(450,538))
	no_button.pressed.connect(_cancel)
	yes_button.pressed.connect(_confirm)
	cost_row = HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	yes_button.add_child(cost_row)
	var prefix := _label(cost_row,"是（消耗",Rect2(),18)
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var food_icon := _icon(cost_row,preload("res://assets/ui/character_details/satiety.png"),Rect2(0,0,18,18))
	food_icon.custom_minimum_size = Vector2(18,18)
	food_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(cost_row,"1）",Rect2(),18).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	remaining = _label(panel,"",Rect2(450,595,190,26),14,T.INK_MUTED)
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remaining_icon = _icon(panel,preload("res://assets/ui/character_details/satiety.png"),Rect2(568,592,18,18))
	status = _label(panel,"捕获中",Rect2(0,526,880,32),16)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track = Visuals.Track.new()
	track.position = Vector2(125,578)
	panel.add_child(track)
	resized.connect(_layout)
	_layout()
	hide()

func _box(parent: Node, rect: Rect2, fill: Color) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel",T.thin_panel_style(fill))
	parent.add_child(node)
	return node

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color := T.INK) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func _icon(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture = texture
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

func _button(text: String, at: Vector2) -> Button:
	var button := SproutButton.new()
	button.set_icon_visible(false)
	button.set_focus_visual(false)
	panel.add_child(button)
	button.text = text
	button.position = at
	button.size = Vector2(190,52)
	return button

func _layout() -> void:
	if not is_instance_valid(panel): return
	var factor := minf(1.0,minf((size.x-32)/880.0,(size.y-32)/640.0))
	panel.scale = Vector2.ONE * factor
	panel.position = (size-Vector2(880,640)*factor)*0.5

func present(row: Dictionary, run: Dictionary, enough: bool, count: int) -> void:
	guaranteed = bool(run.monsters[row.id].guaranteed)
	mode = "ready"
	age = 0
	intro_time = 0
	phase_time = 0
	pressure = 0
	hold_time = 0
	hold_qualified = false
	pulse = 0
	can_pay = enough
	j_down = false
	name_label.text = row.name
	target_chance = mini(95,int(row.chance)+_element_bonus(run,row))
	base_value.text = "基础捕获值  %d%%" % int(row.chance)
	bonus_value.text = "属性加成    +%d%%" % maxi(0,mini(95,int(row.chance)+_element_bonus(run,row))-int(row.chance))
	skills.text = _skill_text(run,row)
	skills.add_theme_font_size_override("normal_font_size",14 if skills.text.count("\n")>=3 else 16)
	frames.clear()
	var texture: Texture2D = load(row.sheet)
	var image := texture.get_image()
	var cell := Vector2i(image.get_width()/4,image.get_height()/4)
	for i in 4:
		var region := Rect2i(Vector2i(i*cell.x,int(row.get("direction",0))*cell.y),cell)
		var bounds := image.get_region(region).get_used_rect()
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(region.position+bounds.position,bounds.size)
		frames.append(frame)
	# 以裁去透明边的动画帧适配实际显示尺寸，全部魔物共用局部绳网。
	var fitted_size := Vector2.ZERO
	for frame_texture in frames:
		var raw_size: Vector2 = frame_texture.get_size()
		var fit := minf(sprite.size.x / raw_size.x, sprite.size.y / raw_size.y)
		var drawn := raw_size * fit
		fitted_size = Vector2(maxf(fitted_size.x, drawn.x), maxf(fitted_size.y, drawn.y))
	rope.configure_target(Rect2(sprite.position - Vector2(308,12) + (sprite.size - fitted_size)*0.5, fitted_size))
	rope.animate("ready", 0, 0, false)
	for child in foods.get_children():
		foods.remove_child(child)
		child.queue_free()
	var display := preload("res://scripts/ui/components/loot_modal.gd").new()
	for i in row.drops.size():
		var id: String = row.drops[i]
		_icon(foods,display.display_texture(Recipes.item_texture(id)),Rect2(30,342+i*49,38,38))
		_label(foods,str(Recipes.get_ingredient(id).get("name",id)),Rect2(80,344+i*49,210,32),20)
	display.free()
	remaining.text = "当前剩余      %d" % count
	no_button.show()
	yes_button.show()
	yes_button.disabled = false
	yes_button.text = ""
	yes_button.modulate = Color.WHITE if enough else Color(0.55,0.55,0.55)
	cost_row.show()
	remaining.show()
	remaining_icon.show()
	close_button.show()
	status.hide()
	track.hide()
	gauge.hide()
	rope.spread = 0
	rope.queue_redraw()
	show()
	if tutorial_only_yes: yes_button.grab_focus()
	else: no_button.grab_focus()

func _element_bonus(run: Dictionary, row: Dictionary) -> int:
	var bonus := 0
	for member in run.members:
		if Run.Catalog.COUNTERS.get(member.element,"") == row.element:
			bonus += 14 if member.level>=20 else (12 if member.level>=10 else 10)
	return mini(30,bonus)

func _skill_text(run: Dictionary, row: Dictionary) -> String:
	for member in run.members:
		if member.id != "yaya": continue
		var rank := int(member.rank)
		var countered: bool = Run.Catalog.COUNTERS.get(member.element,"") == row.element
		var rate := 25 if rank>=4 else (20 if rank>=2 else 15)
		if rank>=3 and countered: rate += 10
		var text := "芽芽 · 双份惊喜\n成功后 %d%% 概率获得双份食材" % rate
		if rank>=6 and countered and run.yaya_counter<3: text = "芽芽 · 丰收拿手菜\n本次成功捕获必得双份食材"
		if rank>=5: text += "\n双份触发后 20% 概率再多一份"
		var title_end := text.find("\n")
		return "[color=#648744]" + text.substr(0,title_end) + "[/color]" + text.substr(title_end)
	return "特殊奖励技能  无"

func start(elapsed: float = 0.0) -> void:
	mode = "throw"
	phase_time = 0
	hold_time = 0
	hold_qualified = false
	pressure = 0.55
	j_down = Input.is_physical_key_pressed(KEY_J) or Input.is_key_pressed(KEY_J)
	no_button.hide()
	yes_button.hide()
	remaining.hide()
	remaining_icon.hide()
	close_button.hide()
	status.text = "捕获中"
	status.show()
	track.show()
	if elapsed>=2.6:
		mode = "suppress"
		phase_time = minf(TIMEOUT,elapsed-2.6)
		rope.spread = 1
		gauge.show()
	elif elapsed>=1.1:
		mode = "restrain"
		phase_time = elapsed-1.1
		rope.spread = 1
	else:
		phase_time = elapsed
	get_viewport().gui_release_focus()

func settlement_error() -> void:
	mode = "retry"
	status.text = "保存失败，请重试"
	yes_button.show()
	yes_button.disabled = false
	yes_button.modulate = Color.WHITE
	yes_button.text = "重试保存"
	cost_row.hide()
	yes_button.grab_focus()

func close() -> void:
	mode = "closed"
	hide()

func _cancel() -> void:
	if tutorial_only_yes: return
	if mode == "ready": cancelled.emit()

func _confirm() -> void:
	if mode == "ready": requested.emit()
	elif mode == "retry": retry_requested.emit()

func _process(delta: float) -> void:
	if not visible: return
	if tutorial_paused: return
	age += delta
	intro_time += delta
	if not frames.is_empty(): sprite.texture = frames[int(age/0.18)%frames.size()]
	probability.text = "%d%%" % roundi(target_chance*(1-pow(1-minf(intro_time/1.2,1),3)))
	pulse = maxf(0,pulse-delta*5)
	if mode in ["throw","restrain","suppress","complete"]:
		phase_time += delta
		if mode == "throw":
			rope.spread = minf(1,phase_time/1.1)
			track.progress = minf(1.0/3,phase_time/1.1/3)
			if phase_time>=1.1:
				mode = "restrain"
				phase_time = 0
		elif mode == "restrain":
			track.progress = 1.0/3+minf(1,phase_time/1.5)/3
			if phase_time>=1.5:
				mode = "suppress"
				phase_time = 0
				gauge.show()
		elif mode == "suppress":
			pressure = maxf(0,pressure-delta*0.24)
			if pressure >= TARGET_LINE: hold_time += delta
			else: hold_time = 0
			# 达标只记录资格；绳索进度独立走满时限，松开不倒退或提前结算。
			hold_qualified = hold_qualified or hold_time>=HOLD_SECONDS
			status.text = "镇压已达标，等待结算" if hold_qualified else "连续按 J，保持刻度线以上 %.1f / 3 秒" % hold_time
			track.progress = 2.0/3+minf(1,phase_time/TIMEOUT)/3
			if phase_time>=TIMEOUT:
				result_passed = guaranteed or hold_qualified
				mode = "complete"
				phase_time = 0
				track.progress = 1
		elif phase_time>=0.55:
			mode = "settling"
			finished.emit(result_passed)
		rope.time = age
		rope.strength = (0.5+pulse*1.6) if mode=="suppress" else 0.22
		rope.animate(mode, phase_time, pulse, result_passed)
		track.phase = age
		track.queue_redraw()
		gauge.amount = pressure
		gauge.pulse = pulse
		gauge.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey: return
	if tutorial_paused: return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_J or event.physical_keycode == KEY_J:
		if not event.pressed: j_down = false
		elif not event.echo and not j_down:
			j_down = true
			if mode == "suppress":
				pressure = minf(1,pressure+0.08)
				if pressure < TARGET_LINE: hold_time = 0
				pulse = 1
		return
	if not event.pressed or event.echo: return
	if mode not in ["ready","retry"]: return
	match event.keycode:
		KEY_ESCAPE: _cancel()
		KEY_TAB,KEY_LEFT,KEY_RIGHT:
			if mode=="ready" and not no_button.disabled and yes_button.has_focus(): no_button.grab_focus()
			else: yes_button.grab_focus()
		KEY_ENTER,KEY_KP_ENTER,KEY_SPACE:
			if mode=="ready" and no_button.has_focus(): _cancel()
			else: _confirm()



