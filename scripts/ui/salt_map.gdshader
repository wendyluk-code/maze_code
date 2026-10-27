shader_type canvas_item;
uniform bool circular_view=false;
uniform vec4 view_region=vec4(0.0,0.0,1.0,1.0);
void fragment(){
 vec2 p=view_region.xy+UV*view_region.zw;
 vec4 c=texture(TEXTURE,p);
 if(any(lessThan(p,vec2(0.0))) || any(greaterThan(p,vec2(1.0)))) c=vec4(0.04,0.12,0.22,1.0);
 if(circular_view) c.a*=1.0-smoothstep(0.49,0.5,distance(UV,vec2(0.5)));
 COLOR=c;
}
