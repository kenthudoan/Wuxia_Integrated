shader_type canvas_item;
render_mode unshaded, blend_add;

uniform sampler2D source_texture : filter_linear, repeat_disable;
uniform vec4 frame_rect = vec4(0.0, 0.0, 128.0, 128.0);
uniform float padding = 14.0;
uniform float strength = 1.15;
uniform float opacity = 1.0;
uniform vec3 tint_low = vec3(0.65, 0.82, 1.0);
uniform vec3 tint_high = vec3(1.0, 0.98, 0.90);

float alpha_at(vec2 p) {
	if (p.x < 0.0 || p.y < 0.0 || p.x >= frame_rect.z || p.y >= frame_rect.w) {
		return 0.0;
	}
	return texture(source_texture, (frame_rect.xy + p + vec2(0.5)) / vec2(textureSize(source_texture, 0))).a;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * (frame_rect.zw + vec2(padding * 2.0)) + frame_rect.zw * 0.5;
	float weights[5] = float[5](1.0, 4.0, 6.0, 4.0, 1.0);
	float soft = 0.0;
	for (int y = 0; y < 5; y++) {
		for (int x = 0; x < 5; x++) {
			soft += alpha_at(p + vec2(float(x - 2), float(y - 2)) * 2.2) * weights[x] * weights[y];
		}
	}
	soft /= 256.0;
	vec3 tint = mix(tint_low, tint_high, smoothstep(0.06, 0.50, soft));
	COLOR = vec4(tint, soft * strength * opacity);
}
