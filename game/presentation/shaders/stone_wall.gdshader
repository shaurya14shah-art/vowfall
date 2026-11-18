shader_type spatial;
// The Quarter's walls: dressed stone, not paint. Courses 1.6 m high with
// staggered joints, each block a shade off its neighbours, and a slow drift
// of tone across the whole wall. No textures: it is drawn from where each
// point of the wall is in the world. Joints fade with distance so that a
// far wall is the blank margin the art direction asks for.

uniform vec3 stone : source_color = vec3(0.70, 0.67, 0.60);
uniform vec3 ink : source_color = vec3(0.10, 0.12, 0.19);
uniform float course = 1.6;
uniform float block_length = 3.2;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Only upright faces are coursed; a floor or a wall-top is left plain.
	float upright = 1.0 - smoothstep(0.3, 0.6, abs(world_normal.y));
	float fade = 1.0 - smoothstep(16.0, 44.0, length(world_pos - CAMERA_POSITION_WORLD));

	float bed = abs(fract(world_pos.y / course - 0.5) - 0.5) * course;
	float bed_line = 1.0 - smoothstep(0.010, 0.010 + fwidth(world_pos.y) * 1.5, bed);

	float along = world_pos.x * abs(world_normal.z) + world_pos.z * abs(world_normal.x);
	float row = floor(world_pos.y / course);
	float run = (along + row * 1.37) / block_length;
	float joint = abs(fract(run - 0.5) - 0.5) * block_length;
	float joint_line = 1.0 - smoothstep(0.008, 0.008 + fwidth(along) * 1.5, joint);

	float block = fract(sin(dot(vec2(floor(run), row), vec2(12.9898, 78.233))) * 43758.5453);
	float drift = sin(world_pos.x * 0.11 + world_pos.z * 0.07) * sin(world_pos.y * 0.09 + world_pos.z * 0.05) * 0.035;

	vec3 base = stone * (1.0 + drift + (block - 0.5) * 0.055 * upright);
	float lines = max(bed_line * 0.17, joint_line * 0.11) * upright * fade;
	ALBEDO = mix(base, ink, lines);
	ROUGHNESS = 0.93;
	METALLIC = 0.0;
}
