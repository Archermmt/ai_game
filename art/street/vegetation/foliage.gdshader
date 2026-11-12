shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 sun_direction = vec3(0.32, 0.86, -0.39);
uniform vec3 shadow_tint = vec3(0.78, 0.67, 0.80);
uniform float soft_facets : hint_range(0.0, 1.0) = 0.75;
uniform float highlight : hint_range(0.0, 1.0) = 0.16;
varying vec3 normal_world;

void vertex() {
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float incidence = dot(normalize(normal_world), normalize(sun_direction));
	float soft = smoothstep(-0.65, 0.85, incidence);
	float stepped = smoothstep(0.16, 0.42, incidence);
	float amount = mix(stepped, soft, soft_facets);
	vec3 ink = COLOR.rgb * mix(shadow_tint, vec3(1.0), amount);
	ink = mix(ink, vec3(1.0, 0.98, 1.0), highlight * smoothstep(0.20, 0.90, incidence));
	ALBEDO = OUTPUT_IS_SRGB ? ink : mix(ink / 12.92, pow((ink + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), ink));
}
