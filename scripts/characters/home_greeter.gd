extends Node2D
## 常驻迎接角色：固定站位，挥手后保持招呼姿势；仅发送选中信号。
signal selected(character_id: String)
const FOOT := Vector2(192, 352)
var character_id := ""
var body: AnimatedSprite2D
var hit_button: Button

func configure(id: String) -> void:
	character_id = id

func _ready() -> void:
	add_to_group("home_greeter")
	position = Vector2(590, 510) if character_id == "yaya" else Vector2(970, 510)
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/characters/tieshan/ground_shadow.png")
	shadow.scale = Vector2(1.26, 0.9) if character_id == "yaya" else Vector2(1.65, 1.05)
	shadow.modulate.a = 0.55
	add_child(shadow)
	body = AnimatedSprite2D.new()
	body.centered = false
	body.offset = -FOOT
	body.scale = Vector2.ONE * (258.0 if character_id == "yaya" else 336.0) / 312.0
	var frames := SpriteFrames.new()
	frames.add_animation("greet")
	frames.set_animation_loop("greet", false)
	frames.set_animation_speed("greet", 3.5)
	var atlas: Texture2D = load("res://assets/characters/home/%s_greeting.png" % character_id)
	for index in [0, 1, 0, 1, 0]:
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(index * 384, 0, 384, 384)
		frames.add_frame("greet", frame)
	body.sprite_frames = frames
	add_child(body)
	body.play("greet")
	hit_button = Button.new()
	hit_button.name = "SelectCharacter"
	hit_button.position = Vector2(-155, -340 if character_id == "tieshan" else -260)
	hit_button.size = Vector2(310, 348 if character_id == "tieshan" else 268)
	hit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit_button.tooltip_text = ("芽芽" if character_id == "yaya" else "铁山") + " · 查看拥有的卡牌"
	for state in ["normal", "hover", "pressed", "disabled"]:
		hit_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hit_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hit_button.pressed.connect(func(): selected.emit(character_id))
	add_child(hit_button)
	var caption := Label.new()
	caption.theme = SproutTheme.make_theme()
	caption.text = ("芽芽" if character_id == "yaya" else "铁山") + " · 查看卡牌"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(-155, 6)
	caption.size = Vector2(310, 32)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_color", SproutTheme.INK)
	add_child(caption)
	hit_button.focus_entered.connect(func(): caption.add_theme_color_override("font_color", Color("48734b")))
	hit_button.focus_exited.connect(func(): caption.add_theme_color_override("font_color", SproutTheme.INK))
