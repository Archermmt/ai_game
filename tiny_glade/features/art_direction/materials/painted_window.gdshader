shader_type spatial;

uniform bool dusk = false;
uniform float dusk_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float warm = max(dusk_mix, dusk ? 0.65 : 0.0);
	float canopy = smoothstep(0.1, 0.88, UV.y + sin(UV.x * 8.0 + UV.y) * 0.07);
	vec3 reflected = mix(vec3(0.043, 0.080, 0.066), vec3(0.135, 0.225, 0.216), canopy);
	float curtain = 0.82 + 0.09 * sin(7.0 * UV.x) + 0.06 * sin(18.0 * UV.x);
	vec3 candle = vec3(0.96, 0.58, 0.23) * curtain;
	ALBEDO = mix(reflected, candle * 0.42, warm);
	EMISSION = candle * warm * 0.67;
	ROUGHNESS = 0.67;
	SPECULAR = 0.22;
}
