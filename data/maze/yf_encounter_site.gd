extends RefCounted
## 红框指定的东侧入水前窄路；角色脚底与剧情触发共用此配置。
const CHAT_FOOT := Vector2(1450,282)
const POSITIONS := {"yufeng":Vector2(1419,282),"salia":Vector2(1480,282)}
const ENTRY_LINE_X := 1518.0

static func should_trigger(point: Vector2) -> bool:
	# 横跨入口通道，不依赖玩家是否走进角色身边的小圆圈。
	# 已绕到西侧的旧档也在下次进入场景时接续首次剧情。
	return point.x <= ENTRY_LINE_X

static func protected(point: Vector2, margin: float = 0.0) -> bool:
	return point.distance_to(CHAT_FOOT)<190.0+margin
