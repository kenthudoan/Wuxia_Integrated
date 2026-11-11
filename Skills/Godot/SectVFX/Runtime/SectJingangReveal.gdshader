shader_type canvas_item;
#include "res://SectVFX/Runtime/SectJingangWarp.gdshaderinc"
uniform float reveal : hint_range(0,1)=1.0;
uniform float top=0.0;
uniform float bottom=1.0;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){
	vec4 pixel=texture(TEXTURE,jingang_uv(UV));
	pixel.a*=step(mix(bottom,top,reveal),UV.y);
	COLOR=item_tint*pixel;
}
