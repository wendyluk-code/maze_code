extends TextureRect
## 共用稀有度字标。调用方为其预留空白，不覆盖头像、姓名或星级。
const Growth = preload("res://scripts/characters/character_progression.gd")

func configure(id: String, rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Growth.CHARACTERS.has(id)
	if visible: texture = load("res://assets/ui/recruitment/%s.png" % Growth.CHARACTERS[id].rarity)

static func attach(parent: Node, id: String, rect: Rect2) -> TextureRect:
	var badge = load("res://scripts/ui/components/rarity_badge.gd").new()
	parent.add_child(badge)
	badge.configure(id, rect)
	return badge

func configure_bottom_right(id: String, corner: Vector2, maximum := Vector2(25,18)) -> void:
	configure(id, Rect2(Vector2.ZERO, maximum))
	if not visible: return
	texture = preload("res://scripts/ui/components/bag_icon_display.gd").texture(texture)
	var factor := minf(maximum.x / texture.get_width(), maximum.y / texture.get_height())
	size = texture.get_size() * factor
	position = corner - size
