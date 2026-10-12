shader_type canvas_item;
render_mode unshaded;
void fragment() {
	// 使用用户确认的生成轮廓，统一纯色，保留透明缝隙与抗锯齿。
	COLOR = vec4(vec3(0.914,0.769,0.416),texture(TEXTURE,UV).a);
}
