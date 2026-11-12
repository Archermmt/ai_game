shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float clock = 0.0;
varying float phase;

void vertex() {
	vec3 side = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 up = vec3(0., 1., 0.);
	mat4 billboard = mat4(vec4(side, 0.), vec4(up, 0.),
			vec4(cross(side, up), 0.), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	phase = MODEL_MATRIX[3].x * 0.27;
}

void fragment() {
	float h = 1.0 - UV.y;
	float bend = 0.16 * h * sin(h * 6.7 - clock * 0.64 + phase) + 0.20 * h;
	float w = mix(0.027, 0.132, h);
	float distance_to_smoke = (UV.x - 0.45 - bend) / w;
	float density = exp(-distance_to_smoke * distance_to_smoke * 0.65);
	ALBEDO = vec3(0.85, 0.82, 0.80);
	ALPHA = density * pow(1.0 - h, 1.4) * smoothstep(0.0, 0.11, h) * 0.55;
}
