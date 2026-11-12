shader_type sky;
uniform vec4 zenith : source_color = vec4(.015,.57,.75,1.);
uniform vec4 turquoise : source_color = vec4(.02,.87,.895,1.);
uniform vec4 cloud_light : source_color = vec4(.87,.93,.98,1.);
uniform vec4 cloud_shadow : source_color = vec4(.56,.77,.89,1.);

float hash(vec2 p) { return fract(sin(dot(p,vec2(41.21,73.54)))*21381.17); }
float noise2(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void sky() {
	float az=atan(EYEDIR.x,-EYEDIR.z);
	float h=EYEDIR.y;
	float n=.50*noise2(vec2(az*11.,h*12.))+.26*noise2(vec2(az*28.,h*25.))+.15*noise2(vec2(az*73.,h*78.))+.09*noise2(vec2(az*160.,h*141.));
	float rim=.124+.064*sin(az*4.6+2.0)+.064*sin(az*8.2-.40)+.040*cos(az*15.2+.6);
	rim+=.023+.65*max(0.,-az-.38);
	float mass=smoothstep(-.048,.021,rim+.092*(n-.45)-h);
	vec3 cloud=mix(cloud_light.rgb,cloud_shadow.rgb,smoothstep(.03,.31,rim-h+.19*(n-.55)));
	vec3 sky_col=mix(turquoise.rgb,zenith.rgb,smoothstep(.12,.77,h));
	COLOR=mix(sky_col,cloud,mass);
}
