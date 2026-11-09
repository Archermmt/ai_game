shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
global uniform float living_time;
instance uniform float phase = 0.0;

void vertex() {
	vec3 across = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = MODEL_MATRIX[3].xyz + across * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float h = 1.0 - UV.y;
	float t = living_time * 0.48 + phase;
	float line = 0.5 + h * (0.18 + sin(h * 6.1 - t) * 0.13);
	float width = 0.043 + 0.13 * h + 0.027 * sin(12.0 * h - t) * h;
	float soft = 1.0 - smoothstep(0.0, width, abs(UV.x - line));
	ALBEDO = mix(vec3(0.40, 0.43, 0.41), vec3(0.70, 0.72, 0.67), h);
	ALPHA = soft * (1.0 - smoothstep(0.14, 1.0, h)) * 0.36;
}
