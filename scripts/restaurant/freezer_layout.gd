extends Node2D
# 编辑器显示辅助面，运行时由交互视图绘制轮廓。
func _ready() -> void:
	visible = SaveManager.freezer_unlocked()
	for index in range(1,4):
		get_node("Slot%d/Selection" % index).hide()
