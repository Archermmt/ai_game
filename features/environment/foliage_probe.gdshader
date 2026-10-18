shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.42, 0.55, 0.31, 1.0);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.45;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform float phase = 0.0;

void vertex() {
	float t = freeze_time ? sample_time : TIME;
	float strength = (reduce_motion ? 0.0 : wind_strength) * (1.0 - UV.y);
	float primary = sin(t * 1.3 + phase + VERTEX.y * 0.7);
	float secondary = sin(t * 2.1 + phase + VERTEX.x * 1.4);
	VERTEX.x += strength * (COLOR.r * primary * 0.24 + COLOR.g * secondary * 0.05);
	VERTEX.z += strength * COLOR.r * sin(t * 0.9 + phase) * 0.12;
}

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.95;
	vec2 p = (UV - vec2(0.5)) * vec2(2.0, 1.7);
	ALPHA = 1.0 - smoothstep(0.78, 0.85, length(p));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
