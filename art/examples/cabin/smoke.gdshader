shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform float smoke_time = 0.0;
uniform vec4 vapor : source_color = vec4(0.84, 0.87, 0.80, 1.0);

void fragment() {
	float height = 1.0 - UV.y;
	float sway = (sin(height * 7.4 - smoke_time * 0.53) - sin(-smoke_time * 0.53)) * (0.10 + 0.075 * height);
	float offset = (UV.x - 0.5) * 0.92 - sway;
	float width = mix(0.048, 0.084, height);
	float density = exp(-pow(abs(offset) / width, 1.7));
	density *= smoothstep(0.0, 0.035, height) * (1.0 - smoothstep(0.64, 1.0, height));
	ALBEDO = vapor.rgb;
	ALPHA = density * mix(0.74, 0.46, height);
}
