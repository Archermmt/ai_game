shader_type spatial;
render_mode cull_disabled, specular_disabled, shadows_disabled, fog_disabled;
#include "res://examples/island/reflection_projection.gdshaderinc"
varying vec3 reflected;
varying vec3 source_normal;
varying vec3 source_position;
uniform bool canopy = false;
uniform bool tree_reflection = false;
void vertex() {
	source_position = VERTEX;
	if (tree_reflection) {
		VERTEX.y *= .68 / length(MODEL_MATRIX[1].xyz);
	} else {
		VERTEX.y += mirror_height_shift(VERTEX, MODEL_MATRIX, CAMERA_POSITION_WORLD);
	}
	// Flip local Y before the model's mirrored normal transform to keep the lit hemisphere upright.
	vec3 n=NORMAL;
	if (canopy) {
		vec3 radial=normalize((source_position-vec3(1.38,7.56,-1.12))/vec3(2.56,1.75,1.78));
		n=normalize(mix(NORMAL,radial,.45));
	}
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * n);
	world_normal.y *= -length(MODEL_MATRIX[1].xyz);
	source_normal = mat3(VIEW_MATRIX) * world_normal;
	reflected = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	float ripples = sin(reflected.z*3.7+reflected.y*6.8) + .42*sin(reflected.x*3.4+reflected.z*2.3);
	VERTEX.x += .026 * ripples * smoothstep(0.,3.2,-reflected.y);
}
void fragment() {
	vec3 tint = vec3(.41,.32,.32);
	if (canopy) {
		float sky_light = smoothstep(-.4,2.8,source_position.x);
		tint = mix(vec3(.35,.37,.55),vec3(.77,.62,.55),sky_light);
	} else {
		float pale_surface = smoothstep(0.30,0.56,COLOR.g);
		tint *= mix(vec3(1.0),vec3(.74,.67,.70),pale_surface);
	}
	ALBEDO = COLOR.rgb * tint;
	ROUGHNESS = 1.0;
}
void light() {
	float incidence = dot(normalize(source_normal),LIGHT);
	float front = max(incidence,0.0);
	// Approximate the same diffuse canopy transmission in its underwater image.
	if (canopy) {
		float reflected_volume = mix(0.58,1.0,smoothstep(-0.8,2.9,source_position.x));
		front = (0.11 + 0.54*smoothstep(-0.25,0.9,incidence))*reflected_volume;
	}
	DIFFUSE_LIGHT += front * ATTENUATION * LIGHT_COLOR/PI;
}
