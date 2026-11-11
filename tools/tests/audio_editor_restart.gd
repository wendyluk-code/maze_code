extends Node
func _ready() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mix-file="): path = arg.trim_prefix("--mix-file=")
	GameAudio.mix.save_path = path
	GameAudio.mix.allow_preview = false
	GameAudio.mix.load_saved()
	GameAudio.mix.refresh()
	var passed: bool = is_equal_approx(GameAudio._players[&"order_accepted"].volume_db, -25)
	print("AUDIO_RESTART: ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)
