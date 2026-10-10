shader_type canvas_item;

uniform sampler2D world_occlusion : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1448.0, 1086.0);

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 map_uv = world_position / map_size;
	if (map_uv.x >= 0.0 && map_uv.x <= 1.0 && map_uv.y >= 0.0 && map_uv.y <= 1.0) {
		COLOR.a *= 1.0 - texture(world_occlusion, map_uv).a;
	}
}
