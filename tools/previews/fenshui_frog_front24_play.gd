extends "res://tools/previews/fenshui_frog_play.gd"

func _prepare_frog() -> bool:
 return maze.capture_flow.monsters["fenshui_wind_frog_1"].enable_frog_front24()

func _play_message() -> String:
 return "分水庭 · 双前向24姿态候选 · 体型1.4倍\n新图覆盖起落、吐水、反击、起身与两类击败。\n暂仅右前／左前，无背向新图；朝上也只显示对应前向候选。\n正常4鱼2鳗1蛙；腾空命中可打断，露腹3秒伤害2倍。\n这是实战候选，不是动作循环演示；独立体验档。"

func _play_title() -> String:
 return "料理迷宫 · 分水庭双前向24姿态 · 1.4倍实战候选 · 20261102"
