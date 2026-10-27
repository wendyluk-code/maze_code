extends Control
## 入队卡面复用角色详情左栏皮肤、立绘、星阶和姓名坐标。
const Progression := preload("res://scripts/characters/character_progression.gd")
const ROOT := "res://assets/ui/character_details/"
var character_id := ""
var stars: Array[TextureRect] = []

func configure(id: String, rank_snapshot: int = -1) -> void:
	character_id = id
	size = Vector2(470, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = SproutTheme.make_theme()
	# 保持原详情皮肤比例，只显示左侧角色区域，不拉伸整张纸面。
	var paper := _image(ROOT + "paper_background_v3.png", Rect2(0, 0, 470, 720))
	var region := AtlasTexture.new()
	region.atlas = paper.texture
	region.region = Rect2(0, 0, paper.texture.get_width() * 470.0 / 1280.0, paper.texture.get_height())
	paper.texture = region
	_image(Progression.portrait_path(id), Rect2(25, 100, 420, 420))
	var record := Progression.record(get_node("/root/SaveManager"), id)
	if rank_snapshot >= 0: record = {"valid": true, "rank": rank_snapshot}
	preload("res://scripts/ui/components/rarity_badge.gd").attach(self, id, Rect2(165, 25, 140, 68))
	for i in 6:
		stars.append(_image(ROOT + ("star_lit" if record.get("valid", false) and i < int(record.get("rank", 0)) else "star_dim") + ".png", Rect2(50 + i * 61, 521, 54, 54)))
	var config: Dictionary = Progression.CHARACTERS[id]
	var label := Label.new()
	label.text = config.name
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", SproutTheme.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
	var left := 246.0 - (56.0 + width) / 2.0
	_image("res://assets/ui/factions/" + str(config.faction) + ".png", Rect2(left, 605, 48, 48))
	label.position = Vector2(left + 56, 599)
	label.size = Vector2(width, 60)

func _image(path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	return image

## 演出只更新六颗星，不重读或修改成长记录。
func display_rank(rank_value: int) -> void:
	for i in stars.size():
		stars[i].texture = load(ROOT + ("star_lit" if i < rank_value else "star_dim") + ".png")
