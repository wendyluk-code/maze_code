extends "res://tools/tests/ch2_guide_01_ch1.gd"

func _cleanup() -> void:
	await super._cleanup()
	await preload("res://tools/tests/restaurant_audio_cleanup.gd").finish(get_tree())
