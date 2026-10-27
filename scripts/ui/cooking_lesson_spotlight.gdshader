shader_type canvas_item;
render_mode unshaded;

uniform vec2 overlay_size = vec2(1152.0, 648.0);
uniform vec2 arc_center = vec2(576.0, 150.0);
uniform vec2 arc_radius = vec2(171.0, 46.0);
uniform float clear_half_width = 20.5;
uniform float edge_softness = 3.4;

void fragment() {
	vec2 point = UV * overlay_size - arc_center;
	float half_span = max(arc_radius.x, 1.0);
	float curvature = arc_radius.y / (half_span * half_span);
	float x = clamp(point.x, -half_span, half_span);
	// 求抛物线最近点：使用真实法线距离保持等宽，端点接相同半径圆帽。
	// 不能把端点欧氏距离再除以斜率，否则会在连接处形成凸包。
	for (int iteration = 0; iteration < 5; iteration++) {
		float y = curvature * x * x;
		float slope = 2.0 * curvature * x;
		float gradient = x - point.x + (y - point.y) * slope;
		float derivative = 1.0 + slope * slope + (y - point.y) * 2.0 * curvature;
		x = clamp(x - gradient / max(derivative, 0.1), -half_span, half_span);
	}
	float distance_to_band = length(point - vec2(x, curvature * x * x));
	COLOR.a *= smoothstep(clear_half_width, clear_half_width + edge_softness, distance_to_band);
}
