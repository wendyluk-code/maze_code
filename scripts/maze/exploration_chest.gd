extends Node2D
## 无碰撞的路边探索物件；场景统一仲裁最近目标和奖励事务。
const Prompt := preload("res://scripts/ui/components/chest_interact_prompt.gd")
const FRAMES := preload("res://assets/props/treasure_chest/sparkle_frames.tres")
var chest_id := ""
var sprite: AnimatedSprite2D
var prompt: Sprite2D

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.centered = false
	sprite.position = Vector2(-20.25, -32)
	sprite.scale = Vector2.ONE * 0.25
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.play("sparkle")
	prompt = Prompt.new()
	add_child(prompt)

func set_targeted(targeted: bool) -> void:
	prompt.visible = targeted and visible
