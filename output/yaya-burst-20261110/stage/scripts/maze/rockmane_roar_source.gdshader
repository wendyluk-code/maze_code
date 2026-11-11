shader_type canvas_item;
render_mode unshaded;
uniform float release_progress : hint_range(0.0, 1.0) = 0.0;
void fragment() {
 vec4 source = texture(TEXTURE, UV);
 vec2 from_mouth = (UV * 1254.0 - vec2(158.0, 674.0)) / 1000.0;
 float distance_from_mouth = length(from_mouth);
 float front = release_progress * 2.0;
 float reveal = 1.0 - smoothstep(front - 0.14, front + 0.10, distance_from_mouth);
 float life = smoothstep(0.0, 0.10, release_progress) * (1.0 - smoothstep(0.62, 1.0, release_progress));
 COLOR = vec4(source.rgb, source.a * reveal * life * 0.88);
}
