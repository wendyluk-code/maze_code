extends "res://tools/previews/fenshui_frog_motion.gd"

func _make_controls() -> Node:
 return preload("res://tools/previews/fenshui_frog_direction_controls.gd").new()

func _window_title() -> String:
 return "料理迷宫 · 巨蛙三向关键姿态核对（非完整战斗动画）"
