shader_type canvas_item;

uniform vec2 source_origin = vec2(0.0);
varying vec2 snow_pixel;

void vertex() {
	snow_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + source_origin;
}

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain(cell), grain(cell + vec2(1.0, 0.0)), f.x),
		mix(grain(cell + vec2(0.0, 1.0)), grain(cell + vec2(1.0, 1.0)), f.x), f.y);
}

float snow_height(vec2 p) {
	return soft_noise(p / 90.0) * 0.75 + soft_noise(p / 31.0) * 0.25;
}

void fragment() {
	vec2 p = floor(snow_pixel / 2.0) * 2.0;
	float height = snow_height(p);
	vec2 slope = vec2(snow_height(p + vec2(3.0, 0.0)) - snow_height(p - vec2(3.0, 0.0)),
		snow_height(p + vec2(0.0, 3.0)) - snow_height(p - vec2(0.0, 3.0)));
	float light = dot(normalize(vec3(-slope * 7.0, 1.0)), normalize(vec3(-0.5, -0.8, 1.0)));
	vec3 powder = mix(vec3(0.72, 0.79, 0.83), vec3(0.97, 0.975, 0.95), clamp(light * 1.5 - 0.3, 0.0, 1.0));
	powder += (height - 0.5) * 0.035 + (grain(p) - 0.5) * 0.025;
	powder = floor(powder * 40.0 + vec3(grain(p))) / 40.0;
	// World-space, two-pixel relief stays fixed while the camera and character move.
	COLOR = vec4(mix(texture(TEXTURE, UV).rgb, powder, 0.82), 1.0);
}
