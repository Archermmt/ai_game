shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.42, 0.55, 0.31, 1.0);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.45;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform float phase = 0.0;
uniform float wind_direction = 0.0;
uniform float amplitude = 1.0;

void vertex() {
	float t = freeze_time ? sample_time : TIME;
	float strength = reduce_motion ? 0.0 : wind_strength;
	float primary = sin(t * 1.3 + phase + VERTEX.y * 0.7);
	float secondary = sin(t * 2.1 + phase + VERTEX.x * 1.4);
	vec2 sway = vec2(COLOR.r * primary * 0.24 + COLOR.g * secondary * 0.05,
                     COLOR.r * sin(t * 0.9 + phase) * 0.12);
    mat2 direction = mat2(vec2(cos(wind_direction), sin(wind_direction)),
                          vec2(-sin(wind_direction), cos(wind_direction)));
    VERTEX.xz += direction * sway * strength * amplitude;
}

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.95;
}
