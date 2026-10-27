extends SproutModal
## 角色详情：图片仅用于无字皮肤，文字和数字统一由游戏字体渲染。
const Progression := preload("res://scripts/characters/character_progression.gd")
const SKIN_ROOT := "res://assets/ui/character_details/"
const Toast := preload("res://scripts/ui/components/feedback_toast.gd")
var character_id := ""
var design: Control
var portrait: TextureRect
var faction_icon: TextureRect
var name_label: Label
var stars: Array[TextureRect] = []
var tabs: Array[Button] = []
var attributes: Control
var skills: Control
var level_label: Label
var experience_label: Label
var experience_bar: ProgressBar
var attribute_values: Array[Label] = []
var breakthrough_button: Button
var error_label: Label
var skill_titles: Array[Label] = []
var skill_bodies: Array[Label] = []
var skill_locks: Array[TextureRect] = []
var skill_badges: Array[Label] = []
var skill_panels: Array[Panel] = []
var selected_tab := 0
var _record: Dictionary = {}
var _busy := false
var _last_gold := -1
var _toast: Label
var active_skill: Control
var active_icon: TextureRect
var active_title: Label
var active_description: Label
var active_interval: Label
var active_damage: Label
var defense_value: Label
var rarity_badge: TextureRect
var active_rules_button: Button
var active_rules_modal: SproutModal

