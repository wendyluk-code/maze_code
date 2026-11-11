shader_type canvas_item;
uniform bool flash=false;
uniform vec2 impact_scale=vec2(1.0);
uniform float impact_angle=0.0;
uniform vec2 motion_scale=vec2(1.0);
uniform float motion_angle=0.0;
uniform sampler2D next_sheet : source_color, filter_linear;
uniform vec2 next_cell=vec2(0.0);
uniform float pose_blend=0.0;
uniform sampler2D entry_sheet : source_color, filter_linear;
uniform sampler2D entry_next_sheet : source_color, filter_linear;
uniform vec2 entry_cell=vec2(0.0);
uniform vec2 entry_next_cell=vec2(0.0);
uniform float entry_pose_blend=0.0;
uniform float entry_mix=1.0;
varying vec4 tint;
void vertex(){
 tint=COLOR;
 vec2 p=VERTEX*impact_scale*motion_scale;
 float angle=impact_angle+motion_angle;
 VERTEX=vec2(cos(angle)*p.x-sin(angle)*p.y,sin(angle)*p.x+cos(angle)*p.y);
}
void fragment(){
 vec4 first=texture(TEXTURE,UV);
 vec2 cell_uv=fract(UV*4.0);
 vec4 second=texture(next_sheet,(next_cell+cell_uv)/4.0);
 // 姿态不透明叠合：只显示一张主体，过渡由重心形变和接续姿态负责。
 vec4 current=mix(first,second,step(0.5,pose_blend));
 vec4 previous=mix(texture(entry_sheet,(entry_cell+cell_uv)/4.0),texture(entry_next_sheet,(entry_next_cell+cell_uv)/4.0),step(0.5,entry_pose_blend));
 COLOR=mix(previous,current,step(0.5,entry_mix))*tint;
 if(flash){COLOR.rgb=vec3(1.0);}
}
