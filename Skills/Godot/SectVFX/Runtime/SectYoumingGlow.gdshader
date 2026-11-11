shader_type canvas_item;
render_mode unshaded,blend_add;
#include "res://SectVFX/Runtime/SectYoumingWarp.gdshaderinc"
uniform sampler2D source_texture:filter_linear,repeat_disable;
uniform vec4 frame_rect=vec4(0.0,0.0,128.0,128.0);
uniform float padding=12.0;
uniform float blur_step=2.0;
uniform float strength=0.48;
uniform float opacity=1.0;
float edge_at(vec2 p){
	vec2 uv=shadow_uv((p+vec2(0.5))/frame_rect.zw);
	if(uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0)return 0.0;
	vec4 v=texture(source_texture,(frame_rect.xy+uv*frame_rect.zw)/vec2(textureSize(source_texture,0)));
	return v.a*smoothstep(0.16,0.70,max(v.r,max(v.g,v.b)))*reveal(uv);
}
void fragment(){
	vec2 p=(UV-vec2(0.5))*(frame_rect.zw+vec2(padding*2.0))+frame_rect.zw*0.5;
	float weights[5]=float[5](1.0,4.0,6.0,4.0,1.0);
	float soft=0.0;
	for(int y=0;y<5;y++)for(int x=0;x<5;x++)soft+=edge_at(p+vec2(float(x-2),float(y-2))*blur_step)*weights[x]*weights[y];
	soft/=256.0;
	COLOR=vec4(vec3(0.72,0.49,0.94),soft*strength*opacity);
}
