extends SceneTree

const SCRIPT_PATH := "res://scripts/maze/fenshui_guide_script.gd"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("失败：" + message)
	else:
		print("通过：" + message)

func _init() -> void:
	if not ResourceLoader.exists(SCRIPT_PATH):
		printerr("失败：已确认的分水庭引导数据尚不存在")
		quit(1)
		return
	var script: Script = load(SCRIPT_PATH)
	if script == null:
		printerr("失败：无法加载引导数据")
		quit(1)
		return
	var lines: Array = script.lines()
	var expected: Array[String] = [
		"这片水里有不少动静……都是什么？",
		"两边水域有银鳞鱼和雷鳗，中间还有一只大蛙。不想打的话，我们也可以绕过去。",
		"它们身上怎么都有一层泡泡？",
		"那是水里的保护膜，有膜的时候不容易打疼它们。可以在岸边引银鳞鱼冲上岸，泡泡就会消失啦。",
		"那雷鳗呢？",
		"雷鳗会范围放电，既能电到附近的鱼，也会电到我们。看见预警，要赶紧离开水面！",
		"它连续放电三次后会力竭，保护膜也会暂时消失，那时就是反击的好机会。",
		"中间那只大蛙看起来不太好对付……",
		"嗯，它比鱼和雷鳗难应对。不过，我觉得它的肚皮似乎是弱点。我们小心观察，说不定能找到机会！",
	]
	check(lines.size() == expected.size(), "保留确认的九句对话")
	if lines.size() == expected.size():
		for index in lines.size():
			var row: Dictionary = lines[index]
			check(row.get("text", "") == expected[index], "第%d句文案一致" % (index + 1))
			var speaker: String = "主角" if index in [0, 2, 4, 7] else "芽芽"
			check(row.get("speaker", "") == speaker, "第%d句说话人一致" % (index + 1))
			var highlights: Array = row.get("highlights", [])
			for keyword in highlights:
				check(keyword is String and not keyword.is_empty() and row.text.contains(keyword), "关键词位于原文")
		check(not str(lines[-1].text).contains("最高点") and not str(lines[-1].text).contains("回血"), "巨蛙只提示肚皮线索，不提前说明反击或回血")
		lines[0].text = "变更副本"
		check(script.lines()[0].text == expected[0], "返回副本不会改写原始对话")
	quit(1 if failures > 0 else 0)
