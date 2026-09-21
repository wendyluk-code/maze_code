extends Node2D
## 第一章铁山进场演出。根节点就是透明主体的脚底锚点；
## Portrait 的偏移由素材高不透明度边界校准，不参与经营状态或 NPC 逻辑。

var _base_y := 0.0
var _t := 0.0

func _ready() -> void:
	add_to_group("guest")
	_base_y = position.y

func _process(delta: float) -> void:
	_t += delta
	# 轻微前后晃动，表现"饿得站不稳"
	position.y = _base_y + sin(_t * 2.2) * 3.0
