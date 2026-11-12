shader_type spatial;
render_mode cull_disabled, specular_disabled;
varying vec3 world_position;
void vertex(){
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
float rand_value(vec2 cell){
	return fract(sin(dot(cell,vec2(41.38,17.13)))*9617.14);
}
float grain(vec2 p){
	vec2 i=floor(p);
	vec2 f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(rand_value(i),rand_value(i+vec2(1,0)),f.x),
		mix(rand_value(i+vec2(0,1)),rand_value(i+vec2(1)),f.x),f.y);
}
void fragment(){
	vec2 p=world_position.xz;
	float dune=grain(p*0.34)+0.38*grain(p*1.7);
	float grit=grain(p*93.0);
	ALBEDO = COLOR.rgb*vec3(1.16,1.34,1.45)*(0.95+0.092*dune+0.019*grit);
	ROUGHNESS=1.0;
}
