shader_type sky;

uniform vec4 horizon : source_color = vec4(0.89, 0.86, 0.86, 1.0);
uniform vec4 upper : source_color = vec4(0.53, 0.68, 0.86, 1.0);
uniform vec4 cirrus : source_color = vec4(0.88, 0.89, 0.90, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(42.43,59.27)))*3462.39);
}
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend*blend*(3.0-2.0*blend);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),blend.x),
		mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),blend.x),blend.y);
}
void sky() {
	float h = max(EYEDIR.y,0.0);
	vec3 color = mix(horizon.rgb,upper.rgb,smoothstep(0.0,0.35,h));
	vec2 p = 1.2*EYEDIR.xz/max(h,0.028);
	p = vec2(p.x*0.70+p.y*0.25,p.y*1.66);
	float clouds = noise(p) * 0.65 + noise(p*2.72)*0.25 + noise(p*5.8)*0.10;
	float mask = smoothstep(0.686,0.704,clouds)*smoothstep(0.02,0.13,h);
	COLOR = mix(color,cirrus.rgb,mask*0.58);
}
