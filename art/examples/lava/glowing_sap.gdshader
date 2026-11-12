shader_type spatial;
render_mode unshaded;
uniform vec4 edge : source_color = vec4(.79,.60,.005,1.);
uniform vec4 body : source_color = vec4(1.,.937,.016,1.);
uniform vec4 glint : source_color = vec4(1.,.998,.61,1.);
varying vec3 normal_world;
void vertex(){ normal_world = normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment(){
	vec3 n=normalize(normal_world);
	float facing=dot(n,normalize(vec3(-.3, .9,.4)));
	vec3 tone=mix(edge.rgb,body.rgb,smoothstep(-.75,.56,facing));
	tone=mix(tone,glint.rgb,.60*smoothstep(.90,.99,facing));
	ALBEDO=tone*1.045;
}
