shader_type canvas_item;
render_mode unshaded,blend_add;
#include "res://SectVFX/Runtime/SectBizhuBend.gdshaderinc"
uniform sampler2D source_texture:filter_linear,repeat_disable;
uniform vec4 frame_rect=vec4(0.0,0.0,128.0,128.0);
uniform float padding=12.0;
uniform float blur_step=2.0;
uniform float strength=0.36;
uniform float opacity=1.0;
float alpha_at(vec2 p){
	if(p.x<0.0 || p.y<0.0 || p.x>=frame_rect.z || p.y>=frame_rect.w)return 0.0;
	vec2 uv=bizhu_uv((p+vec2(0.5))/frame_rect.zw);
	return texture(source_texture,(frame_rect.xy+uv*frame_rect.zw)/vec2(textureSize(source_texture,0))).a;
}
void fragment(){
	vec2 p=(UV-vec2(0.5))*(frame_rect.zw+vec2(padding*2.0))+frame_rect.zw*0.5;
	float weights[5]=float[5](1.0,4.0,6.0,4.0,1.0);
	float soft=0.0;
	for(int y=0;y<5;y++)for(int x=0;x<5;x++)soft+=alpha_at(p+vec2(float(x-2),float(y-2))*blur_step)*weights[x]*weights[y];
	soft/=256.0;
	COLOR=vec4(mix(vec3(0.46,0.62,0.31),vec3(0.93,0.99,0.78),smoothstep(0.04,0.55,soft)),soft*strength*opacity);
}
