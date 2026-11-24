shader_type spatial;
// Overlay on a dying Hollow: a cyan edge eating up through the body as it fades.
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 colour : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float progress = 0.0;

varying vec3 world_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(world_position * 7.0 + vec3(0.0, -TIME * 1.5, 0.0));
	float front = progress * 1.3 - 0.15;
	float edge = 1.0 - smoothstep(0.0, 0.12, abs(n - front));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = colour.rgb * (edge * 3.0 + rim * progress * 0.8) * step(0.001, progress);
}
