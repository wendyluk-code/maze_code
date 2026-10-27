shader_type canvas_item;
uniform bool flash = false;
void fragment() {
	// CanvasItem片元的COLOR已包含纹理与节点调制，不能再次乘纹理。
	if (flash) {
		COLOR.rgb = vec3(1.0);
	}
}
