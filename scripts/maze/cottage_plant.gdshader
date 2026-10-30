shader_type canvas_item;
render_mode unshaded;
uniform float garden_time = 0.0;
uniform float phase = 0.0;
uniform float period = 5.0;
uniform float flutter = 0.0;
varying vec4 plant_tint;
void vertex() {
	plant_tint = COLOR;
}
// 根部固定在画布0.85处；上部叶片轻摆，果实所在下部略滞后，不带动地面。
void fragment() {
	float height = clamp((0.85-UV.y)/0.85,0.0,1.0);
	float wave = sin(garden_time*6.283185/period+phase-UV.y*0.65);
	vec2 uv = UV;
	uv.x += (wave*0.008+flutter*0.009)*height*height;
	vec4 sampled = texture(TEXTURE,uv);
	COLOR = plant_tint*sampled;
}
