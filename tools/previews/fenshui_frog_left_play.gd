extends "res://tools/previews/fenshui_frog_play.gd"
## 只换原巨蛙的完整候选图，仍由正常七怪地图消费真实战斗状态。
const Boss=preload("res://data/maze/fenshui_boss.gd")

func _prepare_frog() -> bool:
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 var run: Dictionary=Run.snapshot(sm)
 frog.sync_action(run.combat.actors[Boss.ID],run.combat)
 return frog.set_frog_motion_direction(1)

func _play_message() -> String:
 return "分水庭实际战斗 · 左前18姿态候选\n本入口固定左前，尚未自动四向。\n腾空命中可反击，露腹3秒、伤害2倍。\n吐水新动作未齐；击败／捕获暂沿原图。"

func _play_title() -> String:
 return "料理迷宫 · 分水庭实际战斗（左前18姿态候选·20261102）"