func _build() -> void:
	theme = SproutTheme.make_theme()
	_overlay = ColorRect.new()
	_overlay.color = preload("res://scripts/ui/components/modal_style.gd").BACKDROP
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	design = Control.new()
	design.size = Vector2(1280, 720)
	add_child(design)
	# 无字整幅纸面等比适配，花叶、分栏与边框不参与九宫格拉伸。
	_image(design, "paper_background_v3", Rect2(0, 0, 1280, 720))
	portrait = _image(design, "", Rect2(25, 100, 420, 420))
	rarity_badge = preload("res://scripts/ui/components/rarity_badge.gd").attach(design, "", Rect2(165, 25, 140, 68))
	faction_icon = _image(design, "", Rect2(0, 605, 48, 48))
	for i in 6:
		stars.append(_image(design, "star_dim", Rect2(50 + i * 61, 521, 54, 54)))
	name_label = _label(design, "", Rect2(54, 599, 384, 60), 42)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 2:
		var button := Button.new()
		button.text = "属性" if i == 0 else "技能"
		button.position = Vector2(472 + i * 330, 8)
		button.size = Vector2(320, 80)
		button.add_theme_font_size_override("font_size", 32)
		button.add_theme_constant_override("outline_size", 0)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(select_tab.bind(i))
		design.add_child(button)
		tabs.append(button)
	_close_button = preload("res://scripts/ui/components/modal_style.gd").close_button()
	_close_button.position = Vector2(1288, -12)
	_close_button.size = Vector2(60, 60)
	_close_button.add_theme_font_size_override("font_size", 54)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		_close_button.add_theme_color_override(state, SproutTheme.CREAM)
	_close_button.tooltip_text = "返回角色簿"
	_close_button.pressed.connect(close_modal)
	design.add_child(_close_button)
	attributes = Control.new()
	attributes.position = Vector2(484, 118)
	attributes.size = Vector2(740, 550)
	design.add_child(attributes)
	level_label = _label(attributes, "", Rect2(8, 0, 155, 64), 38)
	breakthrough_button = Button.new()
	breakthrough_button.position = Vector2(460, 0)
	breakthrough_button.size = Vector2(280, 62)
	breakthrough_button.add_theme_font_size_override("font_size", 24)
	breakthrough_button.add_theme_constant_override("outline_size", 0)
	breakthrough_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	breakthrough_button.add_theme_stylebox_override("normal", _style("breakthrough_active", Vector4.ZERO))
	breakthrough_button.add_theme_stylebox_override("hover", _style("breakthrough_active", Vector4.ZERO))
	breakthrough_button.add_theme_stylebox_override("pressed", _style("breakthrough_active", Vector4.ZERO))
	breakthrough_button.add_theme_stylebox_override("disabled", _style("breakthrough_base", Vector4.ZERO))
	breakthrough_button.add_theme_color_override("font_color", SproutTheme.CREAM)
	breakthrough_button.add_theme_color_override("font_hover_color", SproutTheme.CREAM)
	breakthrough_button.add_theme_color_override("font_focus_color", SproutTheme.CREAM)
	breakthrough_button.add_theme_color_override("font_disabled_color", Color("#eee5d7"))
	breakthrough_button.pressed.connect(_breakthrough)
	attributes.add_child(breakthrough_button)
	# 简单圆角用原生抗锯齿样式绘制，避免原切片残留绿色及零宽裁剪失效。
	experience_bar = ProgressBar.new()
	experience_bar.position = Vector2(155, 15)
	experience_bar.size = Vector2(585, 34)
	experience_bar.show_percentage = false
	experience_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := _rounded_skin(Color("#f2dfc2"), Color("#cda575"), 20, 2)
	track.set_content_margin_all(6)
	experience_bar.add_theme_stylebox_override("background", track)
	experience_bar.add_theme_stylebox_override("fill", _rounded_skin(Color("#a6b967"), Color("#7d9147"), 14, 2))
	attributes.add_child(experience_bar)
	experience_label = _label(attributes, "", Rect2(155, 12, 585, 40), 22)
	experience_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 5:
		_image(attributes, ["attack", "defense", "health_syringe", "satiety", "recovery"][i], Rect2(14, 77 + i * 54, 44, 44))
		_label(attributes, ["攻击力", "防御力", "生命上限", "饱腹度 / 上限", "每秒恢复效率"][i], Rect2(96, 74 + i * 54, 330, 50), 28)
		var value := _label(attributes, "", Rect2(434, 74 + i * 54, 288, 50), 34)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if i == 1: defense_value = value
		else: attribute_values.append(value)
		var divider := _image(attributes, "divider", Rect2(0, 117 + i * 54, 740, 18))
		divider.stretch_mode = TextureRect.STRETCH_SCALE
	active_skill = Control.new()
	active_skill.position = Vector2(0, 342)
	active_skill.size = Vector2(740, 202)
	attributes.add_child(active_skill)
	active_icon = _image(active_skill, "", Rect2(14, 22, 44, 44))
	active_title = _label(active_skill, "", Rect2(96, 15, 620, 30), 28)
	active_description = _label(active_skill, "", Rect2(96, 47, 626, 26), 21)
	active_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_rules_button = Button.new()
	active_rules_button.text = "完整说明"
	active_rules_button.position = Vector2(506, 5)
	active_rules_button.size = Vector2(216, 38)
	active_rules_button.add_theme_font_size_override("font_size", 22)
	active_rules_button.pressed.connect(_open_active_rules)
	active_skill.add_child(active_rules_button)
	_label(active_skill, "伤害", Rect2(96, 88, 200, 50), 28)
	active_damage = _label(active_skill, "队伍攻击力 ×100%", Rect2(340, 88, 382, 50), 28)
	active_damage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(active_skill, "攻击间隔", Rect2(96, 145, 250, 50), 28)
	active_interval = _label(active_skill, "", Rect2(434, 145, 288, 50), 28)
	active_interval.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for boundary in [88, 145]:
		var divider := Control.new()
		divider.position = Vector2(96, boundary - 9)
		divider.size = Vector2(626, 18)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_skill.add_child(divider)
		divider.draw.connect(func():
			var color := Color("cda575")
			divider.draw_line(Vector2(5, 9), Vector2(621, 9), color, 1.0, true)
			divider.draw_colored_polygon(PackedVector2Array([Vector2(0,9), Vector2(5,6), Vector2(10,9), Vector2(5,12)]), color)
			divider.draw_colored_polygon(PackedVector2Array([Vector2(616,9), Vector2(621,6), Vector2(626,9), Vector2(621,12)]), color))
	skills = Control.new()
	skills.position = Vector2(484, 106)
	skills.size = Vector2(740, 580)
	design.add_child(skills)
	for i in 6:
		var y := i * 95.0
		var panel := Panel.new()
		panel.position = Vector2(0, y)
		panel.size = Vector2(740, 89)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skills.add_child(panel)
		skill_panels.append(panel)
		skill_locks.append(_image(skills, "lock", Rect2(14, y + 14, 56, 56)))
		# 标题与实际换行后的正文作为一组，在整条技能框内垂直居中。
		var copy := VBoxContainer.new()
		copy.position = Vector2(86, 0)
		copy.size = Vector2(628, 89)
		copy.alignment = BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation", 0)
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(copy)
		var title := _label(copy, "", Rect2(0, 0, 628, 32), 25)
		title.custom_minimum_size.y = 32
		skill_titles.append(title)
		var badge := _label(skills, "", Rect2(574, y + 17, 144, 28), 17)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		skill_badges.append(badge)
		var body := _label(copy, "", Rect2(0, 0, 628, 0), 19)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		skill_bodies.append(body)
	error_label = _label(design, "角色数据异常，无法展示培养进度", Rect2(490, 180, 700, 100), 25)
	error_label.hide()
	active_rules_modal = SproutModal.new()
	design.add_child(active_rules_modal)
	active_rules_modal._panel.custom_minimum_size = Vector2(780, 500)
	active_rules_modal._panel.size = Vector2(780, 500)
	active_rules_modal._panel.offset_left = -390
	active_rules_modal._panel.offset_top = -250
	active_rules_modal._panel.offset_right = 390
	active_rules_modal._panel.offset_bottom = 250
	active_rules_modal._body_label.add_theme_font_size_override("font_size", 26)
	active_rules_modal._title_label.add_theme_font_size_override("font_size", 30)
	active_rules_modal._cancel_button.hide()
	active_rules_modal.closed.connect(func(): active_rules_button.grab_focus())
	_toast = Toast.attach_to(self)
	resized.connect(_layout)
	_layout()

