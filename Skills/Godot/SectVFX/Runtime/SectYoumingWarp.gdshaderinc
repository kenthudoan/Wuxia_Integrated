uniform vec2 canvas_size=vec2(128.0);
uniform vec2 center_uv=vec2(0.5);
uniform float ellipse_ratio=1.0;
uniform float turn=0.0;
uniform float advance=1.0;
uniform vec2 reveal_bounds=vec2(0.0,1.0);
vec2 shadow_uv(vec2 uv){
	vec2 p=(uv-center_uv)*canvas_size;
	p.y/=ellipse_ratio;
	float c=cos(turn),s=sin(turn);
	p=mat2(vec2(c,s),vec2(-s,c))*p;
	p.y*=ellipse_ratio;
	return p/canvas_size+center_uv;
}
float reveal(vec2 uv){
	float row=floor(uv.y*canvas_size.y/8.0);
	float jag=fract(sin(row*12.9898)*43758.5453)*0.018*(1.0-step(0.999,advance));
	return step(uv.x,mix(reveal_bounds.x,reveal_bounds.y,advance)-jag);
}
