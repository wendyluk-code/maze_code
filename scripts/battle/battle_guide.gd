extends Control
## 战斗专用组合：只复用对白框与指示资源，不实例化餐厅 TutorialGuide。
signal sentence_changed(focus: String)
signal explanation_finished

const DIALOG = preload("res://scenes/ui/dialog_box.tscn")
const CUTOUT = preload("res://scripts/battle/battle_guide_cutout.gdshader")
var dialog: Control
var shade: ColorRect
var pointer: TextureRect
var hint_panel: PanelContainer
var hint_label: Label
var explaining := false
var sentences: Array = []
var sentence := 0
var focus := ""
var cutouts: Array[Rect2] = []
var held_inputs: Dictionary = {}

func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	shade = ColorRect.new()
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = CUTOUT
	shade.material = mat
	add_child(shade)
	dialog = DIALOG.instantiate()
	add_child(dialog)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dialog.position = Vector2(18, 395)
	dialog.size = Vector2(354, 150)
	dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog.set_process_input(false)
	dialog.set_process_unhandled_input(false)
	dialog.finished.connect(_next_sentence)
	pointer = TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/ui/battle/tutorial/cooking_pointer_v1.png")
	atlas.region = Rect2(451, 110, 352, 1016)
	pointer.texture = atlas
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(pointer)
	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_theme_stylebox_override("panel", preload("res://scripts/ui/components/sprout_theme.gd").thin_panel_style())
	hint_panel.position = Vector2(940, 430)
	hint_panel.size = Vector2(248, 96)
	add_child(hint_panel)
	hint_label = Label.new()
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_panel.add_child(hint_label)
	cancel()

func begin(lines: Array) -> void:
	cancel()
	if lines.is_empty():
		explanation_finished.emit()
		return
	sentences = lines
	sentence = 0
	explaining = true
	show()
	shade.show()
	hint_panel.hide()
	# 已经按住的键必须先释放；重复事件不会翻页。
	for key in [KEY_E, KEY_SPACE, KEY_ENTER]:
		if Input.is_key_pressed(key): held_inputs[key] = true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): held_inputs[-1] = true
	_show_sentence()

func _show_sentence() -> void:
	focus = sentences[sentence][1]
	dialog.start("", [sentences[sentence][0]])
	sentence_changed.emit(focus)

func _next_sentence() -> void:
	sentence += 1
	if sentence < sentences.size():
		_show_sentence()
	else:
		explaining = false
		dialog.hide_box()
		explanation_finished.emit()

func consume(event: InputEvent) -> void:
	if not explaining: return
	var code := 0
	var down := false
	if event is InputEventKey:
		if event.keycode not in [KEY_E, KEY_SPACE, KEY_ENTER]: return
		code = event.keycode
		down = event.pressed
		if event.echo: return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		code = -1
		down = event.pressed
	else: return
	if not down:
		held_inputs.erase(code)
		return
	if held_inputs.has(code): return
	held_inputs[code] = true
	dialog._advance()

func practice(text: String) -> void:
	explaining = false
	dialog.hide_box()
	show()
	shade.show()
	hint_panel.show()
	hint_label.text = text
	(shade.material as ShaderMaterial).set_shader_parameter("darkness", 0.22)

func highlight(rects: Array[Rect2], indicate: Rect2) -> void:
	cutouts = rects
	var packed := PackedVector4Array()
	for i in range(8):
		var r := rects[i] if i < rects.size() else Rect2()
		packed.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	shade.material.set_shader_parameter("holes", packed)
	shade.material.set_shader_parameter("hole_count", mini(8, rects.size()))
	shade.material.set_shader_parameter("darkness", 0.48 if explaining else 0.22)
	pointer.visible = indicate.has_area()
	# 双尖指针在目标左边，不覆盖卡面数值。
	pointer.size = Vector2(24, 69)
	pointer.pivot_offset = pointer.size * 0.5
	pointer.rotation = -PI * 0.5
	var center := Vector2(indicate.position.x - 42, indicate.get_center().y)
	if indicate.position.x < 80 or (explaining and focus in ["ap", "health"]): center.x = indicate.end.x + 42
	center.x = clampf(center.x, 36, 1244)
	center.y = clampf(center.y, 14, 706)
	pointer.position = center - pointer.size * 0.5

func cancel() -> void:
	explaining = false
	sentences.clear()
	held_inputs.clear()
	cutouts.clear()
	if is_instance_valid(dialog): dialog.hide_box()
	hide()
