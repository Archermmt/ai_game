shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform float radius = 2.5;
uniform vec2 surface_origin = vec2(0.0);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.35;
uniform bool opaque_probe = false;
varying vec2 local_xz;

void vertex() {
    local_xz = VERTEX.xz - surface_origin;
}

void fragment() {
    float t = reduce_motion ? 0.0 : (freeze_time ? sample_time : TIME) * 0.23;
    float inner = 1.0 - smoothstep(radius - 0.7, radius - 0.06, length(local_xz));
    float wave = sin(local_xz.x * 2.1 + t) * cos(local_xz.y * 2.8 + t * 0.7);
    float glint = pow(max(0.0, sin(local_xz.x * 1.3 + local_xz.y * 2.2 + t)), 24.0);
    vec3 deep = vec3(0.13, 0.28, 0.27);
    vec3 shallow = vec3(0.27, 0.40, 0.35);
    ALBEDO = mix(shallow, deep, inner) + wave * ripple_strength * 0.018;
    NORMAL_MAP = vec3(0.5 + cos(local_xz.x * 2.1 + t) * ripple_strength * 0.035,
                      0.5 + sin(local_xz.y * 2.8 + t) * ripple_strength * 0.035, 1.0);
    EMISSION = vec3(0.31, 0.42, 0.35) * glint * 0.025 * ripple_strength;
    SPECULAR = 0.38;
    ROUGHNESS = 0.34;
    ALPHA = opaque_probe ? 1.0 : mix(0.66, 0.91, inner);
}
