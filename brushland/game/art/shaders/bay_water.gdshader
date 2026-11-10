shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

uniform sampler2D island_field : filter_linear, repeat_disable;
uniform sampler2D reflection_tex : source_color, filter_linear, repeat_disable;
uniform mat4 reflected_clip;
uniform bool has_reflection = false;
uniform float reflection_detail : hint_range(0, 1) = 1.0;
uniform vec4 deep_color : source_color = vec4(0.15, 0.24, 0.31, 1.0);
uniform vec4 horizon : source_color = vec4(0.67, 0.62, 0.62, 1.0);
uniform vec4 shallow : source_color = vec4(0.48, 0.60, 0.57, 1.0);
uniform vec4 sunset_water : source_color = vec4(0.12, 0.15, 0.22, 1.0);
uniform vec4 sunset_horizon : source_color = vec4(0.65, 0.54, 0.54, 1.0);
uniform vec4 sun_glint : source_color = vec4(0.98, 0.87, 0.66, 1.0);
uniform float dusk = 0.0;
uniform float clock = 0.0;
uniform float motion = 1.0;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 field_uv = (world.xz + vec2(0.5)) / 64.0;
	vec2 field = texture(island_field, field_uv).rg;
	float distance_to_land = field.g * 8.0 + length((field_uv - clamp(field_uv, 0.0, 1.0)) * 64.0);
	float time = motion * clock;
	float wave = sin(world.z * 5.7 + 1.8 * sin(world.x * 0.84) + time * 0.52);
	float wave2 = sin(world.x * 4.1 + world.z * 1.4 - time * 0.41);
	float far_band = smoothstep(16.0, 95.0, -VERTEX.z);
	if (PROJECTION_MATRIX[3][3] < 0.5) {
		float elevation = normalize(CAMERA_POSITION_WORLD - world).y;
		far_band = mix(far_band, 1.0 - smoothstep(0.008, 0.24, elevation), 0.67);
	}
	vec3 lake = mix(mix(deep_color.rgb, sunset_water.rgb, dusk),
			mix(horizon.rgb, sunset_horizon.rgb, dusk), far_band);
	lake = mix(lake, shallow.rgb, 0.30 * (1.0 - smoothstep(0.0, 4.5, distance_to_land)) * (1.0 - 0.6 * dusk));
	if (reflection_detail < 0.999 && distance_to_land < 4.0) {
		// An overview still shows the real shore silhouette. Intersect the
		// reflected ray with the height field used by the shore brush.
		vec3 incident = PROJECTION_MATRIX[3][3] > 0.5 ? -INV_VIEW_MATRIX[2].xyz : normalize(world - CAMERA_POSITION_WORLD);
		vec3 ray = reflect(incident, vec3(0.0, 1.0, 0.0));
		float bank = 0.0;
		for (int step_to_bank = 1; step_to_bank <= 5; step_to_bank++) {
			vec3 point = world + ray * (float(step_to_bank) * 0.42);
			vec2 uv = (point.xz + 0.5) / 64.0;
			float land_y = textureLod(island_field, uv, 0.0).r * 2.2 - 0.15;
			bank = max(bank, smoothstep(-0.08, 0.18, land_y - point.y));
		}
		lake = mix(lake, mix(deep_color.rgb, sunset_water.rgb, dusk) * 0.66, bank * 0.52 * (1.0 - reflection_detail));
	}
	if (has_reflection) {
		vec4 clip = reflected_clip * vec4(world, 1.0);
		vec2 uv = clip.xy / clip.w * vec2(0.5, -0.5) + 0.5;
		uv += vec2(wave * 0.0015 + wave2 * 0.0007, wave2 * 0.00055);
		if (clip.w > 0.0 && all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			vec4 reflected = texture(reflection_tex, uv);
			lake = mix(lake, reflected.rgb, 0.62 * reflected.a * reflection_detail);
		}
	}
	vec2 ripple_grid = world.xz * vec2(2.1, 6.9);
	vec2 patch = floor(ripple_grid);
	vec2 local = fract(ripple_grid) - 0.5;
	float seed = hash(patch);
	float reed = 1.0 - smoothstep(0.045, 0.24, abs(local.y + 0.10 * wave));
	float glint = reed * (1.0 - smoothstep(0.08, 0.43, abs(local.x))) * smoothstep(0.87, 1.0, seed);
	glint *= 0.6 + 0.4 * sin(seed * 32.0 + time * 0.5);
	glint *= 1.0 - smoothstep(0.12, 0.70, max(fwidth(ripple_grid.x), fwidth(ripple_grid.y)));
	float waterline = 1.0 - smoothstep(0.015, 0.09, abs(field.r * 2.2 - 0.11));
	waterline *= 1.0 - smoothstep(0.0, 0.5, distance_to_land);
	lake = mix(lake, sun_glint.rgb, 0.25 * glint + waterline * (0.10 + 0.035 * wave));
	ALBEDO = lake;
}
