shader_type canvas_item;
render_mode unshaded;

uniform sampler2D fixed_pose : source_color, filter_linear;
uniform vec2 left_eye_source = vec2(268.0, 205.0);
uniform vec2 right_eye_source = vec2(307.0, 194.0);
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 base = texture(fixed_pose, UV);
	// 每只眼睛单独定位到基准帧；不再混入偏移后的嘴部、脸缘和头发。
	vec2 pixel = UV * vec2(512.0);
	vec2 left_anchor = vec2(268.0, 205.0);
	vec2 right_anchor = vec2(307.0, 194.0);
	float left_mask = 1.0 - smoothstep(0.72, 1.0, length((pixel-left_anchor)/vec2(14.0,12.0)));
	float right_mask = 1.0 - smoothstep(0.72, 1.0, length((pixel-right_anchor)/vec2(17.0,13.0)));
	vec4 left_eye = texture(TEXTURE, (pixel-left_anchor+left_eye_source)/512.0);
	vec4 right_eye = texture(TEXTURE, (pixel-right_anchor+right_eye_source)/512.0);
	COLOR = mix(mix(base, left_eye, left_mask), right_eye, right_mask) * vertex_tint;
}
