shader_type spatial;
render_mode cull_disabled;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
uniform sampler2D coverage : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2DArray height_layers : filter_linear, repeat_disable;
uniform vec4 foliage_tint : source_color = vec4(1.0);
uniform float wind_strength = 0.45;
uniform float wind_direction = 0.4;
uniform bool reduce_motion = false;
uniform bool freeze_time = false;
uniform float sample_time = 0.0;
varying vec3 living_position;
varying float height_weight;
varying float variation;
void vertex() {
    living_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec2 origin = floor(MODEL_MATRIX[3].xz / 8.0) * 8.0 - vec2(1.0);
    vec2 uv = ((living_position.xz - origin) / 10.0 * 128.0 + 0.5) / 129.0;
    float ground = texture(height_layers, vec3(uv, INSTANCE_CUSTOM.b)).r;
    VERTEX.y += (ground - MODEL_MATRIX[3].y) / length(MODEL_MATRIX[1].xyz);
    height_weight = COLOR.r;
    variation = INSTANCE_CUSTOM.r;
    float t = freeze_time ? sample_time : TIME;
    float phase = INSTANCE_CUSTOM.r * 6.283185;
    float wave = sin(t * 1.4 + phase) + sin(t * 2.3 + phase) * 0.22;
    float amount = reduce_motion ? 0.0 : wind_strength * 0.10 * INSTANCE_CUSTOM.g;
    VERTEX.xz += vec2(cos(wind_direction), sin(wind_direction)) * amount * wave * COLOR.r * COLOR.r;
    VERTEX *= 1.0 - smoothstep(42.0, 58.0, distance(MODEL_MATRIX[3].xyz, CAMERA_POSITION_WORLD));
}
void fragment() {
    float paint = texture(coverage, UV).a;
    ALPHA = paint;
    ALPHA_SCISSOR_THRESHOLD = 0.18;
    // Linear albedos matched to G2's sRGB root/tip values.
    vec3 green = mix(vec3(0.0762, 0.1384, 0.0482), vec3(0.2086, 0.314, 0.107), smoothstep(0.05, 0.96, height_weight));
    float field = sin(living_position.x * 0.43 + sin(living_position.z * 0.29) * 1.4) * 0.6
                + cos(living_position.z * 0.51 - living_position.x * 0.17) * 0.4;
    ALBEDO = green * mix(0.86, 1.08, variation) * mix(0.86, 1.0, paint) * foliage_tint.rgb;
    ALBEDO *= mix(vec3(0.88, 0.96, 1.05), vec3(1.0, 1.0, 0.94), smoothstep(-0.5, 0.8, field));
    vec2 cp = living_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud * living_cloud * 0.30;
    float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
    float winter = step(2.5, living_season);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.55, 0.87, 0.42), autumn * 0.72);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.32, 1.06, 0.68), winter * 0.65);
    // Match the production meadow's living_up=0: cards do not collect a snow sheet.
    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * 0.0);
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    ROUGHNESS = 0.95;
    SPECULAR = 0.06;
    BACKLIGHT = ALBEDO * height_weight * 0.06;
}
