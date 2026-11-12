shader_type spatial;
render_mode specular_disabled;
varying vec3 wp;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; }
void fragment(){
	float sheltered = smoothstep(-.20,1.3,wp.y);
	float mineral = sin(wp.y*2.4+wp.x*.3+wp.z*.52)*.5+.5;
	ALBEDO=COLOR.rgb*mix(vec3(.74,.73,.91),vec3(1.03,.97,.98),sheltered)*(.95+.05*mineral);
	ROUGHNESS=1.;
}
