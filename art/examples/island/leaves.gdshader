shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform float pigment_gain = 1.0;
varying vec3 leaf_position;
varying vec3 dome_normal;
varying float closed_bough;

void vertex() {
	leaf_position = VERTEX;
	vec3 offset = VERTEX - vec3(1.38, 7.56, -1.12);
	vec3 radial = normalize(offset / vec3(2.56, 1.75, 1.78));
	closed_bough = smoothstep(-0.92, 0.60, dot(offset, vec3(0.97, 0.68, -0.24)));
	dome_normal = normalize(mat3(VIEW_MATRIX) * MODEL_NORMAL_MATRIX * radial);
}

void fragment() {
	float sunward = smoothstep(0.5, 2.9, leaf_position.x);
	float copper = (1.0 - smoothstep(6.5, 7.7, leaf_position.y))
		* exp(-pow((leaf_position.x - 1.10) / 1.50, 2.0));

	// Vertex colors follow each bent leaf and its sprig. Keep the fine pigment
	// variations of the shaded sprays visible under the broad sunlit wash.
	vec3 palette = mix(vec3(1.22, 1.02, 0.87), vec3(0.55, 0.72, 0.98), sunward);
	palette *= mix(vec3(0.32, 0.37, 0.61), vec3(1.0), smoothstep(-0.45, 1.10, leaf_position.x));
	palette *= mix(vec3(1.0), vec3(1.23, 0.88, 0.77), copper);
	ALBEDO = COLOR.rgb * palette * pigment_gain;
	ROUGHNESS = 1.0;
}

void light() {
	float dome_weight = mix(0.56, 0.976, closed_bough);
	vec3 leaf_normal = normalize(mix(NORMAL, dome_normal, dome_weight));
	float incidence = dot(leaf_normal, LIGHT);
	float diffuse = max((incidence + 0.24) / 1.24, 0.0);
	float transmission = 0.14 * pow(max(dot(-VIEW, LIGHT), 0.0), 3.0) * max(-incidence, 0.0);
	float shadow = LIGHT_IS_DIRECTIONAL ? mix(mix(0.46, 0.76, closed_bough), 1.0, ATTENUATION) : ATTENUATION;
	DIFFUSE_LIGHT += (diffuse + transmission) * shadow * LIGHT_COLOR / PI;
}
