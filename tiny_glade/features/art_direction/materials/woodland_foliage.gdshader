shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
uniform float wind_strength = 0.45;
uniform float wind_direction = 0.4;
uniform float amplitude = 0.07;
uniform float phase = 0.0;
uniform bool batched = false;
uniform bool season_deciduous = false;
uniform vec4 foliage_tint : source_color = vec4(1.0);
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
varying vec3 pigment;
varying vec3 world_position;
varying vec3 local_position;
varying float up;
varying float living_tip;

float speck(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float washy_patch(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(speck(cell), speck(cell + vec2(1.0, 0.0)), f.x),
			mix(speck(cell + vec2(0.0, 1.0)), speck(cell + 1.0), f.x), f.y);
}

void vertex() {
	local_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
	living_tip = UV.y;
	float t = freeze_time ? sample_time : TIME;
	float offset = phase + (batched ? INSTANCE_CUSTOM.r * 6.283 : 0.0);
	float wave = sin(t * 0.86 + offset + world_position.y * 0.10) + 0.16 * sin(t * 1.7 + world_position.x);
	VERTEX.xz += vec2(cos(wind_direction), sin(wind_direction)) * wave * amplitude * wind_strength * UV.x * (reduce_motion ? 0.0 : 1.0);
	// A cool interior, sun-warmed nearest boughs. Evaluate in world space so
	// a planted tree shares the same light transition as the batched grove.
	vec3 srgb = COLOR.rgb;
	if (living_tip > 0.5 && living_tip < 1.5) {
		// Muted blue-green depth, with broken sunlight on the two foreground
		// groups. Lower boughs stay green where the crown shelters itself.
		float depth = 1.0 - smoothstep(-14.0, 3.0, world_position.z);
		float patch = 0.5 + sin(world_position.x * 0.43 + world_position.y * 0.37) * 0.27
				+ sin(world_position.z * 0.51 - world_position.x * 0.29) * 0.19;
		float crown_light = smoothstep(-0.44, 0.8, up);
		srgb *= mix(vec3(0.94, 0.97, 0.96), vec3(0.63, 0.78, 0.91), depth);
		srgb += depth * vec3(0.0, 0.004, 0.023);
		srgb *= 0.84 + 0.12 * patch + 0.06 * crown_light;
		float warm = smoothstep(1.0, 10.5, world_position.z) * smoothstep(1.7, 5.8, world_position.y)
				* smoothstep(0.18, 0.72, patch) * (0.18 + 0.82 * crown_light);
		srgb = mix(srgb, srgb * vec3(1.34, 1.13, 0.84) + vec3(0.047, 0.018, 0.0), warm);
	}

	pigment = pow((srgb + 0.055) / 1.055, vec3(2.4));
}

void fragment() {
	if (season_deciduous && living_season > 2.5 && living_tip > 0.5) {
		discard;
	}
	float greenery = step(0.5, living_tip) * (1.0 - step(1.5, living_tip));
	vec3 paint = pigment * mix(vec3(1.0), foliage_tint.rgb, greenery);
	if (greenery > 0.5) {
		// Broad and fine clustered pigment breaks up the smooth canopy surface
		// while the outermost leaves and their shadows are actual geometry.
		vec2 brush = vec2(local_position.x + 0.69 * local_position.y, local_position.z - 0.54 * local_position.y);
		float broad = washy_patch(brush * 1.35);
		float fine = washy_patch(brush * 5.2 + vec2(3.6, 8.9));
		float strokes = smoothstep(0.28, 0.74, broad * 0.78 + fine * 0.22);
		paint *= mix(vec3(0.87, 0.91, 0.94), vec3(1.06, 1.04, 0.98), strokes);
	}
	float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
	if (season_deciduous) {
		paint = mix(paint, paint * vec3(2.05, 0.90, 0.42) + vec3(0.065, 0.005, 0.0), greenery * autumn);
	}
	if (living_tip < -0.5) {
		float grain = sin(world_position.x * 19.0 + world_position.z * 25.0 + 0.62 * sin(world_position.y * 2.1));
		paint *= 0.89 + 0.11 * smoothstep(-0.86, -0.14, grain);
	}
	float cloud = 0.5 + sin(world_position.x * 0.11 + living_time * 0.024) * 0.25 + cos(world_position.z * 0.09) * 0.20;
	paint *= 1.0 - smoothstep(0.43, 0.77, cloud) * living_cloud * 0.20;
	ALBEDO = mix(paint, vec3(0.81, 0.86, 0.88), living_snow * smoothstep(0.48, 0.94, up));
	ROUGHNESS = 0.96;
	SPECULAR = 0.085;
	BACKLIGHT = paint * greenery * 0.09;
}
