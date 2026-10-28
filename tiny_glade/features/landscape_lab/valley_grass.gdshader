shader_type spatial;
render_mode cull_disabled;

// The source atlas is grayscale coverage, not albedo. Keep its brush strokes.
uniform sampler2D coverage : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D terrain_map : filter_linear, repeat_disable;
uniform vec2 terrain_origin = vec2(-32.0);
uniform float terrain_spacing = 0.25;
uniform float terrain_resolution = 256.0;
uniform bool conform_ground = true;
uniform vec4 root_color : source_color = vec4(0.29, 0.35, 0.12, 1.0);
uniform vec4 tip_color : source_color = vec4(0.57, 0.60, 0.22, 1.0);
uniform float sample_time = 0.0;
uniform float wind_strength = 0.35;
uniform bool reduce_motion = false;
uniform float normal_softening = 0.55;
uniform float facing_fade = 0.7;
varying vec3 world_position;
varying float leaf_height;
varying float color_variation;

float ground_at(vec2 point) {
    return texture(terrain_map, ((point - terrain_origin) / terrain_spacing + 0.5) / terrain_resolution).r;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    if (conform_ground) {
        // Difference from the anchor surface preserves the author's buried roots.
        float tangent_height = (MODEL_MATRIX[0] * VERTEX.x + MODEL_MATRIX[2] * VERTEX.z).y;
        float delta_height = ground_at(world_position.xz) - ground_at(MODEL_MATRIX[3].xz) - tangent_height;
        VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(0.0, delta_height, 0.0);
    }
    leaf_height = COLOR.r;
    color_variation = INSTANCE_CUSTOM.a;
    float phase = INSTANCE_CUSTOM.r * 6.283185;
    float wave = sin(sample_time * 1.4 + phase + world_position.x * 0.18)
               + sin(sample_time * 2.1 + phase) * 0.2;
    float amount = reduce_motion ? 0.0 : wind_strength * 0.12 * INSTANCE_CUSTOM.g;
    VERTEX.xz += vec2(0.9, 0.4) * amount * wave * leaf_height * leaf_height;
    vec3 local_up = normalize(inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
    NORMAL = normalize(mix(NORMAL, local_up, normal_softening));
}

void fragment() {
    float brush = texture(coverage, UV).a;
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float edge = mix(1.0, smoothstep(0.02, 0.32, facing), facing_fade);
    ALPHA = brush * edge;
    ALPHA_HASH_SCALE = 1.0;
    vec3 green = mix(root_color.rgb, tip_color.rgb, smoothstep(0.04, 0.9, leaf_height));
    float field = sin(world_position.x * 0.26 + sin(world_position.z * 0.21))
                + cos(world_position.z * 0.31 - world_position.x * 0.12) * 0.5;
    green *= mix(vec3(0.88, 0.97, 1.02), vec3(1.08, 1.03, 0.84), smoothstep(-1.1, 1.1, field));
    ALBEDO = green * mix(0.92, 1.08, color_variation) * mix(0.90, 1.0, brush);
    ROUGHNESS = 0.95;
    SPECULAR = 0.05;
    AO = mix(0.70, 1.0, smoothstep(0.0, 0.45, leaf_height));
    AO_LIGHT_AFFECT = 0.18;
    BACKLIGHT = ALBEDO * 0.28 * smoothstep(0.05, 0.85, leaf_height);
}
