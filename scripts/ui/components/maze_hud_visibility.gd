extends RefCounted
## 地图临时隐藏指定控件；保留原显隐和控件自身的处理开关。
var _saved: Array[Dictionary] = []

func suppress(nodes: Array) -> void:
	if not _saved.is_empty():
		return
	for node in nodes:
		if not is_instance_valid(node) or not node is CanvasItem:
			continue
		_saved.append({"node": node, "visible": node.visible, "processing": node.is_processing()})
		# 体力控件会在自身 _process 中重新显示；暂停该显示刷新即可。
		# 战斗流程在地图展开时只会隐藏技能栏，不需要暂停业务节点。
		node.set_process(false)
		node.hide()

func restore() -> void:
	for entry in _saved:
		if is_instance_valid(entry.node):
			entry.node.visible = entry.visible
			entry.node.set_process(entry.processing)
	_saved.clear()
