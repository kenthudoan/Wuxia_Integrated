shader_type canvas_item;
render_mode unshaded;
uniform float breakup:hint_range(0.0,1.0)=0.0;
void fragment(){
	vec4 color=texture(TEXTURE,UV)*COLOR;
	vec2 cell=floor(UV*32.0);
	float piece=fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
	color.a*=1.0-smoothstep(piece-.10,piece+.10,breakup);
	COLOR=color;
}
