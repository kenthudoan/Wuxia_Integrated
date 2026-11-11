uniform float bend_pixels=0.0;
uniform vec2 logical_canvas=vec2(128.0);
vec2 bizhu_uv(vec2 uv){
	uv.x+=bend_pixels*sin(clamp(uv.y,0.0,1.0)*3.14159265)/logical_canvas.x;
	return uv;
}
