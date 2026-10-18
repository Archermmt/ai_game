shader_type spatial;
render_mode blend_mix, depth_draw_opaque;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform float radius = 2.5;
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool opaque_probe = false;
varying vec2 local_xz;
void vertex() { local_xz = VERTEX.xz; }
void fragment() {
    float t = reduce_motion ? 0.0 : (freeze_time ? sample_time : TIME) * 0.3;
    float shore = 1.0 - smoothstep(radius - 0.65, radius - 0.06, length(local_xz));
    float waves = sin(local_xz.x * 2.7 + t) * cos(local_xz.y * 3.3 + t * 0.7);
    vec3 deep = vec3(0.17, 0.31, 0.27);
    vec3 shallow = vec3(0.39, 0.48, 0.35);
    ALBEDO = mix(shallow, deep, shore) + waves * ripple_strength * 0.025;
    NORMAL_MAP = vec3(0.5 + cos(local_xz.x * 2.7 + t) * ripple_strength * 0.025,
                      0.5 + sin(local_xz.y * 3.3 + t) * ripple_strength * 0.025, 1.0);
    SPECULAR = 0.0;
    ROUGHNESS = 0.65;
    ALPHA = opaque_probe ? 1.0 : mix(0.48, 0.82, shore);
}
