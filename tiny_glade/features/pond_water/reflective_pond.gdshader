shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform float radius = 2.5;
uniform vec2 surface_origin = vec2(0.0);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.55;
uniform bool opaque_probe = false;
uniform float rain_amount = 0.0;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.55;
uniform bool reflection_enabled = true;
uniform sampler2D reflection_texture : filter_linear, repeat_disable;
uniform mat4 reflection_view;
uniform mat4 reflection_projection;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
varying vec2 world_xz;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_xz = world_position.xz;
}

void fragment() {
    float t = reduce_motion ? 0.0 : (freeze_time ? sample_time : TIME) * 0.55;
    vec2 p = world_xz;
    float a = dot(p, vec2(1.7, 0.8)) + t;
    float b = dot(p, vec2(-0.9, 2.3)) - t * 1.17;
    float c = dot(p, vec2(5.5, -3.2)) + t * 1.7;
    float strength = ripple_strength * (1.0 + rain_amount * 0.75);
    vec2 slope = (cos(a) * vec2(1.7, 0.8) * 0.10
                 + cos(b) * vec2(-0.9, 2.3) * 0.055
                 + cos(c) * vec2(5.5, -3.2) * 0.012) * strength;
    vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    float raw_depth = texture(depth_texture, SCREEN_UV).r;
    vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
    scene.xyz /= scene.w;
    float depth = max(0.0, -scene.z + VERTEX.z);
    float absorption = 1.0 - exp(-depth * 1.2);
    float foam = (1.0 - smoothstep(0.025, 0.16, depth)) * 0.32;
    float rings = 0.0;
    for (int i = 0; i < 2; i++) {
        float phase = fract(t * 0.27 + float(i) * 0.47);
        vec2 center = surface_origin + (i == 0 ? vec2(-0.8, 0.45) : vec2(0.95, -0.5));
        float d = abs(length(p - center) - (0.12 + phase * 1.65));
        rings += (1.0 - smoothstep(0.018, 0.055, d)) * (1.0 - phase);
    }
    vec3 shallow = vec3(0.20, 0.42, 0.36);
    vec3 deep = vec3(0.065, 0.20, 0.22);
    ALBEDO = mix(shallow, deep, absorption);
    ALBEDO = mix(ALBEDO, vec3(0.71, 0.81, 0.70), foam + rings * (0.12 + rain_amount * 0.18));
    vec4 clip = reflection_projection * reflection_view * vec4(world_position, 1.0);
    vec2 reflect_uv = vec2(clip.x, -clip.y) / max(clip.w, 0.001) * 0.5 + 0.5;
    reflect_uv += slope * 0.018;
    float edge = smoothstep(0.0, 0.025, min(min(reflect_uv.x, reflect_uv.y), min(1.0-reflect_uv.x, 1.0-reflect_uv.y)));
    float fresnel = 0.45 + 0.5 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
    float reflect_mix = reflection_enabled ? reflection_strength * fresnel * edge : 0.0;
    ALBEDO *= 1.0 - reflect_mix;
    EMISSION = texture(reflection_texture, clamp(reflect_uv, vec2(0.001), vec2(0.999))).rgb * reflect_mix;
    METALLIC = 0.0;
    SPECULAR = 0.7;
    ROUGHNESS = 0.06 + foam * 0.25;
    ALPHA = opaque_probe ? 1.0 : mix(0.70, 0.94, absorption);
}
