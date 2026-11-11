extends Node2D
## 在子节点初始化之前选择章节布局，普通营业不能覆盖首章前台和座位。
func _enter_tree() -> void:
	get_node("SixSeatBarArt").hide()
	get_node("TieshanSeatAnchor").position = Vector2(471,251)
	var bar := get_node("InteractPoints/BarCounter")
	bar.interaction_polygon = PackedVector2Array([Vector2(-235,-17),Vector2(-186,-29),Vector2(310,-74),Vector2(352,-56),Vector2(352,60),Vector2(314,83),Vector2(-201,142),Vector2(-227,116)])
	bar.foreground_polygon = PackedVector2Array([Vector2(-230,2),Vector2(-186,-5),Vector2(310,-50),Vector2(352,-35),Vector2(352,60),Vector2(314,83),Vector2(-201,142),Vector2(-227,116)])
	bar.occlusion_polygon = PackedVector2Array([Vector2(-232,-92),Vector2(305,-104),Vector2(352,-60),Vector2(352,-10),Vector2(300,20),Vector2(266,40),Vector2(-180,70),Vector2(-230,45)])
	# 遮挡判定优先使用场景中手调的 OcclusionOutline，不覆盖编辑器保存的顶点。
	bar.remove_meta("foreground_texture")
	get_node("InteractPoints/Register").remove_meta("foreground_disabled")
