shader_type canvas_item;
uniform float reveal : hint_range(0.0,1.0) = 0.0;
uniform float dissolve : hint_range(0.0,1.0) = 0.0;
uniform float pulse_time=0.0;

void fragment() {
	vec2 p=(UV-vec2(0.5))/vec2(0.43,0.25);
	float sector=mod(atan(p.y,p.x)+3.14159265,6.2831853)/6.2831853;
	COLOR.a*=step(sector,reveal);
	COLOR.a*=0.88+0.12*sin(pulse_time*2.4-sector*6.2831853);
	vec2 cell=floor(UV*128.0);
	float fragment_id=fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
	COLOR.a*=step(dissolve,fragment_id+0.001);
}
