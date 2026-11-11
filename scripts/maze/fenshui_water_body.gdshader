shader_type canvas_item;
uniform bool flash = false;
uniform float immersion = 0.0;
uniform float foot_y = 0.0;
uniform float fade_height = 15.0;
uniform bool reflection_mode = false;
uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1715.0, 917.0);
varying vec2 world_point;
void vertex() {
 world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
 if (reflection_mode) {
  COLOR.a *= texture(water_mask, world_point / map_size).r;
 } else {
  float below = smoothstep(foot_y - 2.0, foot_y + fade_height, world_point.y);
  COLOR.rgb = mix(COLOR.rgb, vec3(.255, .643, .667), below * immersion * .48);
  COLOR.a *= 1.0 - below * immersion * .85;
 }
 if (flash) { COLOR.rgb = vec3(1.0); }
}
