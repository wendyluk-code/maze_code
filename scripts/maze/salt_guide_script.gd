extends RefCounted
## 文案只描述当前盐池真实生效的战斗规则。

const LINES: Array = [
	{"speaker":"主角","text":"前面就是盐池，听说有岩鬃兽出没。","highlights":[]},
	{"speaker":"芽芽","text":"看到它蓄力，快从冲撞方向侧面躲开！","highlights":["蓄力","侧面躲开"]},
	{"speaker":"芽芽","text":"引它正面高速撞上水晶或树丛，可能把它撞晕；擦边不一定有效。","highlights":["正面高速","水晶或树丛","撞晕"]},
	{"speaker":"芽芽","text":"水池挡不住它，别把水面当作安全屏障。","highlights":["水池挡不住它"]},
	{"speaker":"芽芽","text":"咆哮前会有扇形预警，快离开范围；被命中会大幅减速。","highlights":["扇形预警","大幅减速"]},
	{"speaker":"芽芽","text":"咆哮命中后它会接四连冲撞，继续观察方向并躲开。","highlights":["四连冲撞"]},
	{"speaker":"芽芽","text":"四连结束后的力竭，或它撞晕时，都是反击机会！","highlights":["力竭","撞晕","反击"]},
	{"speaker":"芽芽","text":"被撞飞后如果撞上水晶、树丛或边界，会眩晕两秒。","highlights":["撞飞","眩晕两秒"]},
]

static func lines() -> Array:
	return LINES.duplicate(true)
