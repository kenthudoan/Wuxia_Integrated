shader_type canvas_item;
uniform bool reveal_enabled = false;
uniform float advance = 1.0;
uniform float origin_x = 0.09375;
uniform float breakup = 0.0;
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	float heat = smoothstep(0.04,0.36,max(source.r,max(source.g,source.b)));
	// Retain a thin charcoal rim; the source PNG itself is unchanged.
	COLOR.a *= mix(0.28,1.0,heat);
	if (reveal_enabled) {
		COLOR.a *= step(UV.x,mix(origin_x,1.0,advance));
		COLOR.a *= 1.0-smoothstep(0.96,1.0,UV.x);
		vec2 cell = floor(UV*64.0);
		float fragment_id = fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
		COLOR.a *= step(breakup,fragment_id+0.001);
	}
}
