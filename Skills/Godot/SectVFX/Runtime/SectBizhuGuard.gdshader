shader_type canvas_item;
#include "res://SectVFX/Runtime/SectBizhuBend.gdshaderinc"
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
void fragment(){COLOR=texture(TEXTURE,bizhu_uv(UV))*item_tint;}
