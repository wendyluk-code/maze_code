@tool
extends Polygon2D
## 仅编辑器显示的遮挡判定轮廓，不参与物理碰撞。
func _ready() -> void:
	visible = Engine.is_editor_hint()
