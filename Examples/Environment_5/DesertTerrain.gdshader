shader_type canvas_item;

void fragment() {
	// Fade each repeat edge into the middle of a shifted tile, preserving source PNGs.
	vec2 weight = pow(sin(fract(UV) * 3.14159265), vec2(2.0));
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(TEXTURE, UV + vec2(0.5, 0.0));
	vec4 c = texture(TEXTURE, UV + vec2(0.0, 0.5));
	vec4 d = texture(TEXTURE, UV + vec2(0.5));
	COLOR = mix(mix(d, c, weight.x), mix(b, a, weight.x), weight.y);
}
