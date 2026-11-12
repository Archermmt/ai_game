shader_type spatial;
render_mode specular_disabled;
uniform float progress = 1.0;
void vertex() {
	float t = clamp(progress, 0.0, 1.0);
	float eased = 1.0 - pow(1.0 - t, 3.0);
	VERTEX.y += UV2.x * (1.0 - eased);
}
void fragment() {
	vec3 low = COLOR.rgb / 12.92;
	vec3 high = pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4));
	ALBEDO = mix(low, high, step(vec3(0.04045), COLOR.rgb));
	ROUGHNESS = 1.0;
}
