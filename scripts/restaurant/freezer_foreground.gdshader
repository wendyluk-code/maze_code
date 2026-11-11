shader_type canvas_item;
uniform bool tray_visible = false;
uniform int point_count = 0;
uniform vec2 tray_points[64];
varying vec2 foreground_position;

void vertex() {
	foreground_position = VERTEX;
}

void fragment() {
	// 仅挖去新凹槽覆盖区域；其余柜身仍按原深度规则遮挡人物。
	bool inside = false;
	if (tray_visible && point_count >= 3) {
		int previous = point_count - 1;
		for (int index = 0; index < point_count; index++) {
			vec2 a = tray_points[index];
			vec2 b = tray_points[previous];
			if ((a.y > foreground_position.y) != (b.y > foreground_position.y)) {
				float crossing = (b.x-a.x) * (foreground_position.y-a.y) / (b.y-a.y) + a.x;
				if (foreground_position.x < crossing) { inside = !inside; }
			}
			previous = index;
		}
	}
	if (inside) { COLOR.a = 0.0; }
}
