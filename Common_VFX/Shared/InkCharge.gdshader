shader_type canvas_item;

uniform float charge_progress : hint_range(0.0, 1.0) = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 base = source.rgb * sprite_tint.rgb;
	float weave = smoothstep(-0.25, 0.25, sin(UV.x * 24.0 + sin(UV.y * 16.0 - TIME * 3.0) * 3.0 + TIME * 5.0));
	float shade = 0.65 + dot(base, vec3(0.299, 0.587, 0.114)) * 0.35;
	vec3 ink = mix(vec3(0.025, 0.02, 0.035), vec3(1.0, 0.98, 0.93), weave) * shade;
	COLOR = vec4(mix(base, ink, charge_progress * 0.92), source.a * sprite_tint.a);
}
