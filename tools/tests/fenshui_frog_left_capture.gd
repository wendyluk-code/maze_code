extends "res://tools/tests/fenshui_frog_capture.gd"
## 捕获规则保持原入口；只在真实巨蛙节点启用左前候选。

func battle() -> void:
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(frog.set_frog_motion_direction(1),"左前候选从正常战斗进入击败／捕获")
 await super.battle()

func picture(label: String) -> void:
 await super.picture(label)
 var frog: Node2D=maze.capture_flow.monsters[Boss.ID]
 _check(frog.body.texture==frog.action_sheets.defeated,"未提供新击败图时沿用既有结果，未冒充左前新动作")
