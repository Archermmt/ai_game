shader_type sky;
uniform vec4 high_air : source_color = vec4(.4275,.3569,.2902,1);
uniform vec4 low_air : source_color = vec4(.4471,.3647,.2980,1);
uniform vec4 horizon : source_color = vec4(.2706,.2275,.2471,1);
uniform vec4 distant_water : source_color = vec4(.3647,.2902,.2745,1);
uniform vec4 violet_water : source_color = vec4(.2275,.2196,.2902,1);
uniform vec4 middle_water : source_color = vec4(.1725,.2000,.2784,1);
uniform vec4 near_water : source_color = vec4(.1490,.1765,.2510,1);
uniform vec4 bottom_water : source_color = vec4(.1176,.1490,.2157,1);
uniform float warm_haze = 1.0;
uniform float blue_haze = 0.67;

void sky() {
	float h = EYEDIR.y;
	float depth=dot(EYEDIR,vec3(-0.24525657,-0.18789561,-0.95107542));
	vec2 horizon_uv=vec2(.5)+vec2(dot(EYEDIR,vec3(0.96832220,0.00000000,-0.24970405)),-dot(EYEDIR,vec3(-0.04691830,0.98218900,-0.18194349)))/max(.001,depth)/vec2(0.951201,0.535898);
	vec3 col = mix(low_air.rgb,high_air.rgb,smoothstep(.015,.07,h));
	if (h < .015) col=mix(horizon.rgb,low_air.rgb,smoothstep(-.008,.015,h));
	if (h < -.008) col=mix(distant_water.rgb,horizon.rgb,smoothstep(-.036,-.008,h));
	if (h < -.036) col=mix(violet_water.rgb,distant_water.rgb,smoothstep(-.115,-.036,h));
	if (h < -.115) col=mix(middle_water.rgb,violet_water.rgb,smoothstep(-.175,-.115,h));
	if (h < -.175) col=mix(near_water.rgb,middle_water.rgb,smoothstep(-.275,-.175,h));
	if (h < -.275) col=mix(bottom_water.rgb,near_water.rgb,smoothstep(-.375,-.275,h));
	// Broad atmospheric scatter across the locked art camera, independent of surface illumination.
	vec2 a=(horizon_uv-vec2(.507,.197))/vec2(.162,.202);
	vec2 b=(horizon_uv-vec2(.501,.47))/vec2(.193,.255);
	col += warm_haze*exp(-dot(a,a))*vec3(.246,.135,.058);
	col += blue_haze*exp(-dot(b,b))*vec3(.071,.089,.200);
	vec2 low_haze = (horizon_uv - vec2(.57,.43)) / vec2(.17,.20);
	col += exp(-dot(low_haze,low_haze)) * vec3(.046,.018,.012);
	COLOR=col;
}
