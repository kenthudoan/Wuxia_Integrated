uniform bool guardian_warp=false;
uniform float counter_motion=0.0;
uniform float logical_canvas=183.0;

vec2 jingang_uv(vec2 uv){
	if(!guardian_warp)return uv;
	float arm=smoothstep(0.56,0.78,uv.x)*smoothstep(0.40,0.57,uv.y)*(1.0-smoothstep(0.86,0.98,uv.y));
	float torso=smoothstep(0.25,0.48,uv.y)*(1.0-smoothstep(0.70,0.9,uv.y));
	uv.x-=round((-6.0+8.0*counter_motion)*arm+1.0*counter_motion*torso)/logical_canvas;
	uv.y-=round(1.5*counter_motion*torso)/logical_canvas;
	return uv;
}
