shader_type canvas_item;
uniform vec2 eye_left = vec2(164.0,160.0);
uniform vec2 eye_right = vec2(216.0,160.0);
uniform vec2 mouth_at = vec2(190.0,183.0);
uniform vec2 skin_at = vec2(190.0,170.0);
varying vec4 tint;
void vertex() { tint = COLOR; }
float patch(vec2 p, vec2 center, vec2 radius) {
	return 1.0-smoothstep(0.75,1.0,length((p-center)/radius));
}
void fragment() {
	vec4 base = texture(TEXTURE,UV);
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	vec2 origin = floor(pixel / 384.0)*384.0;
	vec2 p = pixel-origin;
	vec4 skin = texture(TEXTURE,(origin+skin_at)*TEXTURE_PIXEL_SIZE);
	float mask = 0.0; // 保留原始眼睛及瞳孔，不重绘。
	mask = max(mask,patch(p,eye_right+vec2(0.0,-30.0),vec2(16.0,8.0)));
	mask = max(mask,patch(p,mouth_at,vec2(17.0,9.0)));
	COLOR = vec4(mix(base.rgb,skin.rgb,mask),base.a)*tint;
}
