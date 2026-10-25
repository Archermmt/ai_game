shader_type spatial;
render_mode cull_disabled;

uniform sampler2D coverage : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float sample_time = 0.0;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.45;
uniform bool reduce_motion = false;
uniform vec4 root_color : source_color = vec4(0.32, 0.43, 0.24, 1.0);
uniform vec4 tip_color : source_color = vec4(0.53, 0.63, 0.35, 1.0);
varying float height_weight;
varying float variation;

void vertex() {
    height_weight = COLOR.r;
    variation = INSTANCE_CUSTOM.r;
    float phase = INSTANCE_CUSTOM.r * 6.283185;
    float wave = sin(sample_time * 1.4 + phase) + sin(sample_time * 2.3 + phase) * 0.22;
    float amount = reduce_motion ? 0.0 : wind_strength * 0.10 * INSTANCE_CUSTOM.g;
    VERTEX.xz += vec2(0.9, 0.4) * amount * wave * COLOR.r * COLOR.r;
}

void fragment() {
    float paint = texture(coverage, UV).a;
    ALPHA = paint;
    ALPHA_SCISSOR_THRESHOLD = 0.18;
    vec3 green = mix(root_color.rgb, tip_color.rgb, smoothstep(0.05, 0.96, height_weight));
    ALBEDO = green * mix(0.86, 1.08, variation) * mix(0.86, 1.0, paint);
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    ROUGHNESS = 0.95;
    SPECULAR = 0.06;
    BACKLIGHT = ALBEDO * height_weight * 0.06;
}
