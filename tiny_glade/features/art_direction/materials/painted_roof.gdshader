shader_type spatial;

global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
uniform vec4 roof_tint : source_color = vec4(0.325, 0.400, 0.459, 1.0);
uniform bool aged = false;
varying vec3 local;
varying vec3 world;
varying vec3 slate;
varying float upward;

void vertex() {
	local = VERTEX;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// CottageMesh carries sRGB pigments. ArrayMesh COLOR is delivered as numeric bytes.
	slate = pow(COLOR.rgb * (1.0 / 1.055) + vec3(0.055 / 1.055), vec3(2.4));
	upward = NORMAL.y;
}

void fragment() {
	float cleavage = sin(local.z * 20.0 + local.x * 6.0 + 2.0 * sin(local.y * 4.9));
	float wash = sin(local.z * 2.71 + sin(local.x)) * sin(local.x * 2.34 + local.y * 0.38);
	// Preserve lighter chips and darker bedding in either the slate or earthen palette.
	float value = dot(slate, vec3(0.2126, 0.7152, 0.0722)) / 0.126;
	vec3 mineral = roof_tint.rgb * value * (1.0 + 0.045 * wash + 0.016 * cleavage);
	mineral = mix(mineral, mineral * vec3(0.85, 1.02, 0.91), (aged ? 0.4 : 0.04) * (wash * 0.5 + 0.5));
	float cloud = sin(world.x * 0.14 + living_time * 0.025) + cos(world.z * 0.1 + 0.3 * sin(world.x * 0.1));
	ALBEDO = mineral * (1.0 - smoothstep(-0.4, 1.5, cloud) * living_cloud * 0.22);
	ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.48, 0.93, upward));
	ROUGHNESS = aged ? 0.98 : 0.9;
	SPECULAR = 0.14;
}
