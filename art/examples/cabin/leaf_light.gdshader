shader_type spatial;
render_mode cull_disabled, specular_disabled;

varying vec3 world_position;
uniform float pigment_energy = 1.0;
uniform vec3 pigment_tint = vec3(1.0);
uniform float transmission : hint_range(0.0,1.0) = 0.36;

// Low-frequency variation groups neighboring sprays into a light or shade mass.
float leaf_wash(vec3 p) {
	return 0.5 + 0.25*sin(p.x*1.7+p.z*.73+sin(p.y*1.1))
		+ 0.25*sin(p.y*1.85-p.z*1.28+sin(p.x*1.9));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	float wash = smoothstep(.18,.82,leaf_wash(world_position));
	vec2 sun_gap = (world_position.xz-vec2(-7.5,-12.0))/vec2(5.2,7.0);
	float sunlit = exp(-dot(sun_gap,sun_gap));
	float shelter = smoothstep(0.0,5.5,world_position.x) * smoothstep(-14.0,-6.0,world_position.z)
		* (1.0-smoothstep(-0.7,3.0,world_position.z));
	vec3 grove_tint = mix(vec3(1.0),vec3(.84,.90,.81),shelter) + sunlit*vec3(.24,.22,.07);
	ALBEDO = COLOR.rgb * pigment_tint * pigment_energy * grove_tint * mix(vec3(.85,.90,.93),vec3(1.12,1.07,1.0),wash);
	ROUGHNESS = 1.0;
}

void light() {
	float incidence = dot(NORMAL,LIGHT);
	float diffuse = .46 + .49*smoothstep(-.36,.77,incidence);
	float attenuation = LIGHT_IS_DIRECTIONAL ? mix(transmission,1.0,ATTENUATION) : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR/PI * diffuse * attenuation;
}
