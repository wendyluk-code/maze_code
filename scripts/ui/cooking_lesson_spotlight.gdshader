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
	float x = clamp(point.x, -half_span, half_span);
	float progress = x / half_span;
	vec2 centerline = vec2(x, arc_radius.y * progress * progress);
	float slope = 2.0 * arc_radius.y * progress / half_span;
	// 沿实际抛物线色带挖空，两端保留圆润余量，完整露出红黄绿区和指针。
	float distance_to_band = length(point - centerline) / sqrt(1.0 + slope * slope);
	COLOR.a *= smoothstep(clear_half_width, clear_half_width + edge_softness, distance_to_band);
}
