shader_type canvas_item;
render_mode unshaded;
uniform vec3 tint_low=vec3(.57,.76,.90);
uniform vec3 tint_high=vec3(.90,.96,1.0);
void fragment(){
	vec4 source=texture(TEXTURE,UV);
	vec2 px=TEXTURE_PIXEL_SIZE;
	float inside=min(min(texture(TEXTURE,UV+vec2(px.x,0)).a,texture(TEXTURE,UV-vec2(px.x,0)).a),min(texture(TEXTURE,UV+vec2(0,px.y)).a,texture(TEXTURE,UV-vec2(0,px.y)).a));
	float contour=max(0.0,source.a-inside);
	float light=dot(source.rgb,vec3(.25,.60,.15));
	float body=source.a*mix(.30,.72,smoothstep(.16,.72,light));
	vec3 ice=mix(tint_low,tint_high,light);
	COLOR=vec4(ice,clamp(body+contour*.55,0.0,1.0)*COLOR.a);
}
