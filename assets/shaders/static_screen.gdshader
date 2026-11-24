shader_type spatial;
render_mode unshaded, shadows_disabled;
// A dead monitor showing static, with a rolling bar.

uniform float brightness = 0.55;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 cell = floor(UV * vec2(90.0, 60.0));
	float n = hash(cell + floor(TIME * 24.0));
	float roll = smoothstep(0.0, 0.1, abs(fract(UV.y + TIME * 0.35) - 0.5));
	ALBEDO = vec3(n) * brightness * (0.55 + 0.45 * roll) * vec3(0.85, 0.95, 1.0);
}
