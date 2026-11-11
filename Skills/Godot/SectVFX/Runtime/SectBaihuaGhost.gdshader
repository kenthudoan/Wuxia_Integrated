shader_type canvas_item;
uniform float pulse_time=0.0;

void fragment() {
	float light=dot(COLOR.rgb,vec3(.299,.587,.114));
	COLOR.rgb=mix(vec3(.46,.15,.25),vec3(.95,.55,.71),smoothstep(.28,.90,light));
	vec2 cell=floor(UV*128.0);
	float phase=fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453)*6.2831853;
	COLOR.a*=0.85+0.15*sin(pulse_time*3.0+phase);
}
