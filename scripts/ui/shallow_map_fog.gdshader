shader_type canvas_item;
render_mode unshaded;
uniform sampler2D obscured_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D label_free_map : filter_linear, repeat_disable;
// 默认参数保留餐厅剧情地图；探索视图传入真实道路遮罩和局部取景。
uniform sampler2D road_reveal : filter_linear_mipmap, repeat_disable;
uniform bool exploration_view = false;
uniform bool circular_view = false;
uniform bool map_unlocked = true;
uniform bool moss_pool_view = false;
uniform vec4 view_region = vec4(0.0, 0.0, 1.0, 1.0);
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

float nameplate_rect(vec2 p, vec4 bounds) {
	vec2 edge = abs(p - bounds.xy - bounds.zw * 0.5) - bounds.zw * 0.5;
	return 1.0 - smoothstep(0.0,8.0,length(max(edge,vec2(0.0))));
}

float minimap_nameplates(vec2 p) {
	// 仅替换原图十二块地名牌及其柔边，其他像素仍取原地图。
	float mask = nameplate_rect(p,vec4(151.0,137.0,132.0,42.0));
	mask = max(mask,nameplate_rect(p,vec4(374.0,169.0,141.0,42.0)));
	mask = max(mask,nameplate_rect(p,vec4(822.0,198.0,122.0,43.0)));
	mask = max(mask,nameplate_rect(p,vec4(217.0,380.0,124.0,42.0)));
	mask = max(mask,nameplate_rect(p,vec4(750.0,450.0,139.0,47.0)));
	mask = max(mask,nameplate_rect(p,vec4(227.0,620.0,126.0,41.0)));
	mask = max(mask,nameplate_rect(p,vec4(785.0,757.0,124.0,43.0)));
	mask = max(mask,nameplate_rect(p,vec4(1324.0,701.0,125.0,42.0)));
	mask = max(mask,nameplate_rect(p,vec4(1392.0,395.0,144.0,44.0)));
	mask = max(mask,nameplate_rect(p,vec4(1371.0,181.0,123.0,42.0)));
	mask = max(mask,nameplate_rect(p,vec4(1529.0,114.0,82.0,39.0)));
	return max(mask,nameplate_rect(p,vec4(104.0,821.0,101.0,43.0)));
}

void fragment() {
	vec2 map_uv = view_region.xy + UV * view_region.zw;
	vec2 p = map_uv * vec2(1672.0, 941.0);
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
	float clouds = cloud_shadow(map_uv * vec2(5.0, 3.5), TIME * 0.16);
	float coverage = smoothstep(-6.0, 42.0, d + (clouds - 0.5) * 12.0);
	if (moss_pool_view) {
		float moss = ellipse_distance(p, vec2(447.0,185.0), vec2(190.0,164.0));
		moss = min(moss,path_distance(p,vec2(553.0,264.0),vec2(611.0,380.0),22.0));
		coverage = min(coverage,smoothstep(-8.0,20.0,moss));
	}
	if (exploration_view) {
		float road = max(textureLod(road_reveal, map_uv,0.0).r, textureLod(road_reveal,map_uv,4.4).r * 0.95);
		coverage = min(coverage, 1.0 - road);
	}
	vec4 source = texture(TEXTURE, map_uv);
	if (circular_view) {
		source = mix(source,texture(label_free_map,map_uv),minimap_nameplates(p));
	}
	// A prefiltered image gives continuous soft contours without repeated edges.
	vec3 obscured = textureLod(obscured_map, map_uv, 4.2).rgb;
	// Replace the baked nameplate with nearby terrain before darkening, so it
	// disappears into the same shadow instead of leaving an obvious black oval.
	vec3 around_label = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		vec2 side = vec2(float(x) * 18.0 / 1672.0, 70.0 / 941.0);
		around_label += textureLod(obscured_map, map_uv + side, 4.2).rgb;
		around_label += textureLod(obscured_map, map_uv - side, 4.2).rgb;
	}
	obscured = mix(obscured, around_label / 6.0, hidden_label(p));
	float grey = dot(obscured, vec3(0.299, 0.587, 0.114));
	obscured = mix(vec3(grey), obscured, 0.24);
	vec3 fog = mix(vec3(0.012, 0.018, 0.026), vec3(0.03, 0.038, 0.046), clouds);
	vec3 shadows = fog + obscured * mix(0.20, 0.32, clouds);
	COLOR = vec4(mix(source.rgb, shadows, coverage), source.a) * canvas_tint;
	if (!map_unlocked || any(lessThan(map_uv, vec2(0.0))) || any(greaterThan(map_uv,vec2(1.0)))) {
		COLOR = vec4(0.025,0.045,0.055,1.0) * canvas_tint;
	}
	if (circular_view) {
		float radius = length(UV - vec2(0.5));
		// 对齐当前任务详情的米色底与一像素暖棕外边，增加内侧框带。
		float ring = smoothstep(0.459,0.469,radius);
		vec3 frame = mix(vec3(1.0,0.949,0.831),vec3(0.725,0.565,0.333),smoothstep(0.480,0.490,radius));
		COLOR.rgb = mix(COLOR.rgb,frame,ring);
		COLOR.a *= 1.0 - smoothstep(0.492,0.5,radius);
	}
}
