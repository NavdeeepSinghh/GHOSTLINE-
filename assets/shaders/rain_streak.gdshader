shader_type spatial;
// A rain streak: a thin camera-facing quad stretched along the fall direction.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.55, 0.68, 0.8, 0.22);

void vertex() {
	// Billboard around the vertical axis so streaks stay upright.
	vec3 to_camera = normalize((INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz) * vec3(1.0, 0.0, 1.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_camera));
	vec3 fall = normalize(vec3(0.12, 1.0, 0.05));
	mat4 billboard = mat4(vec4(right, 0.0), vec4(fall, 0.0), vec4(to_camera, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = sin(UV.y * 3.14159);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * across * along;
}
