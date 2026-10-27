shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
void fragment() {
    vec4 ink = texture(TEXTURE, UV);
    float inside = step(0.0, UV.x) * step(UV.x, 1.0) * step(0.0, UV.y) * step(UV.y, 1.0);
    float radius = length((UV - vec2(0.5)) * vec2(0.65, 1.0));
    float spread = 1.0 - smoothstep(reveal * 0.75 - 0.12, reveal * 0.75, radius);
    COLOR = ink * vec4(1.0, 1.0, 1.0, inside * spread);
}
