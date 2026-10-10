shader_type canvas_item;
render_mode unshaded;
uniform sampler2D obscured_map : filter_linear_mipmap, repeat_disable;
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

// Source-map coordinates keep the revealed route aligned at every window size.
float ellipse_distance(vec2 p, vec2 center, vec2 radius) {
	return (length((p - center) / radius) - 1.0) * min(radius.x, radius.y);
}

float path_distance(vec2 p, vec2 a, vec2 b, float width) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0)) - width;
}

// Continuous low-frequency shadows avoid precision-sensitive tiled hash noise.
float cloud_shadow(vec2 p, float t) {
	return 0.5 + 0.22 * sin(p.x * 2.1 + sin(p.y * 1.7 - t) + t * 0.6)
		+ 0.16 * cos(p.y * 2.8 + sin(p.x * 1.3 + t * 0.5))
		+ 0.10 * sin(p.x * 4.3 - p.y * 3.1 - t * 0.7);
}

float hidden_label(vec2 p) {
	float d = ellipse_distance(p, vec2(218.0, 157.0), vec2(99.0, 30.0));
	d = min(d, ellipse_distance(p, vec2(444.0, 188.0), vec2(88.0, 31.0)));
	d = min(d, ellipse_distance(p, vec2(283.0, 398.0), vec2(83.0, 30.0)));
	d = min(d, ellipse_distance(p, vec2(275.0, 641.0), vec2(85.0, 30.0)));
	d = min(d, ellipse_distance(p, vec2(842.0, 775.0), vec2(83.0, 30.0)));
	d = min(d, ellipse_distance(p, vec2(1386.0, 723.0), vec2(84.0, 30.0)));
	d = min(d, ellipse_distance(p, vec2(1460.0, 415.0), vec2(89.0, 31.0)));
	d = min(d, ellipse_distance(p, vec2(151.0, 840.0), vec2(78.0, 31.0)));
	return 1.0 - smoothstep(-2.0, 30.0, d);
}

void fragment() {
	vec2 p = UV * vec2(1672.0, 941.0);
	float d = ellipse_distance(p, vec2(1560.0, 125.0), vec2(92.0, 88.0));
	d = min(d, ellipse_distance(p, vec2(1434.0, 203.0), vec2(112.0, 66.0)));
	d = min(d, ellipse_distance(p, vec2(822.0, 487.0), vec2(147.0, 110.0)));
	d = min(d, ellipse_distance(p, vec2(898.0, 211.0), vec2(182.0, 110.0)));
	// Entrance -> old corridor -> watershed court, following the supplied road.
	d = min(d, path_distance(p, vec2(1554.0, 139.0), vec2(1450.0, 200.0), 36.0));
	d = min(d, path_distance(p, vec2(1390.0, 220.0), vec2(1320.0, 250.0), 32.0));
	d = min(d, path_distance(p, vec2(1320.0, 250.0), vec2(1283.0, 286.0), 32.0));
	d = min(d, path_distance(p, vec2(1283.0, 286.0), vec2(1270.0, 337.0), 32.0));
	d = min(d, path_distance(p, vec2(1270.0, 337.0), vec2(1210.0, 388.0), 32.0));
	d = min(d, path_distance(p, vec2(1210.0, 388.0), vec2(1160.0, 412.0), 32.0));
	d = min(d, path_distance(p, vec2(1160.0, 412.0), vec2(1093.0, 403.0), 32.0));
	d = min(d, path_distance(p, vec2(1093.0, 403.0), vec2(1040.0, 437.0), 32.0));
	d = min(d, path_distance(p, vec2(1040.0, 437.0), vec2(1005.0, 478.0), 32.0));
	d = min(d, path_distance(p, vec2(1005.0, 478.0), vec2(918.0, 501.0), 32.0));
	// Watershed court -> salt pool. Other branches remain covered.
	d = min(d, path_distance(p, vec2(828.0, 417.0), vec2(850.0, 365.0), 38.0));
	d = min(d, path_distance(p, vec2(850.0, 365.0), vec2(818.0, 315.0), 38.0));
	d = min(d, path_distance(p, vec2(818.0, 315.0), vec2(785.0, 288.0), 38.0));
	d = min(d, path_distance(p, vec2(785.0, 288.0), vec2(801.0, 252.0), 38.0));
	float clouds = cloud_shadow(UV * vec2(5.0, 3.5), TIME * 0.16);
	float coverage = smoothstep(-6.0, 42.0, d + (clouds - 0.5) * 12.0);
	vec4 source = texture(TEXTURE, UV);
	// A prefiltered image gives continuous soft contours without repeated edges.
	vec3 obscured = textureLod(obscured_map, UV, 4.2).rgb;
	// Replace the baked nameplate with nearby terrain before darkening, so it
	// disappears into the same shadow instead of leaving an obvious black oval.
	vec3 around_label = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		vec2 side = vec2(float(x) * 18.0 / 1672.0, 70.0 / 941.0);
		around_label += textureLod(obscured_map, UV + side, 4.2).rgb;
		around_label += textureLod(obscured_map, UV - side, 4.2).rgb;
	}
	obscured = mix(obscured, around_label / 6.0, hidden_label(p));
	float grey = dot(obscured, vec3(0.299, 0.587, 0.114));
	obscured = mix(vec3(grey), obscured, 0.24);
	vec3 fog = mix(vec3(0.012, 0.018, 0.026), vec3(0.03, 0.038, 0.046), clouds);
	vec3 shadows = fog + obscured * mix(0.20, 0.32, clouds);
	COLOR = vec4(mix(source.rgb, shadows, coverage), source.a) * canvas_tint;
}
