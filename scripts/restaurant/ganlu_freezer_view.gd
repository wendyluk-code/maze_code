extends Node2D
const Service := preload("res://scripts/restaurant/ganlu_service.gd")
const Art := preload("res://scripts/ui/components/ganlu_art.gd")
const POSITIONS := [Vector2(-29,-85), Vector2(0,-6), Vector2(30,73)]
var layout: Node2D
var controller: Node
var buttons: Array[Button] = []
var cup_texture: Texture2D = Art.cup()
var thermometer: Texture2D = Art.thermometer()
var selected_slot := -1
var prompt: Control
var prompts: Array[Control] = []
var cup_visible_region := Rect2(0,0,1,1)

func thermometer_rect(index: int) -> Rect2:
	var cup_rect := Rect2(slot_position(index)-Vector2(19,48),Vector2(38,52))
	var visible_rect := Rect2(cup_rect.position+cup_visible_region.position*cup_rect.size,cup_visible_region.size*cup_rect.size)
	return Rect2(Vector2(visible_rect.end.x+2.0,visible_rect.position.y),Vector2(17,visible_rect.size.y))

func slot_position(index: int) -> Vector2:
	return to_local(layout.get_node("Slot%d" % (index+1)).global_position)

func anchor_position(index: int, anchor: String) -> Vector2:
	return to_local(layout.get_node("Slot%d/%s" % [index+1,anchor]).global_position)

func nearest_slot() -> int:
	var point: Vector2 = to_local(controller.hud._player.global_position)
	var best := 0
	for i in range(1,3):
		if point.distance_squared_to(slot_position(i)) < point.distance_squared_to(slot_position(best)): best = i
	return best

func small_texture(source: AtlasTexture) -> ImageTexture:
	# 独立裁出图素再生成多级缩小纹理，避免图集串色与大图缩小时的闪烁锯齿。
	var pixels := source.atlas.get_image().get_region(Rect2i(source.region))
	pixels.generate_mipmaps()
	return ImageTexture.create_from_image(pixels)

func _ready() -> void:
	layout = get_parent().get_node("FreezerLayout")
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cup_texture = small_texture(Art.cup())
	thermometer = small_texture(Art.thermometer())
	var cup_image := Art.result_cup().get_image()
	var used := Rect2(cup_image.get_used_rect())
	cup_visible_region = Rect2(used.position/Vector2(cup_image.get_size()),used.size/Vector2(cup_image.get_size()))
	var prompt_layer := CanvasLayer.new()
	add_child(prompt_layer)
	for index in range(3):
		var item: Control = preload("res://scenes/ui/interact_button.tscn").instantiate()
		prompt_layer.add_child(item)
		item.size = Vector2(140,48)
		item.visible = false
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		for child in item.find_children("*","Control",true,false):
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.gui_input.connect(_on_prompt_input.bind(index))
		prompts.append(item)
	prompt = prompts[0]
	for i in range(3):
		var button := Button.new()
		button.position = slot_position(i) - Vector2(25,48)
		button.size = Vector2(50,57)
		button.theme = SproutTheme.make_theme()
		button.add_theme_font_size_override("font_size", 14)
		for state in ["normal","hover","pressed","focus","disabled"]: button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		button.pressed.connect(func(): controller.use_slot(i))
		add_child(button)
		buttons.append(button)
func _on_prompt_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if prompts[index].visible and selected_slot == index and not buttons[index].disabled:
			get_viewport().set_input_as_handled()
			controller.use_slot(index)

func _process(_delta: float) -> void:
	visible = SaveManager.freezer_unlocked()
	layout.visible = visible
	var can_use: bool = controller.can_use_freezer()
	selected_slot = nearest_slot() if can_use else -1
	var state := Service.snapshot(SaveManager)
	for i in range(3):
		buttons[i].position = slot_position(i) - Vector2(25,48)
		buttons[i].disabled = i != selected_slot or Service.chilling(state.slots[i])
		buttons[i].text = ""
		buttons[i].tooltip_text = ""
		var ready: bool = not state.slots[i].is_empty() and not Service.chilling(state.slots[i])
		var item := prompts[i]
		item.visible = visible and (ready or i == selected_slot) and not preload("res://scripts/restaurant/preparation.gd").restricted(SaveManager)
		item.get_node("Content/ActionLabel").text = "拿取" if ready else "冰镇"
		var screen: Vector2 = get_viewport().get_canvas_transform() * to_global(anchor_position(i,"Prompt"))
		item.position = screen - item.size * 0.5
		item.modulate = Color("92968d") if Service.chilling(state.slots[i]) else Color.WHITE
		item.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if buttons[i].disabled else Control.CURSOR_POINTING_HAND
	if selected_slot >= 0:
		prompt = prompts[selected_slot]
	queue_redraw()

func _draw() -> void:
	var state := Service.snapshot(SaveManager)
	for i in range(3):
		var base: Vector2 = slot_position(i)
		var outline: Polygon2D = layout.get_node("Slot%d/Selection" % (i+1))
		var hole := PackedVector2Array()
		for vertex in outline.polygon:
			hole.append(to_local(outline.to_global(vertex)))
		if i==selected_slot:
			hole.append(hole[0])
			draw_polyline(hole,Color("c2ccc4") if Service.chilling(state.slots[i]) else Color("e4faff"),2,true)
		var cup: Dictionary = state.slots[i]
		if cup.is_empty(): continue
		var cold := Service.grade(cup)
		preload("res://scripts/ui/components/ganlu_cup_visual.gd").draw_cup(self,Rect2(base-Vector2(19,48),Vector2(38,52)),cold)
		var meter_rect := thermometer_rect(i)
		var meter := meter_rect.position
		var inner_height := meter_rect.size.y-8.0
		var style := StyleBoxFlat.new()
		style.bg_color = Color("de6860") if cold==4 else Color("a6bab1")
		if cold==1:
			var pulse := (sin(Time.get_ticks_msec()/1000.0*TAU)+1.0)*0.5
			style.bg_color = Color("31975b").lerp(Color("81ffad"),pulse)
		style.set_corner_radius_all(5)
		style.anti_aliasing = true
		style.draw(get_canvas_item(),meter_rect)
		style.bg_color = Color("ec7c72") if cold==4 else Color("eee7d4")
		style.draw(get_canvas_item(),Rect2(meter+Vector2(4,4),Vector2(9,inner_height)))
		var height := inner_height*Service.fill(cup)
		if cold!=4 and height>0.0:
			style.bg_color = Color("7cc9dd")
			style.draw(get_canvas_item(),Rect2(meter+Vector2(4,meter_rect.size.y-4.0-height),Vector2(9,height)))


