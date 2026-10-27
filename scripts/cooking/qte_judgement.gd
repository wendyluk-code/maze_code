class_name CookingQteJudgement
extends RefCounted

## 指针位置统一为 [-1, 1]；越靠近中心品质越高，边界包含在高档区域。
static func stars_for_position(position: float, perfect_width: float, good_width: float, center: float = 0.0) -> int:
	var distance := absf(clampf(position, -1.0, 1.0) - center)
	if distance <= perfect_width * 0.5:
		return 3
	if distance <= good_width * 0.5:
		return 2
	return 1

static func random_zones() -> Dictionary:
	# 保留两端红区；绿色始终包含在黄色范围内。
	var perfect := randf_range(0.12, 0.24)
	var good := randf_range(0.60, 1.00)
	var limit := 1.0 - good * 0.5 - 0.08
	return {"perfect": perfect, "good": good, "center": randf_range(-limit, limit)}

static func position_at(elapsed: float, round_duration: float) -> float:
	if round_duration <= 0.0:
		return 1.0
	var phase := fmod(maxf(elapsed, 0.0), round_duration) / round_duration
	var progress := phase * 2.0 if phase <= 0.5 else (1.0 - phase) * 2.0
	return -1.0 + 2.0 * progress
