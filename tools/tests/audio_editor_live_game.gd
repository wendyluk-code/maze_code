extends Node
## 独立游戏进程：观察编辑器面板的真实文件同步。
const Mix = preload("res://scripts/audio/audio_mix.gd")
const TEST_ROOT := "res://output/audio_editor/editor_live"
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	GameAudio.mix.save_path = TEST_ROOT+"/mix.json"
	GameAudio.mix.preview_path = TEST_ROOT+"/preview.json"
	GameAudio.mix.load_saved()
	GameAudio.mix.refresh()
	var start: Control = load("res://scenes/start_screen.tscn").instantiate()
	get_tree().root.add_child(start)
	get_tree().current_scene = start
	Mix.write_json(TEST_ROOT+"/ready.json", {"ready":true})
	var passed := false
	for i in 100:
		await get_tree().create_timer(0.1).timeout
		if is_equal_approx(start.get_node("StartScreenBGM").volume_db, -27):
			passed = start.get_node("StartScreenBGM").playing
			break
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TEST_ROOT+"/game.png")
	Mix.write_json(TEST_ROOT+"/result.json", {"passed":passed, "volume_db":start.get_node("StartScreenBGM").volume_db, "playing":start.get_node("StartScreenBGM").playing, "preview":GameAudio.mix.preview_active})
	start.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if passed else 1)
