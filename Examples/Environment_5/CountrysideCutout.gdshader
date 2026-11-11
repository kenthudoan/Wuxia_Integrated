shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	// Generated alpha has a faint background veil; retain solid sprite pixels only.
	COLOR = vec4(pixel.rgb, step(0.55, pixel.a));
}
