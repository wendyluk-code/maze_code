shader_type canvas_item;
render_mode unshaded;
uniform vec2 overlay_size = vec2(1280.0,720.0);
uniform vec4 bubble_rect = vec4(0.0);

void fragment() {
	// 与气泡主体及尖角使用同一局部坐标，不挖出周围地图。
	vec2 p = (UV * overlay_size - bubble_rect.xy) / bubble_rect.zw * vec2(84.0,89.0) + vec2(-42.0,-90.0);
	vec2 q = abs(p - vec2(0.0,-51.0)) - vec2(34.0,31.0);
	float body = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0) - 8.0;
	float tip = max(max(-12.0-p.y,p.y+1.0),abs(p.x)-( -1.0-p.y)*8.0/11.0);
	COLOR.a *= smoothstep(1.5,2.0,min(body,tip));
}
