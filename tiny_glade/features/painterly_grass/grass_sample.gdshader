shader_type spatial;
render_mode cull_disabled;

uniform sampler2D coverage : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool conform_ground = false;
uniform bool garden_colors = false;
uniform sampler2D terrain_map : hint_default_black, filter_linear, repeat_disable;
uniform vec2 terrain_origin;
uniform float terrain_span = 10.0;
uniform float terrain_resolution = 129.0;
uniform float sample_time = 0.0;
varying vec3 world_position;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.45;
uniform bool reduce_motion = false;
uniform vec4 root_color : source_color = vec4(0.32, 0.43, 0.24, 1.0);
uniform vec4 tip_color : source_color = vec4(0.53, 0.63, 0.35, 1.0);
varying float height_weight;
varying float variation;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    if (conform_ground) {
        vec2 uv = ((world_position.xz - terrain_origin) / terrain_span * (terrain_resolution - 1.0) + 0.5) / terrain_resolution;
        float height = texture(terrain_map, uv).r;
        VERTEX.y += (height - MODEL_MATRIX[3].y) / length(MODEL_MATRIX[1].xyz);
    }
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
    if (garden_colors) {
        float field = sin(world_position.x * 0.43 + sin(world_position.z * 0.29) * 1.4) * 0.6
                    + cos(world_position.z * 0.51 - world_position.x * 0.17) * 0.4;
        ALBEDO *= mix(vec3(0.88, 0.96, 1.05), vec3(1.0, 1.0, 0.94), smoothstep(-0.5, 0.8, field));
    }
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    ROUGHNESS = 0.95;
    SPECULAR = 0.06;
    BACKLIGHT = ALBEDO * height_weight * 0.06;
}
