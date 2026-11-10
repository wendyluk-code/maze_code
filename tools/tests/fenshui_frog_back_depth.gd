extends "res://tools/tests/fenshui_frog_left_depth.gd"

func depth_resolution() -> Vector2i:
 return Vector2i(1280,720) if _arg("--phase=").ends_with("wide") else Vector2i(1152,648)

func prepare_frog(frog: Node2D) -> void:
 var direction:=3 if _arg("--phase=").begins_with("left") else 2
 _check(frog.set_frog_motion_direction(direction),"真实节点启用背向完整链及旧待机衔接")
