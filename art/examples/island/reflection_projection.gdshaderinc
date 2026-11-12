// Shear the reflected mesh along the viewing azimuth so more of the roof
// plane remains visible below the near bank. Keep geometry on the shoreline
// pinned to the mirror plane during an orbit.
float mirror_height_shift(vec3 vertex, mat4 model, vec3 camera_world) {
	float compression = length(model[1].xyz);
	vec2 toward_eye = camera_world.xz - model[3].xz;
	float distance_to_eye = max(length(toward_eye), 0.01);
	float slope = clamp((camera_world.y-model[3].y)/distance_to_eye, -0.35, 0.50);
	float depth = dot((model*vec4(vertex,1.0)).xz-model[3].xz,toward_eye/distance_to_eye);
	float above_shore = smoothstep(0.45,1.45,vertex.y);
	float bank_occlusion = 0.40;
	return -(0.46*(1.0+compression)*slope*depth+bank_occlusion)*above_shore/compression;
}
