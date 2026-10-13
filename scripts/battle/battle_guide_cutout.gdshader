shader_type canvas_item;
uniform vec4 holes[8];
uniform int hole_count = 0;
uniform float darkness = 0.48;
void fragment() {
	vec2 p = UV * vec2(1280.0, 720.0);
	float mask = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i >= hole_count) break;
		vec4 r = holes[i];
		vec2 d = abs(p - (r.xy + r.zw * 0.5)) - r.zw * 0.5;
		float edge = max(d.x, d.y);
		mask *= smoothstep(-1.0, 2.0, edge);
	}
	COLOR = vec4(0.06, 0.12, 0.12, darkness * mask);
}
