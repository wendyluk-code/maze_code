shader_type canvas_item;
render_mode unshaded;
uniform sampler2D edge_mask : filter_linear, repeat_disable;
uniform vec2 area_origin;
uniform float area_span = 1.0;
uniform bool edge_enabled = false;
varying vec2 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
 vec4 pixel = texture(TEXTURE, UV) * COLOR;
 if (edge_enabled) {
  vec2 mask_uv = (world_position - area_origin) / area_span;
  float inside = step(0.0, mask_uv.x) * step(0.0, mask_uv.y) * step(mask_uv.x, 1.0) * step(mask_uv.y, 1.0);
  pixel.a *= texture(edge_mask, mask_uv).r * inside;
 }
 COLOR = pixel;
}
