extends RefCounted
## 仅观察最终位移，不修改移动或体力；步距按各地图的基础速度归一化。
var _stride := 0.0
var _moving := false
var _sprinting := false
var _variant := 0

func reset() -> void:
	_stride = 0.0
	_moving = false
	_sprinting = false

func update(audio: Node, distance: float, base_speed: float, sprinting: bool) -> void:
	if distance <= 0.01:
		reset()
		return
	if sprinting and not _sprinting:
		audio.play_cue(&"sprint_start")
	_sprinting = sprinting
	_stride += distance / base_speed
	if not _moving or _stride >= 0.38:
		audio.play_cue(StringName("footstep_%02d" % (_variant + 1)))
		_variant = (_variant + 1) % 4
		_stride = fmod(_stride, 0.38) if _moving else 0.0
	_moving = true
