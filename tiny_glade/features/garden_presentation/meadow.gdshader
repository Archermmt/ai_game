shader_type spatial;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
varying vec3 living_position;
varying float living_up;

render_mode cull_disabled;
// Opt-in derived preview mask. Defaults preserve the production meadow.
uniform bool preview_patch_enabled = false;
uniform vec4 preview_patch_rect = vec4(0.0);
uniform float wind_strength = 0.45;
uniform float wind_direction = 0.4;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
uniform vec4 foliage_tint : source_color = vec4(1.0);
varying float shade;
varying float height_mix;
varying float meadow_mass;
varying float blade_wash;
void vertex() {
    living_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    living_up = 0.0;
    float t = freeze_time ? sample_time : TIME;
    vec3 base = MODEL_MATRIX[3].xyz;
    // Coarse height groups leave quiet low grass between taller painted tufts.
    // Instance count, density rank and the source distribution remain unchanged.
    float field = sin(base.x * 0.43 + sin(base.z * 0.29) * 1.4) * 0.6
                + cos(base.z * 0.51 - base.x * 0.17) * 0.4;
    meadow_mass = smoothstep(-0.45, 0.65, field);
    VERTEX.y *= mix(0.68, 1.0, meadow_mass) * mix(0.80, 1.13, INSTANCE_CUSTOM.x);
    float phase = INSTANCE_CUSTOM.x * 6.283 + base.x * 0.48 + base.z * 0.31;
    float wave = sin(t * 1.6 + phase) + 0.35 * sin(t * 2.8 + phase * 1.4);
    float strength = reduce_motion ? 0.0 : wind_strength;
    vec2 dir = vec2(cos(wind_direction), sin(wind_direction));
    VERTEX.xz += dir * wave * COLOR.r * COLOR.r * strength * 0.13;
    float fade = 1.0 - smoothstep(42.0, 58.0, distance(base, CAMERA_POSITION_WORLD));
    VERTEX *= fade;
    shade = INSTANCE_CUSTOM.x;
    height_mix = COLOR.r;
    blade_wash = COLOR.g;
}
void fragment() {
    if (preview_patch_enabled && living_position.x >= preview_patch_rect.x && living_position.z >= preview_patch_rect.y
        && living_position.x < preview_patch_rect.x + preview_patch_rect.z && living_position.z < preview_patch_rect.y + preview_patch_rect.w) {
        float edge = min(min(living_position.x - preview_patch_rect.x, preview_patch_rect.x + preview_patch_rect.z - living_position.x),
                         min(living_position.z - preview_patch_rect.y, preview_patch_rect.y + preview_patch_rect.w - living_position.z));
        if (shade < smoothstep(0.25, 0.95, edge)) { discard; }
    }
    // These are linear albedos, matched to the sRGB ground atlas after decoding.
    vec3 root = vec3(0.078, 0.1485, 0.0585);
    vec3 tip = mix(vec3(0.138, 0.2295, 0.0915), vec3(0.192, 0.2835, 0.1155), shade);
    vec3 wash = mix(vec3(0.91, 0.97, 1.03), vec3(1.05, 1.02, 0.95), meadow_mass);
    ALBEDO = mix(root, tip, smoothstep(0.02, 0.95, height_mix))
           * wash * mix(0.96, 1.04, blade_wash) * foliage_tint.rgb;
    // A blade's two thin sides share the same broad meadow illumination.
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    ROUGHNESS = 0.95;
    SPECULAR = 0.12;
    vec2 cp = living_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud_mask = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud_mask * living_cloud * 0.30;

    float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
    float winter = step(2.5, living_season);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.55, 0.87, 0.42), autumn * 0.72);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.32, 1.06, 0.68), winter * 0.65);

    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.55, 0.95, living_up));

}
