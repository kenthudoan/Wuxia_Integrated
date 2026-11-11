shader_type canvas_item;

uniform float motion_time = -1.0;
uniform float phase = 0.0;
uniform vec4 window_px = vec4(54.0, 74.0, 18.0, 16.0);
varying vec4 item_tint;

void vertex() { item_tint = COLOR; }

void fragment() {
	float t = floor((motion_time < 0.0 ? TIME : motion_time) * 8.0) / 8.0;
	float flame = 0.90 + sin(t * 2.1 + phase) * 0.055 + sin(t * 4.7 + phase * 1.3) * 0.025;
	vec4 source = texture(TEXTURE, UV);
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	float window = step(window_px.x, p.x) * step(p.x, window_px.x + window_px.z);
	window *= step(window_px.y, p.y) * step(p.y, window_px.y + window_px.w);
	// Restrict the flame colour to the glass; the roof, frame and pole retain their source pixels.
	float warm = step(source.b * 1.15 + 0.02, source.r);
	source.rgb = mix(source.rgb, source.rgb * flame + vec3(0.10, 0.058, 0.012) * flame, window * warm);
	COLOR = source * item_tint;
}
