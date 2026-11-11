extends Node2D
const Service := preload("res://scripts/restaurant/ganlu_service.gd")
const Art := preload("res://scripts/ui/components/ganlu_art.gd")
const POSITIONS := [Vector2(-29,-85), Vector2(0,-6), Vector2(30,73)]
var controller: Node
var buttons: Array[Button] = []
var food_button: Button
var cup_texture: Texture2D = Art.cup()
var thermometer: Texture2D = Art.thermometer()
var selected_slot := -1
var prompt: Sprite2D

func nearest_slot() -> int:
	var point: Vector2 = to_local(controller.hud._player.global_position)
	var best := 0
	for i in range(1,3):
		if point.distance_squared_to(POSITIONS[i]) < point.distance_squared_to(POSITIONS[best]): best = i
	return best

func small_texture(source: AtlasTexture) -> ImageTexture:
	# 独立裁出图素再生成多级缩小纹理，避免图集串色与大图缩小时的闪烁锯齿。
	var pixels := source.atlas.get_image().get_region(Rect2i(source.region))
	pixels.generate_mipmaps()
	return ImageTexture.create_from_image(pixels)

func _ready() -> void:
	var tray := Polygon2D.new()
	tray.show_behind_parent = true
	tray.polygon = PackedVector2Array([Vector2(-81,-141),Vector2(-5,-157),Vector2(88,76),Vector2(-1,103)])
	tray.texture = preload("res://assets/ui/ganlu/tray.png")
	tray.uv = PackedVector2Array([Vector2(14,60),Vector2(242,20),Vector2(506,680),Vector2(252,736)])
	add_child(tray)
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cup_texture = small_texture(Art.cup())
	thermometer = small_texture(Art.thermometer())
	prompt = preload("res://scripts/ui/components/chest_interact_prompt.gd").new()
	add_child(prompt)
	var disabled_shader := Shader.new()
	disabled_shader.code = "shader_type canvas_item; uniform bool disabled = false; void fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; if(disabled){float g = dot(c.rgb, vec3(0.299,0.587,0.114)); c.rgb = vec3(g); } COLOR = c; }"
	var prompt_material := ShaderMaterial.new()
	prompt_material.shader = disabled_shader
	prompt.material = prompt_material
	for i in range(3):
		var button := Button.new()
		button.position = POSITIONS[i] - Vector2(25,48)
		button.size = Vector2(50,57)
		button.theme = SproutTheme.make_theme()
		button.add_theme_font_size_override("font_size", 14)
		for state in ["normal","hover","pressed","focus","disabled"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		button.pressed.connect(func(): controller.use_slot(i))
		add_child(button)
		buttons.append(button)
	food_button = SproutButton.new()
	food_button.set_icon_visible(false)
	food_button.text = "料理保鲜"
	food_button.position = Vector2(-215,-100)
	food_button.scale = Vector2.ONE * 0.7
	food_button.pressed.connect(controller.food_freezer)
	add_child(food_button)

func _process(_delta: float) -> void:
	visible = SaveManager.freezer_unlocked()
	var can_use: bool = controller.can_use_freezer()
	selected_slot = nearest_slot() if can_use else -1
	prompt.visible = selected_slot >= 0
	if selected_slot >= 0: prompt.position = POSITIONS[selected_slot] + Vector2(0,-77)
	var state := Service.snapshot(SaveManager)
	for i in range(3):
		buttons[i].disabled = i != selected_slot or Service.chilling(state.slots[i])
		buttons[i].text = ""
		buttons[i].tooltip_text = ""
	prompt.modulate = Color("92968d") if selected_slot>=0 and Service.chilling(state.slots[selected_slot]) else Color.WHITE
	prompt.material.set_shader_parameter("disabled",selected_slot>=0 and Service.chilling(state.slots[selected_slot]))
	food_button.visible = can_use
	queue_redraw()

func _draw() -> void:
	var state := Service.snapshot(SaveManager)
	for i in range(3):
		var base: Vector2 = POSITIONS[i]
		var hole := PackedVector2Array([base+Vector2(-43,-22),base+Vector2(18,-36),base+Vector2(38,17),base+Vector2(-23,31)])
		if i==selected_slot:
			hole.append(hole[0])
			draw_polyline(hole,Color("c2ccc4") if Service.chilling(state.slots[i]) else Color("e4faff"),2,true)
		var cup: Dictionary = state.slots[i]
		if cup.is_empty(): continue
		var cold := Service.grade(cup)
		preload("res://scripts/ui/components/ganlu_cup_visual.gd").draw_cup(self,Rect2(base-Vector2(19,48),Vector2(38,52)),cold)
		var meter := base+Vector2(37,-46)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("de6860") if cold==4 else Color("a6bab1")
		style.set_corner_radius_all(5)
		style.anti_aliasing = true
		style.draw(get_canvas_item(),Rect2(meter,Vector2(17,57)))
		style.bg_color = Color("ec7c72") if cold==4 else Color("eee7d4")
		style.draw(get_canvas_item(),Rect2(meter+Vector2(4,4),Vector2(9,49)))
		var height := 38.0*Service.fill(cup)
		if cold!=4:
			style.bg_color = Color("7cc9dd")
			style.draw(get_canvas_item(),Rect2(meter+Vector2(5,52-height),Vector2(7,height)))
		var line_color := Color("efaaa2") if cold==4 else Color("587c80")
		if cold==1:
			var pulse := 0.45+0.55*(sin(Time.get_ticks_msec()/1000.0*TAU)+1)*0.5
			line_color = Color("62d887")
			line_color.a = pulse
			draw_line(meter+Vector2(-3,14),meter+Vector2(20,14),Color(0.4,1,0.6,pulse*0.22),7,true)
		draw_line(meter+Vector2(-3,14),meter+Vector2(20,14),line_color,2,true)
