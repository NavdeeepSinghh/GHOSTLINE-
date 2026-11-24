shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A failing holographic ad: scanlines, a slow sweep, horizontal glitch bands
// and colour separation. `glitch` is raised now and then by the script.

uniform vec4 colour : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform vec4 second : source_color = vec4(1.0, 0.25, 0.7, 1.0);
uniform float strength = 0.9;
uniform float glitch = 0.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float band = floor(uv.y * 24.0 + TIME * 3.0);
	uv.x += (hash(band + floor(TIME * 12.0)) - 0.5) * 0.12 * glitch;
	float scan = 0.65 + 0.35 * sin(uv.y * 340.0 + TIME * 8.0);
	float sweep = smoothstep(0.0, 0.08, abs(fract(uv.y - TIME * 0.22) - 0.5));
	float frame = step(0.02, uv.x) * step(uv.x, 0.98) * step(0.04, uv.y) * step(uv.y, 0.96);
	float border = 1.0 - step(0.03, uv.x) * step(uv.x, 0.97) * step(0.06, uv.y) * step(uv.y, 0.94);
	// Abstract content: two soft rings and a bar graph.
	vec2 c = uv - vec2(0.24, 0.5);
	c.x *= 2.2;
	float rings = smoothstep(0.02, 0.0, abs(length(c) - 0.28 - 0.02 * sin(TIME * 2.0))) + smoothstep(0.02, 0.0, abs(length(c) - 0.16));
	float bars = step(0.62, uv.x) * step(uv.x, 0.94) * step(abs(fract(uv.x * 14.0) - 0.5), 0.3) * step(1.0 - uv.y, 0.25 + 0.6 * hash(floor(uv.x * 14.0) + floor(TIME * 2.0)));
	float fill = 0.1 + rings * 0.9 + bars * 0.6 + border * 0.8;
	vec3 tint = mix(colour.rgb, second.rgb, step(0.55, uv.x) * 0.6 + glitch * 0.4 * hash(band));
	float flicker = 0.85 + 0.15 * hash(floor(TIME * 20.0));
	ALBEDO = tint * fill * scan * (0.6 + 0.4 * sweep) * frame * strength * flicker;
}
