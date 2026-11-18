shader_type spatial;
// The practice yard's floor: stone ruled like a page. Thin lines every
// metre, a heavier margin line every eight, and one inked circle.

uniform vec3 paper : source_color = vec3(0.64, 0.61, 0.54);
uniform vec3 ink : source_color = vec3(0.10, 0.12, 0.19);
uniform float ring_radius = 14.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ruled(float v, float spacing, float width) {
	float d = abs(fract(v / spacing - 0.5) - 0.5) * spacing;
	float aa = fwidth(v) * 1.5;
	return 1.0 - smoothstep(width, width + aa, d);
}

void fragment() {
	float fine = ruled(world_pos.z, 1.0, 0.012) * 0.30;
	float margin = ruled(world_pos.x, 8.0, 0.028) * 0.50;
	float r = length(world_pos.xz);
	float ring = (1.0 - smoothstep(0.045, 0.045 + fwidth(r) * 1.5, abs(r - ring_radius))) * 0.80;
	// Lines fade with distance so the far floor reads as blank stone.
	float fade = 1.0 - smoothstep(22.0, 55.0, length(world_pos - CAMERA_POSITION_WORLD));
	float k = max(fine, max(margin, ring)) * fade;
	// Slow, large tonal drift so the surface is not one flat value.
	float drift = sin(world_pos.x * 0.07) * sin(world_pos.z * 0.05) * 0.03;
	ALBEDO = mix(paper + drift, ink, k);
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
