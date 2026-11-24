shader_type canvas_item;
// Film look over the game: vignette, fine grain, a touch of chromatic
// aberration at the edges, and a red edge pulse when Kael is hurt.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.42;
uniform float grain = 0.035;
uniform float aberration = 0.0018;
uniform float hurt = 0.0;
uniform float low_health = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Photo mode: 0 none, 1 noir, 2 dusk, 3 cold, 4 echo, 5 faded film.
uniform int filter = 0;
// Photo mode: black bars, 0 (none) to 1 (2.39:1 widescreen).
uniform float letterbox = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centred = uv - 0.5;
	float edge = dot(centred, centred);
	vec2 shift = centred * (aberration + hurt * 0.006) * (0.5 + edge * 4.0);
	vec3 colour;
	colour.r = texture(screen, uv + shift).r;
	colour.g = texture(screen, uv).g;
	colour.b = texture(screen, uv - shift).b;
	colour *= tint.rgb;
	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	if (filter == 1) {
		colour = vec3(smoothstep(0.02, 0.85, luma));
	} else if (filter == 2) {
		colour = colour * vec3(1.4, 0.98, 0.62) + vec3(0.06, 0.025, 0.0) * (1.0 - luma);
	} else if (filter == 3) {
		colour = mix(vec3(luma), colour, 0.55) * vec3(0.82, 0.98, 1.2);
	} else if (filter == 4) {
		vec2 echo_shift = centred * 0.014;
		float ghost = dot(texture(screen, uv + echo_shift).rgb, vec3(0.3, 0.59, 0.11));
		colour = vec3(luma * 0.2 + ghost * 0.25, luma * 1.25, luma * 1.45) * 1.2;
		colour += vec3(0.0, 0.08, 0.1) * smoothstep(0.1, 0.45, edge);
	} else if (filter == 5) {
		colour = mix(vec3(luma) * vec3(1.08, 0.98, 0.82), colour, 0.35) * 0.82 + vec3(0.07, 0.06, 0.05);
	}
	float shade = 1.0 - smoothstep(0.08, 0.55, edge) * vignette;
	colour *= shade;
	float n = hash(uv * vec2(1920.0, 1080.0) + fract(TIME * 7.3) * 100.0) - 0.5;
	colour += n * grain;
	float rim = smoothstep(0.12, 0.5, edge);
	float beat = low_health * (0.55 + 0.45 * sin(TIME * 6.0));
	colour = mix(colour, vec3(0.55, 0.02, 0.0), clamp(rim * (hurt * 0.7 + beat * 0.45), 0.0, 0.8));
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float bar = letterbox * 0.5 * max(0.0, 1.0 - aspect / 2.39);
	if (uv.y < bar || uv.y > 1.0 - bar) {
		colour = vec3(0.0);
	}
	COLOR = vec4(colour, 1.0);
}
