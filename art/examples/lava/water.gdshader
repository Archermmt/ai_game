shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 deep_tone : source_color = vec4(.02,.16,.32,1.);
uniform vec4 middle_tone : source_color = vec4(.01,.59,.72,1.);
uniform vec4 far_tone : source_color = vec4(.02,.82,.84,1.);
varying vec3 wp;
void vertex(){ wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(81.17,27.99)))*31871.8); }
float noise2(vec2 p){
	vec2 i=floor(p), f=fract(p);f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);
}
void fragment(){
	float d=8.-wp.z;
	float ripple=noise2(wp.xz*vec2(1.8,6.8))*.58+noise2(wp.xz*vec2(3.8,11.5))*.26+noise2(wp.xz*.64)*.16;
	vec3 c=mix(deep_tone.rgb,middle_tone.rgb,smoothstep(4.4,8.8,d));
	c=mix(c,far_tone.rgb,smoothstep(7.4,12.2,d));
	c+=vec3(.009,.056,.075)*smoothstep(.56,.85,ripple)*(1.-smoothstep(6.,18.,d));
	ALBEDO=c;
}
