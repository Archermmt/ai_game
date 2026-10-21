shader_type spatial;
render_mode cull_disabled;
uniform float wind_strength = 0.45;
uniform float wind_direction = 0.4;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform vec4 foliage_tint : source_color = vec4(1.0);
varying float shade;
varying float height_mix;
void vertex() {
    float t = freeze_time ? sample_time : TIME;
    vec3 base = MODEL_MATRIX[3].xyz;
    float phase = INSTANCE_CUSTOM.x * 6.283 + base.x * 0.48 + base.z * 0.31;
    float wave = sin(t * 1.6 + phase) + 0.35 * sin(t * 2.8 + phase * 1.4);
    float strength = reduce_motion ? 0.0 : wind_strength;
    vec2 dir = vec2(cos(wind_direction), sin(wind_direction));
    VERTEX.xz += dir * wave * COLOR.r * COLOR.r * strength * 0.22;
    float fade = 1.0 - smoothstep(42.0, 58.0, distance(base, CAMERA_POSITION_WORLD));
    VERTEX *= fade;
    shade = INSTANCE_CUSTOM.y;
    height_mix = COLOR.r;
}
void fragment() {
    vec3 root = vec3(0.29, 0.40, 0.17);
    vec3 tip = mix(vec3(0.46, 0.56, 0.24), vec3(0.61, 0.65, 0.31), shade);
    ALBEDO = mix(root, tip, height_mix * 0.85 + 0.15) * foliage_tint.rgb;
    ROUGHNESS = 0.95;
    SPECULAR = 0.12;
}
