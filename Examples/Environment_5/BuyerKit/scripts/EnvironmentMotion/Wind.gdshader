shader_type canvas_item;

uniform float motion_time = -1.0;
uniform float phase = 0.0;
uniform float amplitude = 3.0;
uniform float anchor_y = 128.0;
uniform float top_y = 0.0;
uniform float alpha_cutoff = 0.0;
uniform vec4 region_px = vec4(0.0, 0.0, 128.0, 128.0);
uniform vec2 atlas_size = vec2(128.0);
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
	// Extend the transparent sampling area so canopy pixels cannot clip at a sprite/atlas edge.
	float side = sign(VERTEX.x - region_px.z * 0.5);
	VERTEX.x += side * 5.0;
	UV.x += side * 5.0 / atlas_size.x;
}

void fragment() {
	float t = floor((motion_time < 0.0 ? TIME : motion_time) * 10.0) / 10.0;
	vec2 local = UV * atlas_size - region_px.xy;
	float height = clamp((anchor_y * 0.86 - local.y) / max(anchor_y * 0.86 - top_y, 1.0), 0.0, 1.0);
	float breeze = sin(t * 1.15 + phase) * 0.78 + sin(t * 1.93 + phase * 0.71) * 0.22;
	float offset = round(breeze * amplitude * height * height);
	vec2 sample_px = local + vec2(offset, 0.0);
	vec2 sample_uv = (floor(sample_px) + vec2(0.5) + region_px.xy) / atlas_size;
	vec4 source = texture(TEXTURE, sample_uv);
	float inside = step(0.0, sample_px.x) * step(sample_px.x, region_px.z - 0.001);
	inside *= step(0.0, sample_px.y) * step(sample_px.y, region_px.w - 0.001);
	if (alpha_cutoff > 0.0) source.a = step(alpha_cutoff, source.a);
	COLOR = vec4(source.rgb, source.a * inside) * item_tint;
}
