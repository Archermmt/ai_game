shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D picture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depths : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normals : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform float ink_strength = 0.44;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_distance(vec2 uv, mat4 inv_proj) {
	vec4 p = inv_proj * vec4(uv * 2.0 - 1.0, texture(depths, uv).x, 1.);
	return -p.z / p.w;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float center = view_distance(uv, INV_PROJECTION_MATRIX);
	vec3 n = normalize(texture(normals, uv).xyz * 2.0 - 1.0);
	vec2 offsets[4] = {vec2(-1,0),vec2(1,0),vec2(0,-1),vec2(0,1)};
	float edge = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 p = uv + offsets[i] * 0.00064 * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0);
		float other = view_distance(p, INV_PROJECTION_MATRIX);
		vec3 other_n = normalize(texture(normals, p).xyz * 2.0 - 1.0);
		float silhouette = smoothstep(0.18, 0.52, other - center);
		float crease = smoothstep(0.15, 0.62, 1.0 - dot(n, other_n));
		edge = max(edge, max(silhouette, 0.58 * crease));
	}
	vec3 color = texture(picture, uv).rgb;
	ALBEDO = mix(color, color * vec3(0.40, 0.36, 0.45), edge * ink_strength);
	ALPHA = 1.0;
}
