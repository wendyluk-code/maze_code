extends Node2D
## 等餐提示只读取订单；跟随人物但保持世界尺寸，不参与输入。
const Icons := preload("res://scripts/ui/components/bag_icon_display.gd")
const Recipes := preload("res://scripts/cooking/recipe_catalog.gd")
var dish: Texture2D
var item_id := ""
var panel := StyleBoxFlat.new()
var _tops: Dictionary = {}

func _init() -> void:
	panel.bg_color = Color("fff0d5")
	panel.border_color = Color("a77d54")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	panel.anti_aliasing = true
	z_index = 5

func setup(recipe: String) -> void:
	if recipe == item_id: return
	item_id = recipe
	dish = Icons.texture(Recipes.item_texture(recipe))
	queue_redraw()

func follow(actor: Sprite2D) -> void:
	scale = Vector2.ONE / actor.scale
	var texture: AtlasTexture = actor.texture
	var key := str(texture.region)
	if not _tops.has(key):
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		_tops[key] = pixels.get_used_rect().position.y
	position = Vector2(0, actor.offset.y - texture.get_height() * 0.5 + float(_tops[key]) - 6.0 / actor.scale.y)

func _draw() -> void:
	panel.draw(get_canvas_item(), Rect2(-31, -62, 62, 50))
	# 用底色打通面板下沿，尖头只画两侧，不留下内部横线。
	draw_rect(Rect2(-8, -15, 16, 3), panel.bg_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-12), Vector2(0,-1), Vector2(8,-12)]), panel.bg_color)
	draw_polyline(PackedVector2Array([Vector2(-8,-12), Vector2(0,-1), Vector2(8,-12)]), panel.border_color, 2.0, true)
	if dish:
		var extent := dish.get_size() * minf(42.0 / dish.get_width(), 36.0 / dish.get_height())
		draw_texture_rect(dish, Rect2(Vector2(0,-37) - extent * 0.5, extent), false)
