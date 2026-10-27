extends Node2D
## 与宝箱共用提示；不独立处理输入或发奖，由地图仲裁。
const Prompt := preload("res://scripts/ui/components/chest_interact_prompt.gd")
const FRAMES := preload("res://assets/props/dig_site/twinkle_frames.tres")
const WOOD_ICON := preload("res://generated_assets/wood_logs_pixel_256.png")
var site_id := ""
var sprite: AnimatedSprite2D
var prompt: Sprite2D

func _ready() -> void:
	var config: Dictionary=preload("res://data/maze/region_resources.gd").find(site_id)
	var is_plant: bool=not config.is_empty() and config.item!="wood"
	if is_plant:
		var plant:=Sprite2D.new()
		plant.texture=load("res://assets/props/region_resources/"+config.item+".png")
		plant.scale=Vector2.ONE*48.0/plant.texture.get_width()
		plant.position.y=-15
		add_child(plant)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	if is_plant: sprite.sprite_frames=load("res://assets/props/region_resources/sparkles.tres")
	sprite.scale = Vector2.ONE * 0.18
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play("sparkle")

	prompt = Prompt.new()
	prompt.z_index = 10
	add_child(prompt)

func set_targeted(targeted: bool) -> void:
	prompt.visible = targeted and visible

static func wood_texture() -> Texture2D:
	var icon := AtlasTexture.new()
	icon.atlas = WOOD_ICON
	icon.region = Rect2(12, 40, 233, 198)
	return icon
