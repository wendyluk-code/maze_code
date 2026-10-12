extends Control
## 小地图和展开地图共用的绘制层；只显示调用方提供的位置、朝向和资源。
const MapProjection := preload("res://data/maze/entry_map_projection.gd")
const MAP := preload("res://assets/maps/shallow_floor.png")
const MAP_NO_LABELS := preload("res://assets/ui/maze_map/shallow_floor_no_labels.png")
const FOG := preload("res://scripts/ui/shallow_map_fog.gdshader")
const CHEST := preload("res://assets/ui/maze_map/chest_gold.png")
const DIRECTION := preload("res://assets/ui/maze_map/player_direction.png")
const LOCAL_RADIUS := 145.0
static var _direction_texture: ImageTexture
var atlas_position := Vector2.ZERO
var facing := Vector2.DOWN
var resources: Array[Dictionary] = []
var unlocked := false
var compact := false
var _image: TextureRect
var _markers: Control
var _chests: Control
var _fog: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image = TextureRect.new()
	_image.texture = MAP
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog = ShaderMaterial.new()
	_fog.shader = FOG
	_fog.set_shader_parameter("exploration_view", true)
	_fog.set_shader_parameter("road_reveal", MapProjection.road_texture())
	_fog.set_shader_parameter("circular_view", compact)
	_fog.set_shader_parameter("label_free_map", MAP_NO_LABELS)
	# 两种尺寸复用同一份源纹理的 mipmap，不逐帧生成图片。
	var obscured := (MAP_NO_LABELS if compact else MAP).get_image()
	obscured.generate_mipmaps()
	_fog.set_shader_parameter("obscured_map", ImageTexture.create_from_image(obscured))
	_image.material = _fog
	_chests = Control.new()
	_chests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chests)
	var flat := ShaderMaterial.new()
	flat.shader = preload("res://scripts/ui/components/maze_map_icon.gdshader")
	_chests.material = flat
	_chests.draw.connect(_draw_chests)
	_markers = Control.new()
	if _direction_texture == null:
		var arrow := DIRECTION.get_image()
		arrow.generate_mipmaps()
		_direction_texture = ImageTexture.create_from_image(arrow)
	_markers.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers)
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_markers.draw.connect(_draw_markers)
	resized.connect(func(): _markers.queue_redraw(); _chests.queue_redraw())

func sync(point: Vector2, direction: Vector2, markers: Array[Dictionary], is_unlocked: bool) -> void:
	atlas_position = point
	facing = direction
	resources = markers
	unlocked = is_unlocked
	_fog.set_shader_parameter("map_unlocked", unlocked)
	if compact:
		var origin := (atlas_position - Vector2.ONE * LOCAL_RADIUS) / MapProjection.SIZE
		var extent := Vector2.ONE * LOCAL_RADIUS * 2.0 / MapProjection.SIZE
		_fog.set_shader_parameter("view_region", Vector4(origin.x,origin.y,extent.x,extent.y))
	_chests.queue_redraw()
	_markers.queue_redraw()

func marker_position() -> Vector2:
	return to_view(atlas_position)

func to_view(point: Vector2) -> Vector2:
	if compact:
		return size * 0.5 + (point - atlas_position) * size / (LOCAL_RADIUS * 2.0)
	return point / MapProjection.SIZE * size

func _draw_chests() -> void:
	for resource in resources:
		if resource.kind != "chest" or not unlocked:
			continue
		var point := to_view(resource.position)
		var edge := 14.0 if compact else 22.0
		# 整枚图标留在圆内，避免贴边资源溢出到游戏画面。
		if compact and point.distance_to(size * 0.5) > size.x * 0.48 - edge * 0.5:
			continue
		_chests.draw_texture_rect(CHEST, Rect2(point - Vector2.ONE * edge * 0.5,Vector2.ONE * edge), false)

func _draw_markers() -> void:
	var center := marker_position()
	# 源图含透明留白，实际箭头约占六成；保留手绘分面、米白边与短投影。
	var edge := 23.0 if compact else 48.0
	# 源图尖端朝上，Godot角度零点朝右，因此补偿四分之一圈。
	_markers.draw_set_transform(center, facing.angle() + PI * 0.5)
	_markers.draw_texture_rect(_direction_texture, Rect2(Vector2.ONE * -edge * 0.5,Vector2.ONE * edge),false)
	_markers.draw_set_transform(Vector2.ZERO)

