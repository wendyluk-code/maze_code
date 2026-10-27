extends HBoxContainer
## 设计稿：顶部独立键帽、中央技能图标、底部名称；复用组件库面板与键帽。
signal selected(slot: int)
signal details_requested(slot: int)
const Skills = preload("res://scripts/maze/team_attack.gd")
var buttons: Array[Button]=[]
var icons: Dictionary={}
var last_state: String=""
var pictures: Array[TextureRect]=[]
var captions: Array[Label]=[]
var rings: Array[Control]=[]
var factions: Dictionary={}
var badges: Array[TextureRect]=[]
var rarities: Array[TextureRect]=[]
const Growth = preload("res://scripts/characters/character_progression.gd")

func _ready() -> void:
	add_theme_constant_override("separation",8)
	mouse_filter=Control.MOUSE_FILTER_STOP
	icons.hero=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load("res://assets/combat/spatula_projectile_v1.png"))
	for id in Growth.CHARACTERS:
		icons[id]=preload("res://scripts/ui/components/bag_icon_display.gd").texture(load(Growth.skill_icon_path(id)))
		factions[id]=load("res://assets/ui/factions/%s.png" % Growth.CHARACTERS[id].faction)
	for i in 5:
		var button := Button.new()
		button.custom_minimum_size=Vector2(78,80)
		button.focus_mode=Control.FOCUS_NONE
		button.toggle_mode=true
		button.pressed.connect(func():selected.emit(i))
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click and i > 0 and not button.disabled:
				button.accept_event()
				details_requested.emit(i))
		add_child(button)
		buttons.append(button)
		var inset := Panel.new()
		inset.position=Vector2(5,5)
		inset.size=Vector2(68,70)
		inset.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var inset_style := SproutTheme.thin_panel_style(Color.TRANSPARENT)
		inset_style.border_color=Color("d6bc92")
		inset_style.set_border_width_all(1)
		inset.add_theme_stylebox_override("panel",inset_style)
		button.add_child(inset)
		var picture := TextureRect.new()
		picture.position=Vector2(17,18)
		picture.size=Vector2(44,42)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		pictures.append(picture)
		if i>0:
			picture.position=Vector2(21,20)
			picture.size=Vector2(36,36)
			picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.clip_contents=true
		var faction := TextureRect.new()
		faction.position=Vector2(-5,-5)
		faction.size=Vector2(24,24)
		faction.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		faction.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		faction.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(faction)
		badges.append(faction)
		rarities.append(preload("res://scripts/ui/components/rarity_badge.gd").attach(button, "", Rect2(53, 1, 25, 18)))
		if i==0:
			picture.pivot_offset=Vector2(22,21)
			picture.rotation=PI/4

		var ring := Control.new()
		ring.position=Vector2(23,24)
		ring.size=Vector2(32,32)
		ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ring.draw.connect(func():
			for segment in 10:
				var start := float(segment)*TAU/10.0
				ring.draw_arc(Vector2(16,16),15,start,start+TAU/10.0*0.67,8,Color("a99a86"),2,true))
		button.add_child(ring)
		rings.append(ring)
		var label := Label.new()
		label.theme=SproutTheme.make_theme()
		label.position=Vector2(0,58)
		label.size=Vector2(78,20)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",14)
		label.add_theme_color_override("font_color",SproutTheme.INK)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		captions.append(label)
		var key := preload("res://scenes/ui/key_button.tscn").instantiate()
		button.add_child(key)
		key.position=Vector2(19,-12) if i==0 else Vector2(24,-12)
		key.custom_minimum_size=Vector2(40 if i==0 else 30,28)
		key.size=key.custom_minimum_size
		var texture := AtlasTexture.new()
		texture.atlas=preload("res://assets/ui/key_square26_frame0.png")
		texture.region=Rect2(11,11,26,28)
		key.get_node("KeyIcon").texture=texture
		key.get_node("KeyIcon").expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		key.get_node("KeyIcon").stretch_mode=TextureRect.STRETCH_SCALE
		var key_label := key.get_node("KeyIcon/KeyLabel") as Label
		key_label.text="空格" if i==0 else str(i)
		key_label.add_theme_font_override("font",SproutTheme.FONT_CN)
		key_label.add_theme_font_size_override("font_size",16)
		key_label.add_theme_color_override("font_color",SproutTheme.INK)

func sync(run: Dictionary) -> void:
	var signature := str(run.members)+str(run.combat.get("selected",0))
	if signature==last_state: return
	last_state=signature
	for i in buttons.size():
		var id: String = "hero" if i == 0 else (str(run.members[i - 1].id) if i <= run.members.size() else "")
		rarities[i].configure_bottom_right(id, buttons[i].size + Vector2(3,3))
		captions[i].text="默认" if i==0 else str(Growth.CHARACTERS.get(id, {}).get("name", "空位"))
		buttons[i].disabled=id.is_empty()
		pictures[i].texture=icons.get(id)
		badges[i].texture=factions.get(id)
		badges[i].visible=factions.has(id)
		rings[i].visible=id.is_empty()
		buttons[i].set_pressed_no_signal(int(run.combat.get("selected",0))==i)
		var style := SproutTheme.thin_panel_style(Color("fff2d9") if not id.is_empty() else Color("ddd2bf"))
		style.set_content_margin_all(0)
		if buttons[i].button_pressed:
			style.border_color=Color("ffc34d")
			style.set_border_width_all(3)
			style.shadow_color=Color(1,0.7,0.18,0.6)
			style.shadow_size=4
		for state in ["normal","hover","pressed","disabled"]: buttons[i].add_theme_stylebox_override(state,style)
