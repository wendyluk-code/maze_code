extends AudioStreamPlayer
## 保留场景节点兼容旧引用；实际餐厅BGM由GameAudio跨场景持有。
func _ready() -> void:
	stop()

func _exit_tree() -> void:
	stop()
