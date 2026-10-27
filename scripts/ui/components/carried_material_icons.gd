extends Node2D
## 餐厅携物显示：读取真实材料及料理成品，不复制库存；正背面保留最近水平朝向。
const Catalog := preload("res://scripts/cooking/recipe_catalog.gd")
const IconDisplay := preload("res://scripts/ui/components/bag_icon_display.gd")
const ICON_SIZE := 26.0
const BACKING_RADIUS := 12.0
const BACKING_COLOR := Color("a87950")
const BORDER_COLOR := Color("946239")
const SPACING := 28.0
const SIDE_OFFSET := 48.0
var side := -1
var _ids: Array = []

func _process(_delta: float) -> void:
	var actor := get_parent() as Node2D
	var direction: Vector2 = actor.get("facing")
	if direction.x > 0.1:
		side = -1
	elif direction.x < -0.1:
		side = 1
	position = Vector2(side * SIDE_OFFSET, -66)
	var ids := SaveManager.carried_ingredients().keys()
	var inventory := SaveManager.inventory_snapshot()
	for recipe_id in Catalog.RECIPES:
		if int(inventory.get(recipe_id, 0)) > 0:
			ids.append(recipe_id)
	if ids == _ids:
		return
	_ids = ids
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# 旧档即使超过三种也完整显示，不丢弃真实材料。
	for index in ids.size():
		var texture := IconDisplay.texture(Catalog.item_texture(str(ids[index])))
		if texture == null:
			continue
		var icon := Sprite2D.new()
		icon.name = str(ids[index])
		icon.texture = texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.scale = Vector2.ONE * ICON_SIZE / maxf(texture.get_width(), texture.get_height())
		icon.position.y = index * SPACING
		add_child(icon)
	queue_redraw()

func _draw() -> void:
	# 底板绘于子图标下方，不裁切超框的食材尖角。
	for icon in get_children():
		var center: Vector2 = icon.position
		draw_circle(center + Vector2(0, 1), BACKING_RADIUS, Color("c8b695"), true, -1.0, true)
		draw_circle(center, BACKING_RADIUS, BACKING_COLOR, true, -1.0, true)
		draw_arc(center, BACKING_RADIUS - 0.5, 0.0, TAU, 64, BORDER_COLOR, 1.0, true)
