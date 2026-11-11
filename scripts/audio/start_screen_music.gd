extends AudioStreamPlayer
## 开始界面专属音乐；场景退出时停止，避免与游戏音乐叠播。
func _ready() -> void:
	GameAudio.bind_volume(self, &"music_start")
	stream.loop = true
	play()

func _exit_tree() -> void:
	stop()
