extends "res://tools/tests/tutorial_checkpoint_flow.gd"
func _open_scene() -> void:
	await super._open_scene()
	var foreground = scene.get_node_or_null("PropForeground")
	if foreground != null:
		foreground.set_process(false)
		for layer in foreground.get_children():
			layer.material = null
