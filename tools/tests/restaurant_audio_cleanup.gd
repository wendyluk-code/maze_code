extends RefCounted
## 仅验收退出：主区可能加载GameAudio，最后一次E音效需停止后再quit。
static func finish(tree: SceneTree) -> void:
	var audio := tree.root.get_node_or_null("GameAudio")
	if is_instance_valid(audio):
		for node in audio.find_children("*","",true,false):
			if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D: node.stop()
	await tree.process_frame
	await tree.process_frame
	await tree.create_timer(0.2).timeout
