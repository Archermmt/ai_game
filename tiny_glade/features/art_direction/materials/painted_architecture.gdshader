shader_type spatial;

global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
uniform bool aged = false;
uniform vec4 plaster_tint : source_color = vec4(0.741, 0.518, 0.455, 1.0);
uniform vec4 roof_tint : source_color = vec4(1.0);
varying vec3 local;
varying vec3 world;
varying float upward;

void vertex() {
	local = VERTEX;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	upward = NORMAL.y;
}

void fragment() {
	vec2 brush = vec2(local.x + local.z * 0.83, local.y);
	float cloud = sin(brush.x * 1.89 + cos(brush.y * 1.73)) * sin(brush.y * 2.31 + 0.4 * brush.x);
	float stroke = sin(brush.y * 21.0 + brush.x * 5.0 + 3.8 * sin(brush.x * 1.9));
	vec3 limewash = plaster_tint.rgb * (1.02 + 0.075 * cloud + 0.008 * stroke);
	// Shallow trowel relief belongs to the plaster, leaving real apertures intact.
	NORMAL_MAP = normalize(vec3(0.035 * sin(brush.x * 9.1 + brush.y * 2.7),
		0.027 * cos(brush.y * 8.4 + sin(brush.x * 4.3)), 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.55;
	float damp = 1.0 - smoothstep(0.15, 0.7 + cloud * 0.12, local.y);
	limewash *= mix(vec3(1.0), vec3(0.77, 0.84, 0.77), damp * (aged ? 0.85 : 0.32));
	float shadow = sin(world.x * 0.14 + living_time * 0.025) + cos(world.z * 0.10 + 0.3 * sin(world.x * 0.1));
	ALBEDO = limewash * (1.0 - smoothstep(-0.4, 1.5, shadow) * living_cloud * 0.22);
	ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.55, 0.95, upward));
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
