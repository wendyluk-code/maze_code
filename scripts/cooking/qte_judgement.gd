class_name CookingQteJudgement
extends RefCounted

## 指针位置统一为 [-1, 1]；越靠近中心品质越高，边界包含在高档区域。
static func stars_for_position(position: float, perfect_width: float, good_width: float) -> int:
	var distance := absf(clampf(position, -1.0, 1.0))
	if distance <= perfect_width * 0.5:
		return 3
	if distance <= good_width * 0.5:
		return 2
	return 1

static func position_at(elapsed: float, round_duration: float) -> float:
	if round_duration <= 0.0:
		return 1.0
	var phase := fmod(maxf(elapsed, 0.0), round_duration) / round_duration
	var progress := phase * 2.0 if phase <= 0.5 else (1.0 - phase) * 2.0
	return -1.0 + 2.0 * progress
