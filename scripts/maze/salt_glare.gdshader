shader_type canvas_item;
render_mode unshaded;
uniform sampler2D salt_mask : filter_linear;
uniform float elapsed=0.0;
void fragment(){
 float cycle=floor(elapsed/10.0);
 float phase=mod(elapsed,10.0);
 float envelope=smoothstep(2.0,3.2,phase)*(1.0-smoothstep(5.0,6.5,phase));
 vec2 center=vec2(0.38+0.30*sin(cycle*2.4),0.51+0.13*cos(cycle*1.9));
 float patch=1.0-smoothstep(0.25,1.0,length((UV-center)/vec2(0.20,0.17)));
 float streak=pow(max(0.0,sin(UV.x*30.0+UV.y*12.0+elapsed*0.3)),18.0);
 COLOR=vec4(vec3(1.0),texture(salt_mask,UV).a*envelope*patch*(0.72+0.2*streak));
}
