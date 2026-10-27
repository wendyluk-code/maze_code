shader_type canvas_item;
render_mode unshaded;

uniform vec2 overlay_size = vec2(1152.0, 648.0);
uniform bool circle_cutouts = false;
uniform vec4 ingredients_rect = vec4(0.0);
uniform vec4 cooking_rect = vec4(0.0);

float outside_task(vec2 point, vec4 rect) {
	if (rect.z <= 0.0 || rect.w <= 0.0) { return 1.0; }
	vec2 half_size = rect.zw * 0.5;
	if (circle_cutouts) { return smoothstep(0.0, 2.0, length(point - rect.xy - half_size) - min(half_size.x, half_size.y)); }
	vec2 relative = abs(point - rect.xy - half_size) - half_size + vec2(8.0);
	float distance = length(max(relative, vec2(0.0))) + min(max(relative.x, relative.y), 0.0) - 8.0;
	return smoothstep(0.0, 2.0, distance);
}

void fragment() {
	vec2 point = UV * overlay_size;
	COLOR.a *= outside_task(point, ingredients_rect) * outside_task(point, cooking_rect);
}
