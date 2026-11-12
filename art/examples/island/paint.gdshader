shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform float pigment_gain = 0.82;
uniform bool shoreline = false;
varying vec3 object_position;
float pigment_noise(vec3 p) {
	vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	vec3 seed=vec3(17.17,43.71,91.93);
	float n=0.;
	for(int x=0;x<2;x++) { for(int y=0;y<2;y++) { for(int z=0;z<2;z++) {
		vec3 c=vec3(float(x),float(y),float(z));
		vec3 w=mix(1.0-f,f,c);
		n+=fract(sin(dot(i+c,seed))*31741.7)*w.x*w.y*w.z;
	} } }
	return n;
}
void vertex() { object_position=VERTEX; }

void fragment() {
	float clay=smoothstep(.03,.15,COLOR.r-COLOR.g)*smoothstep(2.8,3.6,object_position.y);
	float wear=mix(1.0,mix(.83,1.09,pigment_noise(object_position*13.0)),clay);
	float damp=shoreline ? mix(.52,1.0,smoothstep(.1,.8,object_position.y)) : 1.0;
	ALBEDO = COLOR.rgb * wear * pigment_gain * damp;
	ROUGHNESS = 0.95;
}
void light() {
	float front = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += front * ATTENUATION * LIGHT_COLOR / PI;
}
