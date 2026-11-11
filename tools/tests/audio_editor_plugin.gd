extends SceneTree
## 在实际编辑器主循环中验证插件注册、显示和渲染。
var attempts := 0
func _initialize() -> void:
	_verify.call_deferred()

func _find_script(node: Node, path: String) -> Node:
	var script: Script = node.get_script()
	if script != null and script.resource_path == path: return node
	for child in node.get_children():
		var found := _find_script(child, path)
		if found != null: return found
	return null

func _verify() -> void:
	await create_timer(2.0).timeout
	var plugin := _find_script(root, "res://addons/audio_mixer/plugin.gd")
	if plugin == null:
		attempts += 1
		if attempts < 30:
			_verify.call_deferred()
			return
		print("AUDIO_PLUGIN: FAIL plugin not registered")
		quit(1)
		return
	plugin._show_panel()
	await process_frame
	await process_frame
	var panel: Control = plugin.panel
	var passed: bool = panel.is_visible_in_tree() and panel.tree.get_root().get_child_count() == 53
	if "--live-check" in OS.get_cmdline_user_args():
		passed = await _live_check(panel) and passed
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://output/audio_editor/editor_panel.png")
	print("AUDIO_PLUGIN: ", "PASS" if passed else "FAIL", " visible=", panel.is_visible_in_tree(), " rows=", panel.tree.get_root().get_child_count())
	quit(0 if passed else 1)

func _live_check(panel: Control) -> bool:
	var mix_class = preload("res://scripts/audio/audio_mix.gd")
	var path := "res://output/audio_editor/editor_live"
	panel.mix.save_path = path+"/mix.json"
	panel.mix.preview_path = path+"/preview.json"
	mix_class.write_json(panel.mix.save_path, {"version":1, "cues":{}, "groups":{}})
	# 显式失效上次结果，避免把历史文件当成本轮完成。
	mix_class.write_json(path+"/ready.json", {"ready":false})
	mix_class.write_json(path+"/result.json", {"passed":false})
	panel.discard_changes()
	panel.selected_id = "music_start"
	panel._rebuild_list()
	var pid := OS.create_process(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"), "--rendering-method", "gl_compatibility", "--resolution", "960x540", "--log-file", ProjectSettings.globalize_path(path+"/game.log"), "res://tools/tests/audio_editor_live_game.tscn"])
	if pid < 0: return false
	for i in 100:
		await create_timer(0.1).timeout
		var ready: Variant = mix_class.parse_json(FileAccess.get_file_as_string(path+"/ready.json"))
		if ready is Dictionary and ready.get("ready", false): break
	panel.volume_number.value = -27.0
	for i in 120:
		await create_timer(0.1).timeout
		if not OS.is_process_running(pid): break
	if OS.is_process_running(pid):
		OS.kill(pid)
		return false
	var result: Variant = mix_class.parse_json(FileAccess.get_file_as_string(path+"/result.json"))
	print("AUDIO_EDITOR_LIVE: ", result)
	panel.discard_changes()
	return result is Dictionary and result.get("passed", false)
