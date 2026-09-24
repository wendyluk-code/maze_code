extends Node2D
## 第一章铁山进场演出。根节点固定在地面，动作只切换等比例、同锚点帧。
## SpriteFrames（精灵帧资源）负责姿势和节奏，不参与经营状态。
var collapse_completed := false
var collapse_started := false
var fade_initial_alpha := 1.0
var fade_started := false
var fade_completed := false

func _ready() -> void:
	add_to_group("guest")
	$Portrait.animation_finished.connect(_on_animation_finished)

func play_collapse() -> void:
	collapse_started = true
	collapse_completed = false
	$Portrait.play("collapse")

func settle_prone() -> void:
	$Portrait.stop()
	$Portrait.animation = "collapse"
	$Portrait.frame = 7
	collapse_completed = true

func _on_animation_finished() -> void:
	collapse_completed = true

func prepare_fade_in() -> void:
	fade_initial_alpha = 0.0
	fade_started = false
	fade_completed = false
	modulate.a = 0.0

func mark_fade_started() -> void:
	fade_started = true

func mark_fade_completed() -> void:
	modulate.a = 1.0
	fade_completed = true
