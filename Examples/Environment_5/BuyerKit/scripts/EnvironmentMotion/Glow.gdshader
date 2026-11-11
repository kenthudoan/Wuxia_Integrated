shader_type canvas_item;
render_mode blend_add;

uniform float motion_time = -1.0;
uniform float phase = 0.0;

void fragment() {
	float t = floor((motion_time < 0.0 ? TIME : motion_time) * 8.0) / 8.0;
	float flame = 0.90 + sin(t * 2.1 + phase) * 0.055 + sin(t * 4.7 + phase * 1.3) * 0.025;
	vec2 p = (floor(UV * vec2(24.0, 18.0)) + vec2(0.5)) / vec2(24.0, 18.0) * 2.0 - 1.0;
	float band = floor(max(0.0, 1.0 - length(p)) * 5.0) / 5.0;
	COLOR = vec4(0.95, 0.58, 0.19, band * 0.13 * flame);
}
