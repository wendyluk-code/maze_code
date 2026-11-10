extends "res://tools/tests/fenshui_frog_depth.gd"

func depth_resolution() -> Vector2i:
 return Vector2i(1280,720) if _arg("--phase=")=="wide" else Vector2i(1152,648)

func prepare_frog(frog: Node2D) -> void:
 _check(frog.enable_frog_front24(),"深度验收启用相同双前向1.4倍候选")
