shader_type sky;

uniform float dusk = 0.0;
uniform vec4 day_air : source_color = vec4(0.72, 0.73, 0.75, 1);
uniform vec4 day_glow : source_color = vec4(0.88, 0.80, 0.70, 1);
uniform vec4 dusk_air : source_color = vec4(0.48, 0.45, 0.52, 1);
uniform vec4 dusk_glow : source_color = vec4(0.81, 0.64, 0.53, 1);
uniform vec4 water_horizon : source_color = vec4(0.67, 0.62, 0.62, 1);
uniform vec4 evening_horizon : source_color = vec4(0.65, 0.54, 0.54, 1);

void sky() {
	float height = EYEDIR.y;
	float azimuth = atan(EYEDIR.z, EYEDIR.x);
	vec3 air = mix(day_air.rgb, dusk_air.rgb, dusk);
	vec3 glow = mix(day_glow.rgb, dusk_glow.rgb, dusk);
	vec3 water = mix(water_horizon.rgb, evening_horizon.rgb, dusk);
	// Periodic ridges keep the distant bank continuous on a full orbit.
	float ridge = 0.004 + 0.004 * sin(7.0 * azimuth + 0.7) + 0.0018 * cos(17.0 * azimuth);
	vec3 sky_color = mix(glow, air, smoothstep(0.01, 0.33, height));
	float warm_arc = pow(max(0.0, dot(EYEDIR, normalize(vec3(-0.61, 0.12, 0.78)))), 12.0);
	sky_color = mix(sky_color, glow * 1.04, 0.38 * warm_arc);
	vec3 bank = mix(water, air * 0.72, smoothstep(-0.018, -0.001, height));
	COLOR = mix(bank, sky_color, smoothstep(ridge - 0.006, ridge + 0.004, height));
}
