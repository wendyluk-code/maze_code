extends SceneTree
var failures := 0
class VisibleWriter extends Control:
	func _process(_delta: float) -> void:
		show()

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var path := "res://scripts/ui/components/maze_hud_visibility.gd"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--helper="): path = arg.trim_prefix("--helper=")
	var guard = load(path).new()
	var shown := VisibleWriter.new()
	var hidden := Control.new()
	var child := Control.new()
	root.add_child(shown)
	root.add_child(hidden)
	shown.add_child(child)
	hidden.hide()
	hidden.set_process(false)
	for cycle in 3:
		guard.suppress([shown, hidden, null])
		check(not shown.visible and not hidden.visible and not child.is_visible_in_tree(), "父控件和子控件隐藏")
		guard.suppress([shown, hidden])
		for frame in 4:
			await process_frame
			check(not shown.visible and not hidden.visible, "地图期间自身逐帧重显暂停")
			check(not child.is_visible_in_tree(), "子控件保持隐藏")
		guard.restore()
		check(shown.visible and not hidden.visible and child.is_visible_in_tree(), "重复打开不覆盖原状态，关闭正确恢复")
		check(shown.is_processing() and not hidden.is_processing(), "恢复各自原处理状态")
		guard.restore()
		shown.hide()
		shown.show()
		check(shown.visible, "恢复后断开抑制回调")
	guard.suppress([shown, hidden])
	hidden.free()
	guard.restore()
	check(shown.visible, "已释放节点不阻止其余节点恢复")
	shown.free()
	print("MAP_HUD_UNIT failures=", failures)
	quit(1 if failures else 0)
