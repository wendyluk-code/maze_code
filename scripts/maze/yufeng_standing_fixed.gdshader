shader_type canvas_item;
render_mode unshaded;
uniform sampler2D fixed_pose : source_color, filter_nearest;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 base = texture(fixed_pose, UV);
	vec4 moving = texture(TEXTURE, UV);
	// 地图以下沿用基准帧，确保靴底和持图动作不会漂移。
	float mask = 1.0 - smoothstep(0.44, 0.49, UV.y);
	vec4 pixel = mix(base, moving, mask);
	pixel.a = step(0.5, pixel.a);
	COLOR = pixel * vertex_tint;
}
