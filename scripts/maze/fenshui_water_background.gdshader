shader_type canvas_item;
uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform float clock = 0.0;
uniform bool enabled = true;
void fragment() {
 if (enabled) {
  vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
  float wet = texture(water_mask, UV).r;
  float shift = sin(pixel.y * .045 + clock * 1.4) * 1.7 + sin(pixel.y * .018 - clock * .9) * 1.1;
  vec2 shifted = UV + vec2(shift, 0.0) * TEXTURE_PIXEL_SIZE;
  float inside = min(wet, texture(water_mask, shifted).r);
  vec4 moving = texture(TEXTURE, shifted);
  COLOR = mix(COLOR, moving, inside);
  float wave = sin(pixel.x * .055 + pixel.y * .032 + clock * .8) + sin(pixel.y * .065 - pixel.x * .025 - clock * .65);
  float light = max(0.0, wave - 1.2) * .08;
  vec2 step_uv = TEXTURE_PIXEL_SIZE * 6.0;
  float shore = 1.0 - min(min(texture(water_mask, UV + vec2(step_uv.x, 0.0)).r, texture(water_mask, UV - vec2(step_uv.x, 0.0)).r), min(texture(water_mask, UV + vec2(0.0, step_uv.y)).r, texture(water_mask, UV - vec2(0.0, step_uv.y)).r));
  float pulse = .5 + .5 * sin(clock * 1.7 + pixel.x * .09 + pixel.y * .03);
  float glint = (light + shore * pulse * .10) * wet;
  COLOR.rgb = mix(COLOR.rgb, vec3(.89, 1.0, .95), glint);
 }
}
