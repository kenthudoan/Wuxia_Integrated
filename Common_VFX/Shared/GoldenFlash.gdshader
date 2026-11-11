shader_type canvas_item;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(1.0, 0.78, 0.2, source.a * COLOR.a);
}
