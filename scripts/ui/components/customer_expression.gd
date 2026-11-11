extends Node2D
## 单份透明五官图集，按人物/坐姿校准；不改原图或经营状态。
const SHEET := "res://assets/ui/customer_expressions/features.png"
const CLEAN := preload("res://scripts/ui/components/customer_face_clean.gdshader")
const NAMES := ["sad","impatient","angry","confused"]
static var features: Texture2D
var emotion := 0
var eyes := Vector2(190,160)
var mouth := Vector2(190,183)
var previous_material: Material
var actor: Sprite2D
var fitted_texture: Texture2D
var fitted_region := Rect2()
var fitted_flip := false

static func apply(target: Sprite2D, customer: String, kind: String) -> bool:
	clear(target)
	if not kind in NAMES or not target.texture is AtlasTexture: return false
	var atlas := target.texture as AtlasTexture
	var row := int(atlas.region.position.y)/384
	var column := int(atlas.region.position.x)/384
	var config := preload("res://scripts/restaurant/customer_catalog.gd").customer(customer)
	customer = str(config.get("face_template",customer))
	# 反馈仅使用已校准的正面候客/坐姿；吃饭、挥手、侧身不叠加。
	if row not in [0,1] or column != 0 or (customer not in ["mage","dingdang","half_elf"] and not config.has("face")): return false
	var layer := new()
	layer.name = "CustomerExpression"
	layer.actor = target
	layer.fitted_texture = target.texture
	layer.fitted_region = atlas.region
	layer.fitted_flip = target.flip_h
	layer.previous_material = target.material
	layer.emotion = NAMES.find(kind)
	var left := Vector2(163,160)
	var right := Vector2(216,160)
	var lip := Vector2(190,183)
	if customer == "dingdang":
		left = Vector2(161,165)
		right = Vector2(218,165)
		lip = Vector2(190,188)
	if customer == "half_elf":
		left = Vector2(164,162)
		right = Vector2(217,162)
		lip = Vector2(190,185)
	if row == 1:
		left = Vector2(168,194) if customer == "mage" else Vector2(161,193)
		right = Vector2(222,188) if customer == "mage" else Vector2(219,193)
		lip = Vector2(198,212) if customer == "mage" else Vector2(190,215)
		if customer == "half_elf":
			left = Vector2(166,194)
			right = Vector2(220,194)
			lip = Vector2(192,217)
	if config.has("face"):
		var points: Array = config.face[row]
		left = Vector2(points[0][0],points[0][1])
		right = Vector2(points[1][0],points[1][1])
		lip = Vector2(points[2][0],points[2][1])
	layer.eyes = (left+right)*0.5
	layer.mouth = lip
	var material := ShaderMaterial.new()
	material.shader = CLEAN
	material.set_shader_parameter("eye_left",left)
	material.set_shader_parameter("eye_right",right)
	material.set_shader_parameter("mouth_at",lip)
	material.set_shader_parameter("skin_at",Vector2(lip.x,lip.y-12))
	target.material = material
	target.add_child(layer)
	layer.position = target.offset-Vector2(192,192)
	# Sprite2D.flip_h 不会镜像子节点，显式同步。
	if target.flip_h:
		layer.position.x = target.offset.x+192
		layer.scale.x = -1
	return true

static func clear(target: Sprite2D) -> void:
	var old := target.get_node_or_null("CustomerExpression")
	if old != null:
		target.material = old.previous_material
		target.remove_child(old)
		old.queue_free()

func _ready() -> void:
	if features == null:
		var imported: Texture2D = load(SHEET) if ResourceLoader.exists(SHEET) else null
		var pixels := imported.get_image() if imported != null else Image.load_from_file(SHEET)
		if pixels.is_compressed(): pixels.decompress()
		pixels.generate_mipmaps()
		features = ImageTexture.create_from_image(pixels)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _draw() -> void:
	if features == null: return
	var cell := features.get_width()/4.0
	var factor := features.get_height()/720.0
	var x := emotion*cell
	draw_texture_rect_region(features,Rect2(eyes+Vector2(-43,-37),Vector2(86,22)),Rect2(x+45*factor,180*factor,450*factor,135*factor))
	# 眼睛直接沿用原角色贴图，透明层仅叠加眉毛和嘴巴。
	draw_texture_rect_region(features,Rect2(mouth+Vector2(-14,-6),Vector2(28,12)),Rect2(x+210*factor,460*factor,125*factor,85*factor))

func _process(_delta: float) -> void:
	if not is_instance_valid(actor): return
	# 动作切帧后撤掉旧坐标，避免表情粘在侧脸/身体上；调用方在新反馈姿态重新apply。
	if actor.texture != fitted_texture or actor.flip_h != fitted_flip or (actor.texture is AtlasTexture and actor.texture.region != fitted_region):
		clear(actor)
