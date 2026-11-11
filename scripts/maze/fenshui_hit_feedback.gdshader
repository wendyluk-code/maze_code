shader_type canvas_item;
uniform bool flash = false;
uniform vec2 impact_scale = vec2(1.0);
uniform float impact_angle = 0.0;
void vertex() {
 vec2 p = VERTEX * impact_scale;
 float c = cos(impact_angle);
 float s = sin(impact_angle);
 VERTEX = vec2(c*p.x-s*p.y,s*p.x+c*p.y);
}
void fragment() {
 if (flash) { COLOR.rgb = vec3(1.0); }
}
