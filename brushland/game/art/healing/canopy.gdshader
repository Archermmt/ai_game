shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float clock = 0.0;
uniform float fill_strength = 1.0;
uniform vec4 leaf_tint : source_color = vec4(1.0);
varying vec3 leaf_pos;

float grain(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float n = dot(cell, vec3(1.0, 57.0, 113.0));
	vec4 corner = n + vec4(0., 57., 113., 170.);
	vec4 a = fract(sin(corner)*4375.854);
	vec4 b = fract(sin(corner + 1.)*4375.854);
	vec4 x = mix(a, b, f.x);
	return mix(mix(x.x, x.y, f.y), mix(x.z, x.w, f.y), f.z);
}

void vertex() {
	leaf_pos = VERTEX;
	float flex = smoothstep(2.0, 4.3, VERTEX.y);
	VERTEX.x += flex * 0.028 * sin(clock * 0.8 + VERTEX.z + MODEL_MATRIX[3].x);
}

void fragment() {
	float dapple = grain(leaf_pos * 4.3) * 0.67 + grain(leaf_pos * 21.0) * 0.33;
	vec3 pigment = COLOR.rgb * leaf_tint.rgb * mix(0.84, 1.15, smoothstep(0.22, 0.76, dapple));
	// Compatibility writes to an sRGB backbuffer. Lift the low-frequency paint
	// using the same soft fill as the study, including the shaded crown edge.
	vec3 painted = OUTPUT_IS_SRGB ? pow(max(pigment, vec3(0.0)), vec3(0.72)) : pigment;
	ALBEDO = painted;
	EMISSION = painted * fill_strength * (0.41 + 0.18 * smoothstep(-1.0, 1.6, leaf_pos.x));
	ROUGHNESS = 1.0;
}

void light() {
	float curved = smoothstep(-0.32, 0.97, dot(NORMAL,LIGHT));
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (0.12 + 0.84 * curved) / PI;
}
