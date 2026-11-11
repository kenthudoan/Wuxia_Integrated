shader_type canvas_item;

uniform float motion_time = -1.0;
uniform float speed = 1.0;
uniform bool marsh = false;
uniform bool composite = false;
varying vec2 world_pixel;
varying vec4 item_tint;

void vertex() {
	world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	item_tint = COLOR;
}

void fragment() {
	float t = floor((motion_time < 0.0 ? TIME : motion_time) * 8.0) / 8.0 * speed;
	vec2 p = floor(world_pixel / 2.0) * 2.0;
	vec2 drift = vec2(round(sin(p.y * 0.043 + t * 1.3)), round(sin(p.x * 0.029 - t * 0.7)));
	vec4 original = texture(TEXTURE, UV);
	vec4 source = texture(TEXTURE, UV + drift * TEXTURE_PIXEL_SIZE);
	float mask = 1.0;
	if (composite) {
		// The pond is a composite: only blue-green water pixels shimmer; lotus and masonry stay fixed.
		source = original;
		mask = step(original.r * 1.12 + 0.015, original.g) * step(original.r * 1.08 + 0.01, original.b);
	}
	if (marsh) source.rgb = mix(vec3(0.15, 0.21, 0.18), source.rgb, 0.62);
	float wave = sin(p.y * 0.115 + sin(p.x * 0.018) * 1.4 - t * 1.7);
	float broken = step(0.1, sin(p.x * 0.12 + floor(p.y / 14.0) * 1.9 + t * 0.3));
	float glint = step(0.94, wave) * broken;
	float shade = step(wave, -0.97) * broken;
	float strength = marsh ? 0.45 : 1.0;
	source.rgb += mask * strength * (glint * vec3(0.038, 0.048, 0.044) - shade * vec3(0.014, 0.018, 0.016));
	COLOR = vec4(clamp(source.rgb, vec3(0.0), vec3(1.0)), source.a) * item_tint;
}
