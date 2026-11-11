shader_type canvas_item;
uniform float advance : hint_range(0.0, 1.0) = 0.0;
uniform float origin_x = 0.09375;
uniform float breakup : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.a *= step(UV.x, mix(origin_x, 1.0, advance));
	// The energy field dissipates at its range limit instead of ending on a hard vertical cut.
	COLOR.a *= 1.0 - smoothstep(0.96, 1.0, UV.x);
	vec2 cell = floor(UV * 64.0);
	float fragment_id = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR.a *= step(breakup, fragment_id + 0.001);
}
