shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.45;
uniform float wind_direction = 0.4;
uniform float amplitude = 0.16;
uniform float phase = 0.0;
uniform bool batched = false;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
varying float fruit;
void vertex() {
    fruit = COLOR.b;
    float instance_phase = phase + (batched ? INSTANCE_CUSTOM.r * 62.83 : 0.0);
    float t = freeze_time ? sample_time : TIME;
    float amount = reduce_motion ? 0.0 : wind_strength * amplitude * COLOR.r;
    vec2 direction = vec2(cos(wind_direction), sin(wind_direction));
    VERTEX.xz += direction * amount * (sin(t * 1.2 + instance_phase) + COLOR.g * sin(t * 2.0 + instance_phase) * 0.2);
}
void fragment() {
    vec4 paint = texture(atlas, UV);
    ALBEDO = mix(paint.rgb, vec3(0.66, 0.29, 0.12), fruit);
    ALPHA = paint.a;
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    ROUGHNESS = 0.94;
}
