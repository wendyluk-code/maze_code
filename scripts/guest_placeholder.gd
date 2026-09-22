extends Node2D
## 第一章铁山进场演出。根节点就是透明主体的脚底锚点；
## Portrait 的偏移由素材高不透明度边界校准，不参与经营状态或 NPC 逻辑。

var _base_y := 0.0
var _t := 0.0
var fade_initial_alpha := 1.0
var fade_started := false
var fade_completed := false

func _ready() -> void:
	add_to_group("guest")
	_base_y = position.y

func _process(delta: float) -> void:
	_t += delta
	# 轻微前后晃动，表现"饿得站不稳"
	position.y = _base_y + sin(_t * 2.2) * 3.0

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
