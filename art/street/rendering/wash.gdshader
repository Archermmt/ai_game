shader_type sky;

uniform vec4 blue_left : source_color = vec4(0.83, 0.95, 0.99, 1.0);
uniform vec4 blue_right : source_color = vec4(0.72, 0.83, 0.93, 1.0);
uniform vec4 ivory : source_color = vec4(0.997, 0.993, 0.999, 1.0);
uniform vec4 rose : source_color = vec4(0.98, 0.93, 0.951, 1.0);
uniform vec4 sand : source_color = vec4(0.954, 0.923, 0.876, 1.0);

void sky() {
	vec2 uv = SCREEN_UV;
	vec3 upper = mix(blue_left.rgb, blue_right.rgb, smoothstep(0.25, 1.0, uv.x));
	vec3 mid = mix(ivory.rgb, rose.rgb, smoothstep(0.12, 0.95, uv.x));
	vec3 wash = mix(upper, mid, smoothstep(0.0, 0.56, uv.y));
	COLOR = mix(wash, sand.rgb, smoothstep(0.57, 1.06, uv.y));
}
