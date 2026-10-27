shader_type spatial;
render_mode cull_disabled;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;

uniform sampler2D coverage : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2DArray height_layers : filter_linear, repeat_disable;
uniform sampler2DArray clearance_layers : filter_linear, repeat_disable;
uniform vec4 root_color : source_color = vec4(0.286, 0.369, 0.212, 1.0);
uniform vec4 tip_color : source_color = vec4(0.635, 0.667, 0.420, 1.0);
uniform vec4 floor_color : source_color = vec4(0.510, 0.584, 0.306, 1.0);
uniform vec4 foliage_tint : source_color = vec4(1.0);
uniform float sample_time = 0.0;
uniform float wind_strength = 0.35;
uniform float wind_direction = 0.4;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float normal_softening = 0.55;
uniform float facing_fade = 0.7;
uniform bool walker_interaction_active = false;
uniform vec4 walker_contacts[4];
uniform float walker_radius = 1.15;
uniform float walker_contact_extent = 0.0;
uniform float walker_push = 0.72;
uniform float walker_drop = 0.18;
varying vec3 world_position;
varying vec2 chunk_origin;
varying float chunk_layer;
varying float leaf_height;
varying float color_variation;
varying float low_cover;
varying float snow_seed;

vec2 map_uv(vec2 point) {
    return ((point - chunk_origin) / 12.0 * 128.0 + 0.5) / 129.0;
}
float ground_at(vec2 point) {
    return texture(height_layers, vec3(map_uv(point), chunk_layer)).r;
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    chunk_origin = floor(MODEL_MATRIX[3].xz / 8.0) * 8.0 - vec2(2.0);
    chunk_layer = INSTANCE_CUSTOM.b;
    float tangent_height = (MODEL_MATRIX[0] * VERTEX.x + MODEL_MATRIX[2] * VERTEX.z).y;
    float root_ground = ground_at(MODEL_MATRIX[3].xz);
    float delta_height = ground_at(world_position.xz) - root_ground - tangent_height;
    VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(0.0, delta_height, 0.0);
    leaf_height = COLOR.r;
    color_variation = INSTANCE_CUSTOM.a;
    low_cover = 1.0 - step(0.5, INSTANCE_CUSTOM.g);
    snow_seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(127.1, 311.7)) + INSTANCE_CUSTOM.r * 74.7) * 43758.5453);
    float phase = INSTANCE_CUSTOM.r * 6.283185;
    float t = freeze_time ? sample_time : TIME;
    float wave = sin(t * 1.4 + phase + world_position.x * 0.18) + sin(t * 2.1 + phase) * 0.2;
    float amount = reduce_motion ? 0.0 : wind_strength * 0.12 * INSTANCE_CUSTOM.g;
    VERTEX.xz += vec2(cos(wind_direction), sin(wind_direction)) * amount * wave * leaf_height * leaf_height;
    // One shared, bounded contact field bends visible blades, never their roots.
    // The uniform fast path keeps orbit views out of the four-contact loop.
    if (walker_interaction_active && !reduce_motion && low_cover < 0.5 && leaf_height > 0.001) {
        vec2 lead_delta = world_position.xz - walker_contacts[0].xz;
        if (dot(lead_delta, lead_delta) < walker_contact_extent * walker_contact_extent) {
            float contact_weight = 0.0;
            vec2 away = vec2(0.0);
            for (int i = 0; i < 4; i++) {
                vec2 offset = world_position.xz - walker_contacts[i].xz;
                float radius = length(offset);
                float height_match = 1.0 - smoothstep(0.25, 0.85, abs(root_ground - walker_contacts[i].y));
                float weight = (1.0 - smoothstep(walker_radius * 0.2, walker_radius, radius))
                    * walker_contacts[i].w * height_match;
                if (weight > contact_weight) {
                    contact_weight = weight;
                    away = radius > 0.001 ? offset / radius : vec2(cos(phase), sin(phase));
                }
            }
            vec3 bend = vec3(away.x * walker_push, -walker_drop, away.y * walker_push)
                * contact_weight * leaf_height * leaf_height;
            VERTEX += inverse(mat3(MODEL_MATRIX)) * bend;
        }
    }
    vec3 local_up = normalize(inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
    NORMAL = normalize(mix(NORMAL, local_up, normal_softening));
}

void fragment() {
    float brush = texture(coverage, UV).a;
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float edge = mix(1.0, smoothstep(0.02, 0.32, facing), facing_fade);
    float allowed = texture(clearance_layers, vec3(map_uv(world_position.xz), chunk_layer)).r;
    float snow_cover = clamp(living_snow, 0.0, 1.0);
    // Stable per-clump survival: bury the low carpet and most tall clumps.
    // No source edits or reseeding; thaw reveals the exact same summer plants.
    float snow_survival = smoothstep(snow_cover * 0.97 - 0.015, snow_cover * 0.97 + 0.015, snow_seed);
    snow_survival *= 1.0 - low_cover * smoothstep(0.20, 0.65, snow_cover);
    snow_survival = mix(1.0, snow_survival, smoothstep(0.0, 0.08, snow_cover));
    ALPHA = brush * edge * smoothstep(0.25, 0.75, allowed) * snow_survival;
    ALPHA_HASH_SCALE = 1.0;
    vec3 tip = mix(tip_color.rgb, floor_color.rgb, low_cover);
    vec3 green = mix(root_color.rgb, tip, smoothstep(0.04, 0.9, leaf_height));
    float field = sin(world_position.x * 0.26 + sin(world_position.z * 0.21)) + cos(world_position.z * 0.31 - world_position.x * 0.12) * 0.5;
    green *= mix(vec3(0.88, 0.97, 1.02), vec3(1.08, 1.03, 0.84), smoothstep(-1.1, 1.1, field));
    ALBEDO = green * mix(0.92, 1.08, color_variation) * mix(0.90, 1.0, brush) * foliage_tint.rgb;
    vec2 cp = world_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud * living_cloud * 0.30;
    float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
    float winter = step(2.5, living_season);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.55, 0.87, 0.42), autumn * 0.72);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.32, 1.06, 0.68), winter * 0.65);
    vec3 dry_grass = mix(vec3(0.30, 0.22, 0.12), vec3(0.64, 0.49, 0.27), smoothstep(0.04, 0.9, leaf_height));
    ALBEDO = mix(ALBEDO, dry_grass, smoothstep(0.20, 0.8, snow_cover));
    // Remaining straw tips catch snow; the continuous blanket is on Terrain3D.
    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), snow_cover * 0.35 * (1.0 - low_cover) * smoothstep(0.72, 0.98, leaf_height));
    ROUGHNESS = 0.95;
    SPECULAR = 0.05;
    AO = mix(0.70, 1.0, smoothstep(0.0, 0.45, leaf_height));
    AO_LIGHT_AFFECT = 0.18;
    BACKLIGHT = ALBEDO * 0.28 * smoothstep(0.05, 0.85, leaf_height);
}
