shader_type spatial;
// World-space material for the Dead City: one shader covers asphalt, concrete,
// building facades (procedural windows), rusted metal and interiors. Instance
// colour (MultiMesh) tints each box. Upward faces are rain-wet and hold puddles
// that mirror the neon and sodium lights (screen-space reflections on Medium/High).
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float base_roughness = 0.85;
uniform float metallic_amount = 0.0;
uniform float wetness = 0.7;
uniform float puddle_amount = 0.0;
uniform float windows = 0.0;
uniform float seams = 0.0;
uniform float seam_size = 2.0;
uniform float road_markings = 0.0;
uniform float ripple_strength = 0.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Expanding rain rings on standing water.
float ripples(vec2 point) {
	float total = 0.0;
	for (int i = 0; i < 2; i++) {
		vec2 grid = point * (1.3 + float(i) * 0.9) + float(i) * 17.3;
		vec2 id = floor(grid);
		vec2 local = fract(grid) - 0.5;
		float seed = hash21(id);
		float age = fract(TIME * (0.7 + seed * 0.6) + seed * 9.0);
		vec2 centre = (vec2(hash21(id + 3.1), hash21(id + 7.7)) - 0.5) * 0.5;
		float ring = abs(length(local - centre) - age * 0.42);
		total += smoothstep(0.035, 0.0, ring) * (1.0 - age);
	}
	return total;
}

void fragment() {
	vec3 facing = abs(world_normal);
	bool is_top = world_normal.y > 0.5;
	vec2 plane = facing.y > 0.5 ? world_position.xz : (facing.x > 0.5 ? world_position.zy : world_position.xy);
	float perpendicular = facing.x > 0.5 ? world_position.x : world_position.z;

	float broad = texture(noise_texture, plane * 0.021).r;
	float mid = texture(noise_texture, plane * 0.13 + 0.37).r;
	float fine = texture(noise_texture, plane * 0.29).r;
	vec3 albedo = COLOR.rgb * mix(0.7, 1.14, mid) * mix(0.9, 1.08, fine);
	float roughness = base_roughness + (fine - 0.5) * 0.2;
	float metallic = metallic_amount;
	vec3 emission = vec3(0.0);

	if (!is_top && facing.y < 0.5) {
		// Rain streaks and grime running down walls.
		float streak = texture(noise_texture, vec2(plane.x * 0.31, plane.y * 0.026)).r;
		albedo *= mix(0.62, 1.05, smoothstep(0.25, 0.7, streak));
		roughness -= wetness * 0.22 * smoothstep(0.45, 0.75, streak);
		if (seams > 0.5) {
			vec2 cell = plane / seam_size;
			vec2 edge = abs(fract(cell) - 0.5);
			float line = smoothstep(0.485, 0.497, max(edge.x, edge.y));
			albedo *= 1.0 - line * 0.45;
		}
		if (windows > 0.5 && plane.y > 4.3) {
			vec2 cell = vec2(plane.x / 3.1, (plane.y - 4.3) / 3.2);
			vec2 id = floor(cell);
			vec2 f = fract(cell);
			float seed = hash21(id + floor(perpendicular) * 0.37);
			float frame = step(0.14, f.x) * step(f.x, 0.86) * step(0.2, f.y) * step(f.y, 0.82);
			float glass = step(0.19, f.x) * step(f.x, 0.81) * step(0.25, f.y) * step(f.y, 0.77);
			albedo = mix(albedo, albedo * 0.55, frame);
			if (glass > 0.5) {
				if (seed < 0.3) {
					// Broken or boarded.
					albedo = vec3(0.012, 0.014, 0.016);
					roughness = 1.0;
				} else {
					albedo = vec3(0.02, 0.03, 0.04);
					roughness = 0.07;
					metallic = 0.35;
					float flicker = 0.75 + 0.25 * sin(TIME * (2.0 + seed * 9.0) + seed * 40.0);
					emission += vec3(1.0, 0.62, 0.3) * step(0.975, seed) * 1.1 * flicker;
				}
			}
			// Floor slab line between storeys.
			albedo *= 1.0 - 0.3 * step(f.y, 0.045);
		}
		if (windows > 0.5 && plane.y <= 4.3) {
			albedo *= 0.62 + 0.25 * step(4.0, plane.y);
		}
	} else if (is_top) {
		if (road_markings > 0.5) {
			albedo = mix(albedo, albedo * 1.5 + 0.02, smoothstep(0.55, 0.8, broad) * 0.25);
		}
		float puddle = smoothstep(0.5, 0.66, broad + (mid - 0.5) * 0.25) * puddle_amount;
		float wet_roughness = mix(roughness, 0.3 + (fine - 0.5) * 0.2, wetness);
		roughness = mix(wet_roughness, 0.035, puddle);
		albedo *= mix(1.0 - 0.25 * wetness, 0.42, puddle);
		if (ripple_strength > 0.0 && puddle > 0.05) {
			float distance_fade = 1.0 - smoothstep(14.0, 32.0, length(VERTEX));
			float rings = ripples(plane) * distance_fade * ripple_strength;
			roughness += rings * 0.35 * puddle;
			albedo += vec3(0.05, 0.07, 0.09) * rings * puddle;
		}
	}

	ALBEDO = albedo;
	ROUGHNESS = clamp(roughness, 0.03, 1.0);
	METALLIC = metallic;
	SPECULAR = 0.5;
	EMISSION = emission;
}
