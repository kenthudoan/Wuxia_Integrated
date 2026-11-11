shader_type canvas_item;
#include "res://SectVFX/Runtime/SectYoumingWarp.gdshaderinc"
uniform float dark_alpha:hint_range(0.0,1.0)=.14;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
	vec2 uv=shadow_uv(UV);
	vec4 source=texture(TEXTURE,uv);
	float light=max(source.r,max(source.g,source.b));
	float energy=smoothstep(.055,.66,light);
	source.a*=mix(dark_alpha,1.0,energy);
	COLOR=source*item_tint;
	COLOR.a*=reveal(uv);
}
