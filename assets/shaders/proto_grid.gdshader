shader_type spatial;
// World-space graybox material. Grid lines stay 1 m apart whatever the size of
// the block, so the level reads to scale. Top faces are damp and pick up
// reflections; instance colour (MultiMesh) tints each block.
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 line_color : source_color = vec3(0.36, 0.45, 0.52);
uniform float grid_size = 1.0;
uniform float line_width = 0.012;
uniform float line_strength = 0.3;
uniform float top_roughness = 0.42;
uniform float side_roughness = 0.82;
uniform float puddle_amount = 0.55;
uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float grid_lines(vec2 point, float size, float width) {
	vec2 distance_to_line = abs(fract(point / size - 0.5) - 0.5) * size;
	vec2 pixel = fwidth(point);
	vec2 line = 1.0 - smoothstep(vec2(width), vec2(width) + pixel * 1.5, distance_to_line);
	return max(line.x, line.y);
}

void fragment() {
	vec3 facing = abs(world_normal);
	vec2 plane = facing.y > 0.5 ? world_position.xz : (facing.x > 0.5 ? world_position.zy : world_position.xy);
	float minor = grid_lines(plane, grid_size, line_width);
	float major = grid_lines(plane, grid_size * 5.0, line_width * 2.2);
	float distance_fade = 1.0 - smoothstep(18.0, 55.0, length(VERTEX));
	float lines = max(minor * 0.45, major) * line_strength * distance_fade;

	float broad = texture(noise_texture, plane * 0.035).r;
	float fine = texture(noise_texture, plane * 0.27).r;
	vec3 base = COLOR.rgb * mix(0.8, 1.1, fine) * mix(0.9, 1.05, broad);
	ALBEDO = mix(base, line_color, lines);

	float top = step(0.5, world_normal.y);
	float puddle = smoothstep(0.52, 0.72, broad) * top * puddle_amount;
	ROUGHNESS = mix(mix(side_roughness, top_roughness, top) + (fine - 0.5) * 0.18, 0.06, puddle);
	ALBEDO *= mix(1.0, 0.55, puddle);
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
