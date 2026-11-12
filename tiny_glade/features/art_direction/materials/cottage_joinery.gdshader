shader_type spatial;

global uniform float living_snow;
uniform bool wood = true;
uniform bool aged = false;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 pigment;
varying float upward;
varying vec3 local;

void vertex() {
	pigment = pow(COLOR.rgb * (1.0 / 1.055) + vec3(0.055 / 1.055), vec3(2.4));
	upward = NORMAL.y;
	local = VERTEX;
}

void fragment() {
	float grain = sin(UV.x * 82.0 + 2.3 * sin(UV.y * 2.7 + UV.x * 9.0));
	float stone = sin(local.x * 6.3 + local.z * 4.8 + 2.1 * sin(local.y * 8.0));
	float wear = wood ? grain * 0.055 : stone * 0.035;
	vec3 base = pigment * (1.0 + wear) * tint.rgb;
	if (aged) {
		base = mix(base, base * vec3(0.83, 0.95, 0.82), 0.65 - 0.22 * stone);
	}
	ALBEDO = mix(base, vec3(0.77, 0.83, 0.82), smoothstep(0.60, 0.98, upward) * living_snow * 0.9);
	ROUGHNESS = wood ? 0.94 : 0.97;
	SPECULAR = 0.16;
}
