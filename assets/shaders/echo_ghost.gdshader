shader_type spatial;
// An Echo ghost: a glowing cyan silhouette with drifting scanlines and flicker.
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform vec4 colour : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float base_glow = 0.035;
uniform float strength = 1.0;
uniform float flicker = 1.0;
uniform float dissolve = 0.0;

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float lines = 0.75 + 0.25 * sin(world_position.y * 60.0 - TIME * 4.0);
	float band = smoothstep(0.92, 1.0, sin(world_position.y * 3.0 - TIME * 2.2)) * 0.6;
	float wobble = 1.0 - flicker * 0.35 * step(0.93, hash(vec2(floor(TIME * 14.0), 3.1)));
	float n = noise(world_position.xz * 6.0 + world_position.y * 4.0);
	float keep = step(dissolve, n * 0.9 + 0.05);
	float edge = (1.0 - smoothstep(0.0, 0.08, n * 0.9 + 0.05 - dissolve)) * step(0.001, dissolve);
	float glow = (base_glow + rim * 0.55 + band * 0.5) * lines * wobble;
	ALBEDO = colour.rgb * (glow * keep + edge * 1.5) * strength;
}
