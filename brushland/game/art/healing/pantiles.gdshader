shader_type spatial;
render_mode specular_disabled;

// UV is baked in metres along the eave and up the slope so a batched elbow
// in a roof retains its own rows of overlapping terracotta tiles.
void fragment() {
	float row = UV.y / 0.100;
	float column = UV.x / 0.195 + mod(floor(row), 2.0) * 0.5;
	vec2 cell = floor(vec2(column, row));
	vec2 tile = fract(vec2(column, row));
	vec2 aa = clamp(fwidth(vec2(column, row)), vec2(0.0001), vec2(0.5));
	float lap = smoothstep(0.015-aa.y, 0.075+aa.y, tile.y);
	float bevel = smoothstep(0.005-aa.x, 0.09+aa.x, tile.x);
	float fade = 1.0 - smoothstep(0.2, 0.55, max(aa.x, aa.y));
	float fleck = fract(sin(dot(cell, vec2(4.21, 53.07))) * 3126.4);
	float pattern = (0.84 + 0.19 * fleck) * (0.8 + 0.2 * lap) * (0.91 + 0.09 * bevel);
	ALBEDO = COLOR.rgb * mix(0.93, pattern, fade);
	ROUGHNESS = 0.92;
}

void light() {
	float diffuse = smoothstep(-0.25, 0.94, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += ATTENUATION * (0.13 + 0.70 * diffuse) * LIGHT_COLOR / PI;
}
