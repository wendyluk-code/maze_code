extends "res://scripts/interactable_point.gd"
## 独立道具贴图与脚底碰撞；草叶前景从原地图局部采样，不替换底图。
func _ready() -> void:
	super._ready()
	var sprite := Sprite2D.new()
	sprite.name = "BinArt"
	sprite.texture = preload("res://assets/props/trash/trash_bin.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.region_enabled = true
	sprite.region_rect = Rect2(250, 150, 820, 960)
	sprite.scale = Vector2.ONE * 0.125
	sprite.position = Vector2(0, -60)
	add_child(sprite)
	var body := StaticBody2D.new()
	body.name = "BinCollision"
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 22
	shape.height = 80
	collision.shape = shape
	collision.rotation = PI / 2
	collision.position = Vector2(0, -17)
	body.add_child(collision)
	add_child(body)
	# 左侧原生草叶盖住桶脚，桶背后的叶片继续由底图显示。
	var grass := Polygon2D.new()
	grass.name = "ForegroundGrass"
	var points := PackedVector2Array([Vector2(125, 511), Vector2(143, 515), Vector2(153, 530), Vector2(169, 528), Vector2(179, 537), Vector2(175, 546), Vector2(163, 549), Vector2(176, 560), Vector2(174, 572), Vector2(155, 570), Vector2(140, 550), Vector2(125, 545)])
	grass.texture = preload("res://assets/maps/restaurant_map.png")
	grass.uv = points
	var local := PackedVector2Array()
	for point in points:
		local.append(point - position)
	grass.polygon = local
	add_child(grass)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	# 玩家在吧台后方时，旧底图前景采样也会重绘桶的位置；桶应仍在其前方。
	# 走到桶前则回到角色下层，避免桶盖住从下方经过的玩家。
	z_index = 51 if is_instance_valid(player) and player.global_position.y < global_position.y else 0
