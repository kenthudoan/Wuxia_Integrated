shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec2 radius = vec2(138.0, 78.0);
uniform vec2 quad_size = vec2(304.0, 184.0);
uniform float opacity = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * quad_size;
	float distance_to_ring = abs(length(p / radius) - 1.0) * min(radius.x, radius.y);
	float soft = exp(-distance_to_ring * distance_to_ring / 8.0) * 0.24;
	COLOR = vec4(0.77, 0.88, 1.0, soft * opacity);
}
