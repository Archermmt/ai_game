shader_type spatial;
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
varying vec3 living_position;
varying float living_up;

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
    living_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    living_up = 0.0;
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
    vec2 cp = living_position.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float cloud_mask = smoothstep(0.40, 0.72, 0.5 + sin(cp.x + sin(cp.y)) * 0.22 + cos(cp.y * 0.8 - cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - cloud_mask * living_cloud * 0.30;

    float autumn = 1.0 - step(0.45, abs(living_season - 2.0));
    float winter = step(2.5, living_season);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.55, 0.87, 0.42), autumn * 0.72);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.32, 1.06, 0.68), winter * 0.65);

    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), living_snow * smoothstep(0.55, 0.95, living_up));

}
