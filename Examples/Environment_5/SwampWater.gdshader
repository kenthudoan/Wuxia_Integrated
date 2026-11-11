shader_type canvas_item;

void fragment() {
	vec4 water = texture(TEXTURE, UV);
	COLOR = vec4(mix(vec3(0.15, 0.21, 0.18), water.rgb, 0.62), water.a);
}
