extends RefCounted
## 已确认的分水庭战斗引导文案；不负责触发、显示、输入或存档。

const LINES: Array = [
	{"speaker": "主角", "text": "这片水里有不少动静……都是什么？", "highlights": []},
	{"speaker": "芽芽", "text": "两边水域有银鳞鱼和雷鳗，中间还有一只大蛙。不想打的话，我们也可以绕过去。", "highlights": ["绕过去"]},
	{"speaker": "主角", "text": "它们身上怎么都有一层泡泡？", "highlights": []},
	{"speaker": "芽芽", "text": "那是水里的保护膜，有膜的时候不容易打疼它们。可以在岸边引银鳞鱼冲上岸，泡泡就会消失啦。", "highlights": ["保护膜", "冲上岸"]},
	{"speaker": "主角", "text": "那雷鳗呢？", "highlights": []},
	{"speaker": "芽芽", "text": "雷鳗会范围放电，既能电到附近的鱼，也会电到我们。看见预警，要赶紧离开水面！", "highlights": ["范围放电", "离开水面"]},
	{"speaker": "芽芽", "text": "它连续放电三次后会力竭，保护膜也会暂时消失，那时就是反击的好机会。", "highlights": ["力竭", "保护膜"]},
	{"speaker": "主角", "text": "中间那只大蛙看起来不太好对付……", "highlights": []},
	{"speaker": "芽芽", "text": "嗯，它比鱼和雷鳗难应对。不过，我觉得它的肚皮似乎是弱点。我们小心观察，说不定能找到机会！", "highlights": ["肚皮似乎是弱点"]},
]

static func lines() -> Array:
	return LINES.duplicate(true)
