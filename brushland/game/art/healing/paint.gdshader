shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 pigment_tint : source_color = vec4(1.0);

void fragment() {
	ALBEDO = COLOR.rgb * pigment_tint.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float d = smoothstep(-0.25, 0.94, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += ATTENUATION * (0.13 + 0.70 * d) * LIGHT_COLOR / PI;
}