func _label(parent: Control, text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", SproutTheme.INK)
	parent.add_child(label)
	return label

func _image(parent: Control, asset: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	if not asset.is_empty(): image.texture = load(SKIN_ROOT + asset + ".png")
	if asset in ["health_syringe", "defense"]:
		# 设计稿保留透明留白，仅裁显示区域，使针筒与既有属性图标等大。
		var cropped := AtlasTexture.new()
		cropped.atlas = image.texture
		cropped.region = image.texture.get_image().get_used_rect()
		image.texture = cropped
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _patch(parent: Control, asset: String, rect: Rect2, margins: Vector4) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = load(SKIN_ROOT + asset + ".png")
	patch.position = rect.position
	patch.size = rect.size
	patch.patch_margin_left = int(margins.x)
	patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z)
	patch.patch_margin_bottom = int(margins.w)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(patch)
	return patch

func _style(asset: String, margins: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(SKIN_ROOT + asset + ".png")
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	return style

func _rounded_skin(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 16
	style.anti_aliasing = true
	return style

func _layout() -> void:
	if not is_instance_valid(design): return
	var fit := minf(size.x / 1280.0, size.y / 720.0) * 0.83
	design.scale = Vector2.ONE * fit
	design.position = (size - Vector2(1280, 720) * fit) * 0.5

func present(id: String) -> void:
	if not Progression.CHARACTERS.has(id): return
	character_id = id
	var config: Dictionary = Progression.CHARACTERS[id]
	portrait.texture = load(Progression.portrait_path(id))
	rarity_badge.configure(id, Rect2(165, 25, 140, 68))
	faction_icon.texture = load("res://assets/ui/factions/" + str(config.faction) + ".png")
	name_label.text = config.name
	# 图标和原生姓名文字作为一组，居中于原姓名牌。
	var name_width := name_label.get_theme_font("font").get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
	var group_left := 246.0 - (48.0 + 8.0 + name_width) / 2.0
	faction_icon.position.x = group_left
	name_label.position.x = group_left + 56.0
	name_label.size.x = name_width
	refresh()
	select_tab(0)
	show()
	_close_button.grab_focus()

func refresh() -> void:
	_record = Progression.record(SaveManager, character_id)
	error_label.visible = not _record.valid
	for button in tabs: button.disabled = not _record.valid
	for i in 6:
		var unlocked := bool(_record.valid) and i < int(_record.get("rank", 0))
		stars[i].texture = load(SKIN_ROOT + ("star_lit" if unlocked else "star_dim") + ".png")
	if not _record.valid:
		attributes.hide()
		skills.hide()
		return
	level_label.text = "等级 %d" % _record.level
	experience_label.text = "已满级" if _record.level == 30 else "%d / %d" % [_record.exp, _record.required_exp]
	var ratio := 1.0 if _record.level == 30 else float(_record.exp) / float(_record.required_exp)
	experience_bar.value = ratio * 100.0
	attribute_values[0].text = str(_record.attack)
	attribute_values[1].text = str(_record.health)
	active_icon.texture = preload("res://scripts/ui/components/bag_icon_display.gd").texture(load(Progression.skill_icon_path(character_id)))
	var active_config: Dictionary = Progression.CHARACTERS[character_id]
	active_title.text = "技能 · " + str(active_config.active_name)
	active_description.text = str(active_config.active_description)
	active_rules_button.visible = active_config.has("active_rules_text")
	var active := Progression.active_skill(character_id, int(_record.level))
	active_interval.text = ("%.2f" % active.interval).trim_suffix("0").trim_suffix(".") + " 秒"
	active_damage.text = "队伍攻击力 ×%s%%" % (("%.1f" % (active.multiplier * 100.0)).trim_suffix("0").trim_suffix("."))
	if active_config.get("implementation_status", "") == "catalog_only":
		active_title.text = "技能设计 · " + str(active_config.active_name)
		active_damage.text = "实战效果尚未接入"
		if float(active_config.interval_start) <= 0.0:
			active_interval.text = "团队被动"
	defense_value.text = str(_record.defense)
	_refresh_satiety()
	var recovery := "%.4f" % _record.recovery_percent
	if recovery.ends_with("0"): recovery = recovery.left(-1)
	attribute_values[3].text = recovery + "%"
	breakthrough_button.visible = _record.needs_breakthrough
	# 两位数等级留足文字空间；突破时缩短经验条，按钮保持原有点击范围。
	var experience_left := 175.0 if int(_record.level) >= 10 else 155.0
	var experience_right := 444.0 if breakthrough_button.visible else 740.0
	experience_bar.position.x = experience_left
	experience_label.position.x = experience_left
	experience_bar.size.x = experience_right - experience_left
	experience_label.size.x = experience_right - experience_left
	breakthrough_button.text = "突破 · %d金币" % _record.breakthrough_cost
	_update_breakthrough()
	var config: Dictionary = Progression.CHARACTERS[character_id]
	for i in 6:
		var unlocked := i < int(_record.rank)
		skill_panels[i].add_theme_stylebox_override("panel", _rounded_skin(Color("#f3f3d5") if unlocked else Color("#f4e8d7"), Color("#9da649") if unlocked else Color("#d6b995"), 22, 2))
		skill_locks[i].texture = load(SKIN_ROOT + ("skill_gift" if unlocked else "lock") + ".png")
		skill_titles[i].text = config.skills[i][0]
		skill_bodies[i].text = config.skills[i][1]
		skill_badges[i].text = "已解锁" if unlocked else "%d阶解锁" % (i + 1)
		var color := SproutTheme.INK if unlocked else Color("#81796c")
		for label in [skill_titles[i], skill_bodies[i], skill_badges[i]]:
			label.add_theme_color_override("font_color", color)
	select_tab(selected_tab)

func select_tab(index: int) -> void:
	if is_instance_valid(_toast): _toast.dismiss()
	selected_tab = index
	attributes.visible = index == 0 and bool(_record.get("valid", false))
	skills.visible = index == 1 and bool(_record.get("valid", false))
	for i in 2:
		# 页签整张等比缩小，不拉伸弧角和手绘纸纹。
		var style := _style("tab_selected_v2" if i == index else "tab_idle_v2", Vector4.ZERO)
		for state in ["normal", "hover", "pressed"]: tabs[i].add_theme_stylebox_override(state, style)
		var color := SproutTheme.CREAM if i == index else SproutTheme.INK
		SproutTheme.apply_tab_button_colors(tabs[i], color)

func _update_breakthrough() -> void:
	_last_gold = SaveManager.gold_balance()
	breakthrough_button.disabled = _busy or _last_gold < int(_record.get("breakthrough_cost", 0)) or bool(SaveManager.get("_replaying")) or bool(SaveManager.get("_prologue_preview"))
	breakthrough_button.tooltip_text = "金币不足" if _last_gold < int(_record.get("breakthrough_cost", 0)) else "突破后可继续升级，不提升星阶"

func _refresh_satiety() -> void:
	var food := Progression.satiety_snapshot(SaveManager)
	attribute_values[2].text = "%s / %d" % [Progression.food_text(float(food.values.get(character_id, 0.0))), _record.satiety_max] if food.valid else "数据异常"

func _process(_delta: float) -> void:
	if visible and _record.get("valid", false): _refresh_satiety()
	if visible and _record.get("valid", false) and SaveManager.gold_balance() != _last_gold: _update_breakthrough()

func _breakthrough() -> void:
	if _busy: return
	_busy = true
	var result := Progression.breakthrough(SaveManager, character_id)
	_busy = false
	refresh()
	if result.success:
		_toast.show_message("突破成功")
		tabs[0].grab_focus()
	else:
		var messages := {"insufficient_gold": "金币不足", "save_failed": "保存失败，金币未扣除", "preview": "演示中无法突破", "not_eligible": "当前无需突破", "invalid_record": "角色数据异常", "not_restaurant": "请返回餐厅后突破"}
		_toast.show_message(messages.get(result.reason, "暂时无法突破"))

func _open_active_rules() -> void:
	var config: Dictionary = Progression.CHARACTERS[character_id]
	active_rules_modal.show_modal(str(config.active_name) + " · 完整说明", str(config.active_rules_text), "返回属性")

func close_modal() -> void:
	if active_rules_modal.visible:
		active_rules_modal.close_modal()
		return
	_toast.dismiss()
	super.close_modal()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_modal()

