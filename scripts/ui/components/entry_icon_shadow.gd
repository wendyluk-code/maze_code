extends RefCounted
## 常驻入口共用居中淡投影，不参与鼠标命中。
static func attach(button: Button, node_name: String) -> void:
	var shadow := Panel.new()
	shadow.name = node_name
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.show_behind_parent = true
	button.add_child(shadow)
	shadow.position = Vector2(8,8)
	shadow.size = Vector2(48,48)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20,0.16,0.10,0.10)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0.20,0.16,0.10,0.18)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0,2)
	shadow.add_theme_stylebox_override("panel",style)
