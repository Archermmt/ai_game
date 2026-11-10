shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

global uniform float living_snow;
global uniform float living_season;
uniform vec4 foliage_tint : source_color = vec4(1.0);
uniform float wind_strength = 0.28;
uniform float wind_direction = 0.4;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform bool reduce_motion = false;
varying vec3 pigment;

void vertex() {
	float t = freeze_time ? sample_time : TIME;
	float bend = sin(t * 1.1 + UV.x * 6.283) * UV.y * 0.035 * wind_strength;
	VERTEX.xz += vec2(cos(wind_direction), sin(wind_direction)) * bend * (reduce_motion ? 0.0 : 1.0);
	VERTEX.y -= smoothstep(0.08, 0.58, living_snow) * 0.75;
	pigment = pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4));
}

void fragment() {
	// Low ground transitions disappear beneath the existing snow surface.
	if (living_snow > 0.58) { discard; }
	float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
	ALBEDO = pigment * foliage_tint.rgb * mix(vec3(1.0), vec3(1.22, 0.96, 0.70), autumn);
	ROUGHNESS = 0.96;
	SPECULAR = 0.10;
}
